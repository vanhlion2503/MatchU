import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:matchu_app/services/security/device_service.dart';
import 'package:pointycastle/asn1/primitives/asn1_integer.dart';
import 'package:pointycastle/asn1/primitives/asn1_sequence.dart';
import 'package:pointycastle/export.dart';

import 'identity_key_service.dart';
import 'message_crypto_service.dart';
import 'passcode_backup_service.dart';

class SessionKeyService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static final _storage = FlutterSecureStorage();
  static final _functions = FirebaseFunctions.instance;
  static const int _keyCreationLockTtlMs = 20000;
  static const int _activeDeviceWindowDays = 60;
  static const int _maxSessionKeyDevicesPerUser = 5;
  static const int _legacyDeviceQueryLimit = 5;
  static const String _activeDeviceStatus = 'active';
  static const String _revokedDeviceStatus = 'revoked';
  static const String _staleDeviceStatus = 'stale';

  static String get uid => _auth.currentUser!.uid;
  static final Map<String, StreamController<void>> _keyUpdateControllers = {};
  static final Set<String> _distributionChecks = {};

  static Stream<void> onSessionKeyUpdated(String roomId) {
    return _keyUpdateControllers
        .putIfAbsent(roomId, () => StreamController.broadcast())
        .stream;
  }

  /// Notify listeners that session key is available/updated
  static void notifyUpdated(String roomId) {
    _keyUpdateControllers[roomId]?.add(null);
  }

  static String _localSessionKeyKey(String roomId, int keyId) {
    if (keyId == 0) {
      return "chat_${roomId}_session_key";
    }
    return "chat_${roomId}_session_key_$keyId";
  }

  static String _sessionKeyDocId({
    required String participantUid,
    required String deviceId,
    required int keyId,
  }) {
    final base = "${participantUid}_$deviceId";
    if (keyId == 0) return base;
    return "${base}_$keyId";
  }

  static String _legacySessionKeyDocId({
    required String deviceId,
    required int keyId,
  }) {
    if (keyId == 0) return deviceId;
    return "${deviceId}_$keyId";
  }

  static String _roomKeyToken(String roomId, int keyId) => "$roomId:$keyId";

  static Future<void> _saveLocalSessionKey({
    required String roomId,
    required int keyId,
    required Uint8List sessionKey,
  }) async {
    await _storage.write(
      key: _localSessionKeyKey(roomId, keyId),
      value: base64Encode(sessionKey),
    );
    MessageCryptoService.cacheSessionKey(
      roomId: roomId,
      keyId: keyId,
      key: sessionKey,
    );
  }

  /// ===============================
  /// STEP 1 — CREATE AES KEY
  /// ===============================
  static Uint8List _generateAESKey() {
    final rand = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(32, (_) => rand.nextInt(256)), // AES-256
    );
  }

  /// ===============================
  /// STEP 2 — RSA ENCRYPT
  /// ===============================
  static Uint8List _rsaEncrypt(Uint8List data, RSAPublicKey publicKey) {
    final cipher = OAEPEncoding.withSHA256(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));

    return _processInBlocks(cipher, data);
  }

  /// ===============================
  /// STEP 4 — SEND SESSION KEY (MULTI-DEVICE)
  /// ===============================
  static Future<void> createAndSendSessionKey({
    required String roomId,
    required List<String> participantUids,
    int keyId = 0,
  }) async {
    // 🔒 Kiểm tra xem đã có session key local chưa (không rotate key)
    if (await hasLocalSessionKey(roomId, keyId: keyId)) {
      // Nếu đã có key, chỉ đảm bảo phân phối cho tất cả thiết bị
      await ensureDistributedToAllDevices(
        roomId: roomId,
        participantUids: participantUids,
        keyId: keyId,
      );
      return;
    }

    // 🔒 QUAN TRỌNG: Kiểm tra xem room đã có session keys trong Firestore chưa
    // Nếu đã có → không tạo key mới (vì tất cả thiết bị phải dùng cùng 1 key)
    // Thiết bị khác sẽ phân phối lại key cho thiết bị mới qua ensureDistributedToAllDevices
    final hasAnyKeys =
        keyId == 0
            ? await hasAnySessionKeys(roomId)
            : await hasAnySessionKeysForKeyId(roomId, keyId);
    if (hasAnyKeys) {
      final hasKeyForCurrentDevice = await hasSessionKeyForCurrentDevice(
        roomId,
        keyId: keyId,
      );
      debugPrint(
        hasKeyForCurrentDevice
            ? "Room $roomId already has a session key for this device, skip creating new key"
            : "Room $roomId already has session keys for keyId=$keyId, skip creating duplicate key",
      );
      return;
    }

    final lockNonce = await _acquireKeyCreationLock(
      roomId: roomId,
      keyId: keyId,
    );
    if (lockNonce == null) {
      debugPrint("Another device is creating session key for room $roomId");
      return;
    }

    try {
      final hasAnyKeysAfterLock =
          keyId == 0
              ? await hasAnySessionKeys(roomId)
              : await hasAnySessionKeysForKeyId(roomId, keyId);
      if (hasAnyKeysAfterLock) {
        debugPrint(
          "Room $roomId received session key while waiting for lock, skip creating",
        );
        return;
      }

      debugPrint("Creating session key for room $roomId");
      final sessionKey = _generateAESKey();
      await _distributeSessionKeyToDevices(
        roomId: roomId,
        sessionKey: sessionKey,
        participantUids: participantUids,
        keyId: keyId,
        progressive: true,
      );

      // Local readiness is published only after both participants' primary
      // envelopes have been acknowledged by the server.
      await _saveLocalSessionKey(
        roomId: roomId,
        keyId: keyId,
        sessionKey: sessionKey,
      );

      unawaited(
        PasscodeBackupService.backupSessionKey(
          roomId: roomId,
          sessionKey: sessionKey,
          keyId: keyId,
        ).catchError((e) {
          debugPrint("Passcode backup failed: $e");
        }),
      );

      final roomUpdate = <String, dynamic>{"currentKeyId": keyId};
      if (keyId > 0) {
        roomUpdate["currentKeyUpdatedAt"] = FieldValue.serverTimestamp();
      }
      await _db
          .collection("chatRooms")
          .doc(roomId)
          .set(roomUpdate, SetOptions(merge: true));

      // Notify listeners
      notifyUpdated(roomId);
    } finally {
      await _releaseKeyCreationLock(
        roomId: roomId,
        keyId: keyId,
        lockNonce: lockNonce,
      );
    }
  }

  static Future<int> rotateSessionKey({
    required String roomId,
    required List<String> participantUids,
  }) async {
    final newKeyId = await _incrementCurrentKeyId(roomId);
    final sessionKey = _generateAESKey();

    await _distributeSessionKeyToDevices(
      roomId: roomId,
      sessionKey: sessionKey,
      participantUids: participantUids,
      keyId: newKeyId,
      progressive: true,
    );

    await _saveLocalSessionKey(
      roomId: roomId,
      keyId: newKeyId,
      sessionKey: sessionKey,
    );

    unawaited(
      PasscodeBackupService.backupSessionKey(
        roomId: roomId,
        sessionKey: sessionKey,
        keyId: newKeyId,
      ).catchError((e) {
        debugPrint("Passcode backup failed: $e");
      }),
    );

    notifyUpdated(roomId);
    return newKeyId;
  }

  static Future<int> _incrementCurrentKeyId(String roomId) {
    final ref = _db.collection("chatRooms").doc(roomId);
    return _db.runTransaction<int>((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      final current = (data?["currentKeyId"] ?? 0) as int;
      final next = current + 1;
      tx.set(ref, {
        "currentKeyId": next,
        "currentKeyUpdatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return next;
    });
  }

  /// ===============================
  /// STEP 5 — RECEIVE & DECRYPT
  /// ===============================
  static Future<bool> receiveSessionKey({
    required String roomId,
    int keyId = 0,
  }) async {
    final deviceId = await DeviceService.getDeviceId();
    final docId = _sessionKeyDocId(
      participantUid: uid,
      deviceId: deviceId,
      keyId: keyId,
    );

    var snap =
        await _db
            .collection("chatRooms")
            .doc(roomId)
            .collection("sessionKeys")
            .doc(docId)
            .get();

    if (!snap.exists) {
      final legacyDocId = _legacySessionKeyDocId(
        deviceId: deviceId,
        keyId: keyId,
      );
      if (legacyDocId != docId) {
        final legacy =
            await _db
                .collection("chatRooms")
                .doc(roomId)
                .collection("sessionKeys")
                .doc(legacyDocId)
                .get();
        if (legacy.exists) {
          snap = legacy;
        }
      }
    }

    if (!snap.exists && keyId == 0) {
      final fallback =
          await _db
              .collection("chatRooms")
              .doc(roomId)
              .collection("sessionKeys")
              .doc("${deviceId}_0")
              .get();
      if (fallback.exists) {
        snap = fallback;
      }
    }

    if (!snap.exists) return false;

    return await _decryptAndSaveSessionKey(
      roomId: roomId,
      snap: snap,
      keyId: keyId,
    );
  }

  /// Decrypt và save session key từ snapshot
  static Future<bool> _decryptAndSaveSessionKey({
    required String roomId,
    required DocumentSnapshot<Map<String, dynamic>> snap,
    int keyId = 0,
  }) async {
    final data = snap.data();
    if (data == null) {
      debugPrint("Session key document ${snap.id} is empty");
      return false;
    }
    if (data["keyId"] is int) {
      keyId = data["keyId"] as int;
    }
    if (data["userId"] is String && data["userId"] != uid) {
      debugPrint(
        "❌ Session key doc belongs to another user: ${data["userId"]}",
      );
      return false;
    }

    final encryptedKeyB64 = data["encryptedKey"];
    if (encryptedKeyB64 is! String || encryptedKeyB64.isEmpty) {
      debugPrint("Session key doc ${snap.id} is missing encryptedKey");
      return false;
    }

    late final Uint8List encrypted;
    try {
      encrypted = base64Decode(encryptedKeyB64);
    } catch (e) {
      debugPrint("Invalid encryptedKey encoding for ${snap.id}: $e");
      return false;
    }
    final privateKeyPem = await IdentityKeyService.readPrivateKey();
    if (privateKeyPem == null) return false;

    final privateKey = _decodePrivateKeyFromPem(privateKeyPem);

    final cipher = OAEPEncoding.withSHA256(RSAEngine())
      ..init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));

    try {
      final sessionKey = _processInBlocks(cipher, encrypted);

      // 🔒 Validate session key length (AES-256 = 32 bytes)
      if (sessionKey.length != 32) {
        debugPrint(
          "❌ Invalid session key length: ${sessionKey.length}, expected 32",
        );
        debugPrint("🔍 Encrypted key length: ${encrypted.length}");
        return false;
      }

      await _saveLocalSessionKey(
        roomId: roomId,
        keyId: keyId,
        sessionKey: sessionKey,
      );

      try {
        await PasscodeBackupService.backupSessionKey(
          roomId: roomId,
          sessionKey: sessionKey,
          keyId: keyId,
        );
      } catch (e) {
        debugPrint("Passcode backup failed: $e");
      }

      notifyUpdated(roomId);
      return true;
    } catch (e) {
      debugPrint("❌ RSA decrypt failed: $e");
      return false;
    }
  }

  /// Listen realtime cho session key của device hiện tại
  /// Return StreamSubscription, cancel khi không cần nữa
  static Future<StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
  listenForSessionKey({
    required String roomId,
    required Function(bool success) onKeyReceived,
    int keyId = 0,
  }) async {
    final deviceId = await DeviceService.getDeviceId();
    final docId = _sessionKeyDocId(
      participantUid: uid,
      deviceId: deviceId,
      keyId: keyId,
    );

    final stream =
        _db
            .collection("chatRooms")
            .doc(roomId)
            .collection("sessionKeys")
            .doc(docId)
            .snapshots();

    return stream.listen(
      (snap) async {
        if (snap.exists && snap.data() != null) {
          debugPrint(
            "🔒 Session key document created/updated for device $deviceId",
          );
          final success = await _decryptAndSaveSessionKey(
            roomId: roomId,
            snap: snap,
            keyId: keyId,
          );
          onKeyReceived(success);
        }
      },
      onError: (e) {
        debugPrint("❌ Error listening for session key: $e");
        onKeyReceived(false);
      },
    );
  }

  static Future<bool> waitForLocalSessionKey(
    String roomId, {
    required int keyId,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (await hasLocalSessionKey(roomId, keyId: keyId)) return true;

    final completer = Completer<bool>();
    final localSubscription = onSessionKeyUpdated(roomId).listen((_) async {
      if (completer.isCompleted) return;
      if (await hasLocalSessionKey(roomId, keyId: keyId)) {
        completer.complete(true);
      }
    });
    final remoteSubscription = await listenForSessionKey(
      roomId: roomId,
      keyId: keyId,
      onKeyReceived: (success) {
        if (success && !completer.isCompleted) completer.complete(true);
      },
    );
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) completer.complete(false);
    });
    if (await hasLocalSessionKey(roomId, keyId: keyId) &&
        !completer.isCompleted) {
      completer.complete(true);
    }

    try {
      return await completer.future;
    } finally {
      timer.cancel();
      await localSubscription.cancel();
      await remoteSubscription.cancel();
    }
  }

  static Future<void> requestSessionKey({
    required String roomId,
    required int keyId,
  }) async {
    final deviceId = await DeviceService.getDeviceId();
    final requestId = _sessionKeyDocId(
      participantUid: uid,
      deviceId: deviceId,
      keyId: keyId,
    );
    await _db
        .collection('chatRooms')
        .doc(roomId)
        .collection('keyRequests')
        .doc(requestId)
        .set({
          'userId': uid,
          'deviceId': deviceId,
          'keyId': keyId,
          'status': 'pending',
          'requestedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
  listenForKeyRequests({
    required String roomId,
    required Future<void> Function(int keyId) onRequest,
  }) {
    return _db
        .collection('chatRooms')
        .doc(roomId)
        .collection('keyRequests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen(
          (snapshot) async {
            final keyIds =
                snapshot.docs
                    .map((doc) => doc.data()['keyId'])
                    .whereType<int>()
                    .toSet();
            for (final requestedKeyId in keyIds) {
              if (!await hasLocalSessionKey(roomId, keyId: requestedKeyId)) {
                continue;
              }
              try {
                await onRequest(requestedKeyId);
                final batch = _db.batch();
                for (final doc in snapshot.docs.where(
                  (doc) => doc.data()['keyId'] == requestedKeyId,
                )) {
                  batch.update(doc.reference, {
                    'status': 'fulfilled',
                    'fulfilledAt': FieldValue.serverTimestamp(),
                  });
                }
                await batch.commit();
              } catch (e) {
                debugPrint('Unable to fulfill room key request: $e');
              }
            }
          },
          onError: (Object e) {
            debugPrint('Room key request listener failed: $e');
          },
        );
  }

  static Future<void> clearCurrentDeviceKeyRequest({
    required String roomId,
    required int keyId,
  }) async {
    final deviceId = await DeviceService.getDeviceId();
    final requestId = _sessionKeyDocId(
      participantUid: uid,
      deviceId: deviceId,
      keyId: keyId,
    );
    try {
      await _db
          .collection('chatRooms')
          .doc(roomId)
          .collection('keyRequests')
          .doc(requestId)
          .delete();
    } catch (_) {}
  }

  /// ===============================
  /// UTILS
  /// ===============================
  static Uint8List _processInBlocks(
    AsymmetricBlockCipher engine,
    Uint8List input,
  ) {
    final numBlocks =
        input.length ~/ engine.inputBlockSize +
        ((input.length % engine.inputBlockSize != 0) ? 1 : 0);

    final out = BytesBuilder();

    for (var i = 0; i < numBlocks; i++) {
      final start = i * engine.inputBlockSize;
      final end = min(start + engine.inputBlockSize, input.length);
      out.add(engine.process(input.sublist(start, end)));
    }

    return out.toBytes();
  }

  static RSAPublicKey _decodePublicKeyFromPem(String pem) {
    final clean = pem
        .replaceAll('-----BEGIN RSA PUBLIC KEY-----', '')
        .replaceAll('-----END RSA PUBLIC KEY-----', '')
        .replaceAll(RegExp(r'\s'), '');

    final bytes = base64Decode(clean);
    final seq = ASN1Sequence.fromBytes(bytes);

    final modulus = (seq.elements![0] as ASN1Integer).integer!;
    final exponent = (seq.elements![1] as ASN1Integer).integer!;

    return RSAPublicKey(modulus, exponent);
  }

  static RSAPrivateKey _decodePrivateKeyFromPem(String pem) {
    // 1️⃣ loại bỏ header / footer
    final clean = pem
        .replaceAll('-----BEGIN RSA PRIVATE KEY-----', '')
        .replaceAll('-----END RSA PRIVATE KEY-----', '')
        .replaceAll(RegExp(r'\s'), '');

    // 2️⃣ base64 decode
    final bytes = base64Decode(clean);

    // 3️⃣ parse ASN1
    final seq = ASN1Sequence.fromBytes(bytes);

    return RSAPrivateKey(
      (seq.elements![1] as ASN1Integer).integer!, // n
      (seq.elements![3] as ASN1Integer).integer!, // d
      (seq.elements![4] as ASN1Integer).integer!, // p
      (seq.elements![5] as ASN1Integer).integer!, // q
    );
  }

  static Future<bool> hasLocalSessionKey(String roomId, {int keyId = 0}) async {
    if (MessageCryptoService.hasCachedSessionKey(roomId, keyId: keyId)) {
      return true;
    }

    final key = await _storage.read(key: _localSessionKeyKey(roomId, keyId));
    if (key != null) {
      try {
        MessageCryptoService.cacheSessionKey(
          roomId: roomId,
          keyId: keyId,
          key: base64Decode(key),
        );
      } catch (_) {}
    }
    return key != null;
  }

  /// Kiểm tra xem room đã có session keys trong Firestore chưa
  static Future<bool> hasAnySessionKeys(String roomId) async {
    final snap =
        await _db
            .collection("chatRooms")
            .doc(roomId)
            .collection("sessionKeys")
            .limit(1)
            .get();
    return snap.docs.isNotEmpty;
  }

  static Future<bool> hasAnySessionKeysForKeyId(
    String roomId,
    int keyId,
  ) async {
    final snap =
        await _db
            .collection("chatRooms")
            .doc(roomId)
            .collection("sessionKeys")
            .where("keyId", isEqualTo: keyId)
            .limit(1)
            .get();
    return snap.docs.isNotEmpty;
  }

  static Future<bool> hasAnySessionKeysForUser(
    String roomId,
    String userId, {
    int? keyId,
  }) async {
    Query<Map<String, dynamic>> query = _db
        .collection("chatRooms")
        .doc(roomId)
        .collection("sessionKeys")
        .where("userId", isEqualTo: userId);

    if (keyId == null) {
      final snap = await query.limit(1).get();
      return snap.docs.isNotEmpty;
    }

    if (keyId > 0) {
      query = query.where("keyId", isEqualTo: keyId);
      final snap = await query.limit(1).get();
      return snap.docs.isNotEmpty;
    }

    final snap = await query.get();
    for (final doc in snap.docs) {
      final data = doc.data();
      final existingKeyId = data["keyId"] is int ? data["keyId"] as int : 0;
      if (existingKeyId == keyId) {
        return true;
      }
    }
    return false;
  }

  static Future<bool> hasSessionKeyForDevice({
    required String roomId,
    required String participantUid,
    required String deviceId,
    int keyId = 0,
  }) async {
    final docId = _sessionKeyDocId(
      participantUid: participantUid,
      deviceId: deviceId,
      keyId: keyId,
    );

    final snap =
        await _db
            .collection("chatRooms")
            .doc(roomId)
            .collection("sessionKeys")
            .doc(docId)
            .get();
    return snap.exists;
  }

  static Future<bool> hasSessionKeyForCurrentDevice(
    String roomId, {
    int keyId = 0,
  }) async {
    final deviceId = await DeviceService.getDeviceId();
    return hasSessionKeyForDevice(
      roomId: roomId,
      participantUid: uid,
      deviceId: deviceId,
      keyId: keyId,
    );
  }

  static String _keyCreationLockPath(int keyId) => "sessionKeyLocks.$keyId";

  static Future<String?> _acquireKeyCreationLock({
    required String roomId,
    required int keyId,
  }) async {
    final roomRef = _db.collection("chatRooms").doc(roomId);
    final deviceId = await DeviceService.getDeviceId();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final expiresAtMs = nowMs + _keyCreationLockTtlMs;
    final lockNonce = base64UrlEncode(
      List<int>.generate(18, (_) => Random.secure().nextInt(256)),
    );

    return _db.runTransaction<String?>((tx) async {
      final snap = await tx.get(roomRef);
      final data = snap.data() ?? const <String, dynamic>{};

      String? lockUid;
      String? lockDeviceId;
      int lockExpiresAt = 0;

      final locksRaw = data["sessionKeyLocks"];
      if (locksRaw is Map) {
        final currentLockRaw = locksRaw["$keyId"];
        if (currentLockRaw is Map) {
          final uidRaw = currentLockRaw["uid"];
          final deviceIdRaw = currentLockRaw["deviceId"];
          final expiresRaw = currentLockRaw["expiresAtMs"];
          if (uidRaw is String && uidRaw.isNotEmpty) {
            lockUid = uidRaw;
          }
          if (deviceIdRaw is String && deviceIdRaw.isNotEmpty) {
            lockDeviceId = deviceIdRaw;
          }
          if (expiresRaw is int) {
            lockExpiresAt = expiresRaw;
          }
        }
      }

      final lockActive = lockUid != null && lockExpiresAt > nowMs;
      if (lockActive) {
        debugPrint("Session key creation is locked by $lockUid/$lockDeviceId");
        return null;
      }

      tx.update(roomRef, {
        _keyCreationLockPath(keyId): {
          "uid": uid,
          "deviceId": deviceId,
          "nonce": lockNonce,
          "expiresAtMs": expiresAtMs,
        },
      });
      return lockNonce;
    });
  }

  static Future<void> _releaseKeyCreationLock({
    required String roomId,
    required int keyId,
    required String lockNonce,
  }) async {
    final roomRef = _db.collection("chatRooms").doc(roomId);
    try {
      await _db.runTransaction<void>((tx) async {
        final snap = await tx.get(roomRef);
        final locksRaw = snap.data()?["sessionKeyLocks"];
        final lockRaw = locksRaw is Map ? locksRaw["$keyId"] : null;
        if (lockRaw is! Map || lockRaw["nonce"] != lockNonce) return;
        tx.update(roomRef, {_keyCreationLockPath(keyId): FieldValue.delete()});
      });
    } catch (_) {}
  }

  static Future<Uint8List?> _readLocalSessionKey(
    String roomId, {
    int keyId = 0,
  }) async {
    final key = await _storage.read(key: _localSessionKeyKey(roomId, keyId));
    if (key == null) return null;
    final sessionKey = base64Decode(key);
    MessageCryptoService.cacheSessionKey(
      roomId: roomId,
      keyId: keyId,
      key: sessionKey,
    );
    return sessionKey;
  }

  /// Đảm bảo session key được phân phối cho tất cả thiết bị của participants
  static Future<void> ensureDistributedToAllDevices({
    required String roomId,
    required List<String> participantUids,
    int keyId = 0,
    bool force = false,
  }) async {
    final sessionKey = await _readLocalSessionKey(roomId, keyId: keyId);
    if (sessionKey == null) return;

    final token = _roomKeyToken(roomId, keyId);
    if (!force && !_distributionChecks.add(token)) {
      return;
    }

    try {
      await _distributeSessionKeyToDevices(
        roomId: roomId,
        sessionKey: sessionKey,
        participantUids: participantUids,
        keyId: keyId,
      );
    } finally {
      // Only deduplicate concurrent checks. A permanent token would prevent a
      // device enrolled later from ever receiving this room key.
      _distributionChecks.remove(token);
    }
  }

  /// Phân phối session key cho tất cả thiết bị của participants
  static Future<void> _distributeSessionKeyToDevices({
    required String roomId,
    required Uint8List sessionKey,
    required List<String> participantUids,
    int keyId = 0,
    bool progressive = false,
  }) async {
    final totalTimer = Stopwatch()..start();
    final directoryTimer = Stopwatch()..start();
    final participants = participantUids.toSet().toList(growable: false);
    final states = await Future.wait(
      participants.map((participantUid) async {
        final devicesFuture = _getDevices(participantUid);
        final existingFuture = _getExistingSessionKeyDocIds(
          roomId: roomId,
          participantUid: participantUid,
          keyId: keyId,
        );
        return _ParticipantDistributionState(
          userId: participantUid,
          devices: await devicesFuture,
          existingDocIds: await existingFuture,
        );
      }),
    );
    directoryTimer.stop();

    final primaryTargets = <_SessionKeyTarget>[];
    final backgroundTargets = <_SessionKeyTarget>[];
    var skippedCount = 0;

    for (final state in states) {
      if (state.devices.isEmpty) {
        throw StateError(
          'No eligible encryption device found for ${state.userId}.',
        );
      }

      for (var index = 0; index < state.devices.length; index++) {
        final device = state.devices[index];
        final docId = _sessionKeyDocId(
          participantUid: state.userId,
          deviceId: device.deviceId,
          keyId: keyId,
        );
        if (state.existingDocIds.contains(docId)) {
          skippedCount++;
          continue;
        }

        final target = _SessionKeyTarget(
          docRef: _db
              .collection("chatRooms")
              .doc(roomId)
              .collection("sessionKeys")
              .doc(docId),
          userId: state.userId,
          device: device,
        );
        if (index == 0) {
          primaryTargets.add(target);
        } else {
          backgroundTargets.add(target);
        }
      }
    }

    final primaryTimer = Stopwatch()..start();
    await _wrapAndPublishTargets(
      roomId: roomId,
      keyId: keyId,
      sessionKey: sessionKey,
      targets: primaryTargets,
      requireCompleteAcceptance: true,
    );
    primaryTimer.stop();

    if (backgroundTargets.isNotEmpty) {
      final backgroundWork = _wrapAndPublishTargets(
        roomId: roomId,
        keyId: keyId,
        sessionKey: sessionKey,
        targets: backgroundTargets,
      );
      if (progressive) {
        unawaited(
          backgroundWork.catchError((e, st) {
            debugPrint('Background session key distribution failed: $e');
          }),
        );
      } else {
        await backgroundWork;
      }
    }

    debugPrint(
      'E2EE_METRIC room=$roomId keyId=$keyId '
      'directoryMs=${directoryTimer.elapsedMilliseconds} '
      'primaryMs=${primaryTimer.elapsedMilliseconds} '
      'readyMs=${totalTimer.elapsedMilliseconds} '
      'primary=${primaryTargets.length} '
      'background=${backgroundTargets.length} existing=$skippedCount',
    );
  }

  static Future<void> _wrapAndPublishTargets({
    required String roomId,
    required int keyId,
    required Uint8List sessionKey,
    required List<_SessionKeyTarget> targets,
    bool requireCompleteAcceptance = false,
  }) async {
    if (targets.isEmpty) return;

    final encryptedKeys = await compute(_wrapSessionKeysInBackground, {
      'sessionKey': base64Encode(sessionKey),
      'publicKeys': targets
          .map((target) => target.device.publicKeyPem)
          .toList(growable: false),
    });
    final writes = <_WrappedSessionKeyWrite>[];
    for (var index = 0; index < targets.length; index++) {
      final encryptedKey = encryptedKeys[index];
      if (encryptedKey == null) {
        debugPrint(
          'Unable to wrap room key for ${targets[index].device.deviceId}',
        );
        continue;
      }
      final target = targets[index];
      writes.add(
        _WrappedSessionKeyWrite(
          docRef: target.docRef,
          userId: target.userId,
          deviceId: target.device.deviceId,
          encryptedKey: encryptedKey,
        ),
      );
    }

    if (requireCompleteAcceptance && writes.length != targets.length) {
      throw StateError('Unable to encrypt the room key for a primary device.');
    }
    if (writes.isEmpty) return;

    final result = await _publishWrappedSessionKeys(
      roomId: roomId,
      keyId: keyId,
      writes: writes,
    );
    if (requireCompleteAcceptance && result.accepted < writes.length) {
      if (result.invalid == 0) {
        // Compatibility with the previous callable, which silently skipped
        // inactive (but still valid) devices and did not report invalidDevices.
        await _writeWrappedSessionKeysDirect(writes, keyId: keyId);
        return;
      }
      throw StateError(
        'The server rejected one or more primary encryption devices.',
      );
    }
  }

  static Future<_WrappedKeyPublishResult> _publishWrappedSessionKeys({
    required String roomId,
    required int keyId,
    required List<_WrappedSessionKeyWrite> writes,
  }) async {
    const chunkSize = 20;
    var written = 0;
    var existing = 0;
    var invalid = 0;
    try {
      final callable = _functions.httpsCallable('publishWrappedRoomKeys');
      for (var i = 0; i < writes.length; i += chunkSize) {
        final chunk = writes.skip(i).take(chunkSize).toList(growable: false);
        final response = await callable.call(<String, dynamic>{
          'roomId': roomId,
          'keyId': keyId,
          'keys': chunk
              .map(
                (write) => <String, dynamic>{
                  'userId': write.userId,
                  'deviceId': write.deviceId,
                  'encryptedKey': write.encryptedKey,
                },
              )
              .toList(growable: false),
        });
        final data = response.data;
        if (data is Map) {
          written += (data['written'] as num?)?.toInt() ?? 0;
          existing += (data['alreadyExists'] as num?)?.toInt() ?? 0;
          invalid += (data['invalidDevices'] as num?)?.toInt() ?? 0;
        }
      }
      return _WrappedKeyPublishResult(
        written: written,
        existing: existing,
        invalid: invalid,
      );
    } catch (e) {
      debugPrint("publishWrappedRoomKeys failed, using direct fallback: $e");
      await _writeWrappedSessionKeysDirect(writes, keyId: keyId);
      return _WrappedKeyPublishResult(
        written: writes.length,
        existing: 0,
        invalid: 0,
      );
    }
  }

  static Future<void> _writeWrappedSessionKeysDirect(
    List<_WrappedSessionKeyWrite> writes, {
    required int keyId,
  }) async {
    WriteBatch batch = _db.batch();
    var pendingWrites = 0;

    Future<void> commitPendingWrites() async {
      if (pendingWrites == 0) return;

      try {
        await batch.commit();
      } catch (e) {
        debugPrint("sessionKey batch write error: $e");
        rethrow;
      } finally {
        batch = _db.batch();
        pendingWrites = 0;
      }
    }

    for (final write in writes) {
      batch.set(write.docRef, {
        "userId": write.userId,
        "encryptedKey": write.encryptedKey,
        "keyId": keyId,
        "createdAt": FieldValue.serverTimestamp(),
      });
      pendingWrites++;

      if (pendingWrites >= 400) {
        await commitPendingWrites();
      }
    }

    await commitPendingWrites();
  }

  static Future<List<_SessionDeviceInfo>> _getDevices(
    String participantUid,
  ) async {
    final currentDeviceId =
        participantUid == uid ? await DeviceService.getDeviceId() : null;
    final devicesRef = _db
        .collection('users')
        .doc(participantUid)
        .collection('devices');
    final currentDeviceFuture =
        currentDeviceId == null ? null : devicesRef.doc(currentDeviceId).get();
    late final QuerySnapshot<Map<String, dynamic>> activeSnapshot;
    try {
      activeSnapshot =
          await devicesRef
              .where('e2eeStatus', isEqualTo: _activeDeviceStatus)
              .orderBy('lastE2eeActiveAt', descending: true)
              .limit(_maxSessionKeyDevicesPerUser)
              .get();
    } on FirebaseException catch (e) {
      if (e.code != 'failed-precondition') rethrow;
      // Safe during staged deployment before the composite index is ready.
      activeSnapshot =
          await devicesRef
              .where('e2eeStatus', isEqualTo: _activeDeviceStatus)
              .limit(_maxSessionKeyDevicesPerUser)
              .get();
    }
    final currentDeviceSnapshot = await currentDeviceFuture;

    final documents = <String, DocumentSnapshot<Map<String, dynamic>>>{};
    if (currentDeviceSnapshot?.exists ?? false) {
      documents[currentDeviceSnapshot!.id] = currentDeviceSnapshot;
    }
    for (final doc in activeSnapshot.docs) {
      documents[doc.id] = doc;
    }

    final activeCutoff = DateTime.now().subtract(
      const Duration(days: _activeDeviceWindowDays),
    );
    final eligibleDevices = <_SessionDeviceInfo>[];
    var skippedInvalid = 0;

    for (final doc in documents.values) {
      final data = doc.data();
      if (data == null) continue;
      final publicKey = data["publicKey"];

      if (publicKey is! String || publicKey.trim().isEmpty) {
        skippedInvalid++;
        continue;
      }

      final status = data["e2eeStatus"];
      final statusValue = status is String ? status.trim() : null;
      if (_isDeviceStatusBlocked(statusValue)) {
        continue;
      }

      final lastActiveAt = _readDeviceLastActiveAt(data);
      final isFresh =
          lastActiveAt != null && lastActiveAt.isAfter(activeCutoff);
      final isCurrentDevice = doc.id == currentDeviceId;

      final device = _SessionDeviceInfo(
        deviceId: doc.id,
        publicKeyPem: publicKey.trim(),
        lastActiveAt: lastActiveAt,
        isCurrentDevice: isCurrentDevice,
      );

      final isActiveDevice = statusValue == _activeDeviceStatus;
      final isLegacyDevice = statusValue == null || statusValue.isEmpty;

      if (isCurrentDevice ||
          (isActiveDevice && (isFresh || lastActiveAt == null)) ||
          (isLegacyDevice && isFresh)) {
        eligibleDevices.add(device);
      }
    }

    if (skippedInvalid > 0) {
      debugPrint(
        "Skipping $skippedInvalid invalid device docs for user $participantUid because publicKey is missing",
      );
    }

    if (eligibleDevices.isNotEmpty) {
      return _limitSessionKeyDevices(eligibleDevices);
    }

    // Bounded compatibility query for signed-out and legacy devices. This keeps
    // first-message recovery without downloading an unbounded device history.
    var fallbackSnapshot =
        await devicesRef
            .orderBy('lastActiveAt', descending: true)
            .limit(_legacyDeviceQueryLimit)
            .get();
    if (fallbackSnapshot.docs.isEmpty) {
      fallbackSnapshot = await devicesRef.limit(1).get();
    }

    final fallbackDevices = <_SessionDeviceInfo>[];
    for (final doc in fallbackSnapshot.docs) {
      final data = doc.data();
      final publicKey = data['publicKey'];
      final status = data['e2eeStatus'];
      final statusValue = status is String ? status.trim() : null;
      if (publicKey is! String ||
          publicKey.trim().isEmpty ||
          _isDeviceStatusBlocked(statusValue)) {
        continue;
      }
      fallbackDevices.add(
        _SessionDeviceInfo(
          deviceId: doc.id,
          publicKeyPem: publicKey.trim(),
          lastActiveAt: _readDeviceLastActiveAt(data),
          isCurrentDevice: doc.id == currentDeviceId,
        ),
      );
    }
    return _limitSessionKeyDevices(fallbackDevices, fallbackLimit: 1);
  }

  static bool _isDeviceStatusBlocked(String? status) {
    // Inactive means the account signed out, not that the device key is
    // invalid. Keep recent inactive devices eligible as fallback so first
    // messages sent while the recipient is signed out remain decryptable when
    // that account logs back into the same device.
    return status == _revokedDeviceStatus || status == _staleDeviceStatus;
  }

  static DateTime? _readDeviceLastActiveAt(Map<String, dynamic> data) {
    return _readTimestamp(data["lastE2eeActiveAt"]) ??
        _readTimestamp(data["lastActiveAt"]);
  }

  static DateTime? _readTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static List<_SessionDeviceInfo> _limitSessionKeyDevices(
    List<_SessionDeviceInfo> devices, {
    int fallbackLimit = _maxSessionKeyDevicesPerUser,
  }) {
    if (devices.isEmpty) return const [];

    final sorted = List<_SessionDeviceInfo>.from(devices)
      ..sort(_compareDeviceRecency);
    final limit = min(fallbackLimit, _maxSessionKeyDevicesPerUser).toInt();
    if (sorted.length <= limit) return sorted;

    final limited = sorted.take(limit).toList();
    _SessionDeviceInfo? currentDevice;
    for (final device in sorted) {
      if (device.isCurrentDevice) {
        currentDevice = device;
        break;
      }
    }

    if (currentDevice != null &&
        !limited.any((device) => device.deviceId == currentDevice!.deviceId)) {
      limited[limited.length - 1] = currentDevice;
    }
    return limited;
  }

  static int _compareDeviceRecency(_SessionDeviceInfo a, _SessionDeviceInfo b) {
    if (a.isCurrentDevice != b.isCurrentDevice) {
      return a.isCurrentDevice ? -1 : 1;
    }

    final aMs = a.lastActiveAt?.millisecondsSinceEpoch ?? 0;
    final bMs = b.lastActiveAt?.millisecondsSinceEpoch ?? 0;
    return bMs.compareTo(aMs);
  }

  static Future<Set<String>> _getExistingSessionKeyDocIds({
    required String roomId,
    required String participantUid,
    required int keyId,
  }) async {
    Query<Map<String, dynamic>> query = _db
        .collection("chatRooms")
        .doc(roomId)
        .collection("sessionKeys")
        .where("userId", isEqualTo: participantUid);

    if (keyId > 0) {
      query = query.where("keyId", isEqualTo: keyId);
    }

    final snap = await query.get();
    final existingDocIds = <String>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final existingKeyId = data["keyId"] is int ? data["keyId"] as int : 0;
      if (existingKeyId == keyId) {
        existingDocIds.add(doc.id);
      }
    }
    return existingDocIds;
  }
}

class _SessionDeviceInfo {
  const _SessionDeviceInfo({
    required this.deviceId,
    required this.publicKeyPem,
    required this.lastActiveAt,
    required this.isCurrentDevice,
  });

  final String deviceId;
  final String publicKeyPem;
  final DateTime? lastActiveAt;
  final bool isCurrentDevice;
}

class _ParticipantDistributionState {
  const _ParticipantDistributionState({
    required this.userId,
    required this.devices,
    required this.existingDocIds,
  });

  final String userId;
  final List<_SessionDeviceInfo> devices;
  final Set<String> existingDocIds;
}

class _SessionKeyTarget {
  const _SessionKeyTarget({
    required this.docRef,
    required this.userId,
    required this.device,
  });

  final DocumentReference<Map<String, dynamic>> docRef;
  final String userId;
  final _SessionDeviceInfo device;
}

class _WrappedKeyPublishResult {
  const _WrappedKeyPublishResult({
    required this.written,
    required this.existing,
    required this.invalid,
  });

  final int written;
  final int existing;
  final int invalid;
  int get accepted => written + existing;
}

class _WrappedSessionKeyWrite {
  const _WrappedSessionKeyWrite({
    required this.docRef,
    required this.userId,
    required this.deviceId,
    required this.encryptedKey,
  });

  final DocumentReference<Map<String, dynamic>> docRef;
  final String userId;
  final String deviceId;
  final String encryptedKey;
}

/// Runs PEM parsing and RSA-OAEP wrapping outside Flutter's UI isolate.
List<String?> _wrapSessionKeysInBackground(Map<String, dynamic> input) {
  final sessionKey = base64Decode(input['sessionKey'] as String);
  final publicKeys = List<String>.from(input['publicKeys'] as List);
  return publicKeys
      .map<String?>((publicKeyPem) {
        try {
          final publicKey = SessionKeyService._decodePublicKeyFromPem(
            publicKeyPem,
          );
          return base64Encode(
            SessionKeyService._rsaEncrypt(sessionKey, publicKey),
          );
        } catch (_) {
          return null;
        }
      })
      .toList(growable: false);
}
