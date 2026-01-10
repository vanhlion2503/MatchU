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

class SessionKeyService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static final _storage = FlutterSecureStorage();

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
  static Uint8List _rsaEncrypt(
    Uint8List data,
    RSAPublicKey publicKey,
  ) {
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
  }) async {
    // 🔒 Kiểm tra xem đã có session key local chưa (không rotate key)
    if (await hasLocalSessionKey(roomId)) {
      // Nếu đã có key, chỉ đảm bảo phân phối cho tất cả thiết bị
      await ensureDistributedToAllDevices(
        roomId: roomId,
        participantUids: participantUids,
      );
      return;
    }

    // 🔒 QUAN TRỌNG: Kiểm tra xem room đã có session keys trong Firestore chưa
    // Nếu đã có → không tạo key mới (vì tất cả thiết bị phải dùng cùng 1 key)
    // Thiết bị khác sẽ phân phối lại key cho thiết bị mới qua ensureDistributedToAllDevices
    if (await hasAnySessionKeys(roomId)) {
      print("🔒 Room $roomId đã có session keys, không tạo key mới");
      return;
    }

    // 🔒 FIX RACE CONDITION: Chỉ cho phép leader (uid nhỏ nhất) tạo key
    final sorted = [...participantUids]..sort();
    final leaderUid = sorted.first;

    if (uid != leaderUid) {
      // Không phải leader → chỉ receive, không tạo key
      print("🔒 Không phải leader ($leaderUid), không tạo key mới");
      return;
    }

    // Room chưa có key nào → leader tạo key mới
    print("🔒 Leader tạo session key cho room $roomId");
    final sessionKey = _generateAESKey();
    await _distributeSessionKeyToDevices(
      roomId: roomId,
      sessionKey: sessionKey,
      participantUids: participantUids,
    );

    await _storage.write(
      key: "chat_${roomId}_session_key",
      value: base64Encode(sessionKey),
    );

    // Notify listeners
    notifyUpdated(roomId);
  }




  /// ===============================
  /// STEP 5 — RECEIVE & DECRYPT
  /// ===============================
  static Future<bool> receiveSessionKey({
    required String roomId,
  }) async {
    final deviceId = await DeviceService.getDeviceId();

    final snap = await _db
        .collection("chatRooms")
        .doc(roomId)
        .collection("sessionKeys")
        .doc(deviceId)
        .get();

    if (!snap.exists) return false;

    return await _decryptAndSaveSessionKey(roomId: roomId, snap: snap);
  }

  /// Decrypt và save session key từ snapshot
  static Future<bool> _decryptAndSaveSessionKey({
    required String roomId,
    required DocumentSnapshot<Map<String, dynamic>> snap,
  }) async {
    final encrypted = base64Decode(snap["encryptedKey"]);
    final privateKeyPem = await IdentityKeyService.readPrivateKey();
    if (privateKeyPem == null) return false;

    final privateKey = _decodePrivateKeyFromPem(privateKeyPem);

    final cipher = OAEPEncoding.withSHA256(RSAEngine())
      ..init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));

    try {
      final sessionKey = _processInBlocks(cipher, encrypted);

      // 🔒 Validate session key length (AES-256 = 32 bytes)
      if (sessionKey.length != 32) {
        print("❌ Invalid session key length: ${sessionKey.length}, expected 32");
        print("🔍 Encrypted key length: ${encrypted.length}");
        return false;
      }

      await _storage.write(
        key: "chat_${roomId}_session_key",
        value: base64Encode(sessionKey),
      );

      notifyUpdated(roomId);
      return true;
    } catch (e) {
      print("❌ RSA decrypt failed: $e");
      return false;
    }
  }

  /// Listen realtime cho session key của device hiện tại
  /// Return StreamSubscription, cancel khi không cần nữa
  static Future<StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>> listenForSessionKey({
    required String roomId,
    required Function(bool success) onKeyReceived,
  }) async {
    final deviceId = await DeviceService.getDeviceId();
    
    final stream = _db
        .collection("chatRooms")
        .doc(roomId)
        .collection("sessionKeys")
        .doc(deviceId)
        .snapshots();

    return stream.listen((snap) async {
      if (snap.exists && snap.data() != null) {
        print("🔒 Session key document created/updated for device $deviceId");
        final success = await _decryptAndSaveSessionKey(roomId: roomId, snap: snap);
        onKeyReceived(success);
      }
    }, onError: (e) {
      print("❌ Error listening for session key: $e");
      onKeyReceived(false);
    });
  }



  /// ===============================
  /// UTILS
  /// ===============================
  static Uint8List _processInBlocks(
    AsymmetricBlockCipher engine,
    Uint8List input,
  ) {
    final numBlocks = input.length ~/ engine.inputBlockSize +
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


  static Future<bool> hasLocalSessionKey(String roomId) async {
    final key = await _storage.read(key: "chat_${roomId}_session_key");
    return key != null;
  }

  /// Kiểm tra xem room đã có session keys trong Firestore chưa
  static Future<bool> hasAnySessionKeys(String roomId) async {
    final snap = await _db
        .collection("chatRooms")
        .doc(roomId)
        .collection("sessionKeys")
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  static Future<Uint8List?> _readLocalSessionKey(String roomId) async {
    final key = await _storage.read(key: "chat_${roomId}_session_key");
    if (key == null) return null;
    return base64Decode(key);
  }

  /// Đảm bảo session key được phân phối cho tất cả thiết bị của participants
  static Future<void> ensureDistributedToAllDevices({
    required String roomId,
    required List<String> participantUids,
  }) async {
    final sessionKey = await _readLocalSessionKey(roomId);
    if (sessionKey == null) return;

    await _distributeSessionKeyToDevices(
      roomId: roomId,
      sessionKey: sessionKey,
      participantUids: participantUids,
    );
  }

  /// Phân phối session key cho tất cả thiết bị của participants
  static Future<void> _distributeSessionKeyToDevices({
    required String roomId,
    required Uint8List sessionKey,
    required List<String> participantUids,
  }) async {
    final uniqueParticipants = participantUids.toSet();
    int distributedCount = 0;
    int skippedCount = 0;

    for (final participantUid in uniqueParticipants) {
      final devices = await _getDevices(participantUid);

      for (final d in devices) {
        final deviceId = d['deviceId'];
        final publicKeyPem = d['publicKey'];
        if (deviceId == null || publicKeyPem == null) continue;

        final docRef = _db
            .collection("chatRooms")
            .doc(roomId)
            .collection("sessionKeys")
            .doc(deviceId);

        // 🔒 Kiểm tra xem device đã có session key chưa (không ghi đè)
        final existing = await docRef.get();
        if (existing.exists) {
          skippedCount++;
          continue; // Đã có key, bỏ qua
        }

        try {
          await docRef.set({
            "userId": participantUid,
            "encryptedKey": base64Encode(
              _rsaEncrypt(sessionKey, _decodePublicKeyFromPem(publicKeyPem)),
            ),
            "createdAt": FieldValue.serverTimestamp(),
          });
          distributedCount++;
          print("🔒 Distributed session key to device $deviceId (user: $participantUid)");
        } catch (e) {
          // Log error nhưng không throw - tiếp tục với device khác
          print("🔒 sessionKey write error for $deviceId: $e");
        }
      }
    }

    if (distributedCount > 0 || skippedCount > 0) {
      print("🔒 Distribution summary: $distributedCount distributed, $skippedCount skipped");
    }
  }

  static Future<List<Map<String, dynamic>>> _getDevices(String uid) async {
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('devices')
        .get();

    return snap.docs.map((d) => {
      'deviceId': d.id,
      'publicKey': d['publicKey'],
    }).toList();
  }



}
