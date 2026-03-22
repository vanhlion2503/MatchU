import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:matchu_app/services/security/device_service.dart';
import 'package:pointycastle/asn1/primitives/asn1_integer.dart';
import 'package:pointycastle/asn1/primitives/asn1_sequence.dart';
import 'package:pointycastle/export.dart';

import 'identity_key_service.dart';
import 'passcode_backup_service.dart';

class SessionKeyService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static final _storage = FlutterSecureStorage();
  static const int _keyCreationLockTtlMs = 20000;

  static String get uid => _auth.currentUser!.uid;
  static final Map<String, StreamController<void>> _keyUpdateControllers = {};

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
      print(
        hasKeyForCurrentDevice
            ? "Room $roomId already has a session key for this device, skip creating new key"
            : "Room $roomId already has session keys for keyId=$keyId, skip creating duplicate key",
      );
      return;
    }

    final canCreate = await _acquireKeyCreationLock(
      roomId: roomId,
      keyId: keyId,
    );
    if (!canCreate) {
      print("Another device is creating session key for room $roomId");
      return;
    }

    try {
      final hasAnyKeysAfterLock =
          keyId == 0
              ? await hasAnySessionKeys(roomId)
              : await hasAnySessionKeysForKeyId(roomId, keyId);
      if (hasAnyKeysAfterLock) {
        print(
          "Room $roomId received session key while waiting for lock, skip creating",
        );
        return;
      }

      print("Creating session key for room $roomId");
      final sessionKey = _generateAESKey();
      await _distributeSessionKeyToDevices(
        roomId: roomId,
        sessionKey: sessionKey,
        participantUids: participantUids,
        keyId: keyId,
      );

      await _storage.write(
        key: _localSessionKeyKey(roomId, keyId),
        value: base64Encode(sessionKey),
      );

      try {
        await PasscodeBackupService.backupSessionKey(
          roomId: roomId,
          sessionKey: sessionKey,
          keyId: keyId,
        );
      } catch (e) {
        print("Passcode backup failed: $e");
      }

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
      await _releaseKeyCreationLock(roomId: roomId, keyId: keyId);
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
    );

    await _storage.write(
      key: _localSessionKeyKey(roomId, newKeyId),
      value: base64Encode(sessionKey),
    );

    try {
      await PasscodeBackupService.backupSessionKey(
        roomId: roomId,
        sessionKey: sessionKey,
        keyId: newKeyId,
      );
    } catch (e) {
      print("Passcode backup failed: $e");
    }

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
      print("Session key document ${snap.id} is empty");
      return false;
    }
    if (data["keyId"] is int) {
      keyId = data["keyId"] as int;
    }
    if (data["userId"] is String && data["userId"] != uid) {
      print("❌ Session key doc belongs to another user: ${data["userId"]}");
      return false;
    }

    final encryptedKeyB64 = data["encryptedKey"];
    if (encryptedKeyB64 is! String || encryptedKeyB64.isEmpty) {
      print("Session key doc ${snap.id} is missing encryptedKey");
      return false;
    }

    late final Uint8List encrypted;
    try {
      encrypted = base64Decode(encryptedKeyB64);
    } catch (e) {
      print("Invalid encryptedKey encoding for ${snap.id}: $e");
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
        print(
          "❌ Invalid session key length: ${sessionKey.length}, expected 32",
        );
        print("🔍 Encrypted key length: ${encrypted.length}");
        return false;
      }

      await _storage.write(
        key: _localSessionKeyKey(roomId, keyId),
        value: base64Encode(sessionKey),
      );

      try {
        await PasscodeBackupService.backupSessionKey(
          roomId: roomId,
          sessionKey: sessionKey,
          keyId: keyId,
        );
      } catch (e) {
        print("Passcode backup failed: $e");
      }

      notifyUpdated(roomId);
      return true;
    } catch (e) {
      print("❌ RSA decrypt failed: $e");
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
          print("🔒 Session key document created/updated for device $deviceId");
          final success = await _decryptAndSaveSessionKey(
            roomId: roomId,
            snap: snap,
            keyId: keyId,
          );
          onKeyReceived(success);
        }
      },
      onError: (e) {
        print("❌ Error listening for session key: $e");
        onKeyReceived(false);
      },
    );
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
    final key = await _storage.read(key: _localSessionKeyKey(roomId, keyId));
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
    final snap =
        await _db
            .collection("chatRooms")
            .doc(roomId)
            .collection("sessionKeys")
            .where("userId", isEqualTo: userId)
            .limit(20)
            .get();

    if (keyId == null) return snap.docs.isNotEmpty;

    for (final doc in snap.docs) {
      final data = doc.data();
      final value = data["keyId"];
      if (value is int && value == keyId) {
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

  static Future<bool> _acquireKeyCreationLock({
    required String roomId,
    required int keyId,
  }) async {
    final roomRef = _db.collection("chatRooms").doc(roomId);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final expiresAtMs = nowMs + _keyCreationLockTtlMs;

    return _db.runTransaction<bool>((tx) async {
      final snap = await tx.get(roomRef);
      final data = snap.data() ?? const <String, dynamic>{};

      String? lockUid;
      int lockExpiresAt = 0;

      final locksRaw = data["sessionKeyLocks"];
      if (locksRaw is Map) {
        final currentLockRaw = locksRaw["$keyId"];
        if (currentLockRaw is Map) {
          final uidRaw = currentLockRaw["uid"];
          final expiresRaw = currentLockRaw["expiresAtMs"];
          if (uidRaw is String && uidRaw.isNotEmpty) {
            lockUid = uidRaw;
          }
          if (expiresRaw is int) {
            lockExpiresAt = expiresRaw;
          }
        }
      }

      final lockActive = lockUid != null && lockExpiresAt > nowMs;
      if (lockActive && lockUid != uid) {
        return false;
      }

      tx.update(roomRef, {
        _keyCreationLockPath(keyId): {"uid": uid, "expiresAtMs": expiresAtMs},
      });
      return true;
    });
  }

  static Future<void> _releaseKeyCreationLock({
    required String roomId,
    required int keyId,
  }) async {
    final roomRef = _db.collection("chatRooms").doc(roomId);
    try {
      await roomRef.update({_keyCreationLockPath(keyId): FieldValue.delete()});
    } catch (_) {}
  }

  static Future<Uint8List?> _readLocalSessionKey(
    String roomId, {
    int keyId = 0,
  }) async {
    final key = await _storage.read(key: _localSessionKeyKey(roomId, keyId));
    if (key == null) return null;
    return base64Decode(key);
  }

  /// Đảm bảo session key được phân phối cho tất cả thiết bị của participants
  static Future<void> ensureDistributedToAllDevices({
    required String roomId,
    required List<String> participantUids,
    int keyId = 0,
  }) async {
    final sessionKey = await _readLocalSessionKey(roomId, keyId: keyId);
    if (sessionKey == null) return;

    await _distributeSessionKeyToDevices(
      roomId: roomId,
      sessionKey: sessionKey,
      participantUids: participantUids,
      keyId: keyId,
    );
  }

  /// Phân phối session key cho tất cả thiết bị của participants
  static Future<void> _distributeSessionKeyToDevices({
    required String roomId,
    required Uint8List sessionKey,
    required List<String> participantUids,
    int keyId = 0,
  }) async {
    final uniqueParticipants = participantUids.toSet();
    int distributedCount = 0;
    int skippedCount = 0;

    for (final participantUid in uniqueParticipants) {
      final devices = await _getDevices(participantUid);
      if (devices.isEmpty) {
        continue;
      }

      final existingDocIds = await _getExistingSessionKeyDocIds(
        roomId: roomId,
        participantUid: participantUid,
        keyId: keyId,
      );

      for (final device in devices) {
        final deviceId = device.deviceId;
        final publicKeyPem = device.publicKeyPem;
        final docId = _sessionKeyDocId(
          participantUid: participantUid,
          deviceId: deviceId,
          keyId: keyId,
        );

        final docRef = _db
            .collection("chatRooms")
            .doc(roomId)
            .collection("sessionKeys")
            .doc(docId);

        // 🔒 Kiểm tra xem device đã có session key chưa (không ghi đè)
        if (existingDocIds.contains(docId)) {
          skippedCount++;
          continue; // Đã có key, bỏ qua
        }

        try {
          await docRef.set({
            "userId": participantUid,
            "encryptedKey": base64Encode(
              _rsaEncrypt(sessionKey, _decodePublicKeyFromPem(publicKeyPem)),
            ),
            "keyId": keyId,
            "createdAt": FieldValue.serverTimestamp(),
          });
          distributedCount++;
          print(
            "🔒 Distributed session key to device $deviceId (user: $participantUid)",
          );
        } catch (e) {
          // Log error nhưng không throw - tiếp tục với device khác
          print("🔒 sessionKey write error for $deviceId: $e");
        }
      }
    }

    if (distributedCount > 0 || skippedCount > 0) {
      print(
        "🔒 Distribution summary: $distributedCount distributed, $skippedCount skipped",
      );
    }
  }

  static Future<List<_SessionDeviceInfo>> _getDevices(String uid) async {
    final snap =
        await _db.collection('users').doc(uid).collection('devices').get();

    final devices = <_SessionDeviceInfo>[];
    var skippedInvalid = 0;

    for (final doc in snap.docs) {
      final data = doc.data();
      final publicKey = data["publicKey"];

      if (publicKey is! String || publicKey.trim().isEmpty) {
        skippedInvalid++;
        continue;
      }

      devices.add(
        _SessionDeviceInfo(deviceId: doc.id, publicKeyPem: publicKey.trim()),
      );
    }

    if (skippedInvalid > 0) {
      print(
        "Skipping $skippedInvalid invalid device docs for user $uid because publicKey is missing",
      );
    }

    return devices;
  }

  static Future<Set<String>> _getExistingSessionKeyDocIds({
    required String roomId,
    required String participantUid,
    required int keyId,
  }) async {
    final snap =
        await _db
            .collection("chatRooms")
            .doc(roomId)
            .collection("sessionKeys")
            .where("userId", isEqualTo: participantUid)
            .get();

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
  });

  final String deviceId;
  final String publicKeyPem;
}
