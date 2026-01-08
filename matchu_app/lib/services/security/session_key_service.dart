import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  /// STEP 2 — LOAD PUBLIC KEY
  /// ===============================
  static Future<RSAPublicKey> _loadPublicKey(String otherUid) async {
    final snap = await _db
        .collection("users")
        .doc(otherUid)
        .collection("encryptionKeys")
        .doc("identity")
        .get();

    final pem = snap.data()!["publicKey"] as String;
    return _decodePublicKeyFromPem(pem);
  }

  /// ===============================
  /// STEP 3 — RSA ENCRYPT
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
  /// STEP 4 — SEND SESSION KEY
  /// ===============================
  static Future<void> createAndSendSessionKey({
    required String roomId,
    required String receiverUid,
  }) async {
    final ref = _db
        .collection("chatRooms")
        .doc(roomId)
        .collection("sessionKeys")
        .doc(receiverUid);

    if ((await ref.get()).exists) return;

    final sessionKey = _generateAESKey();
    final publicKey = await _loadPublicKey(receiverUid);
    final encrypted = _rsaEncrypt(sessionKey, publicKey);

    await ref.set({
      "from": uid,
      "encryptedKey": base64Encode(encrypted),
      "createdAt": FieldValue.serverTimestamp(),
    });

    await _storage.write(
      key: "chat_${roomId}_session_key",
      value: base64Encode(sessionKey),
    );
  }


  /// ===============================
  /// STEP 5 — RECEIVE & DECRYPT
  /// ===============================
  static Future<bool> receiveSessionKey({
    required String roomId,
  }) async {
    final snap = await _db
        .collection("chatRooms")
        .doc(roomId)
        .collection("sessionKeys")
        .doc(uid)
        .get();

    // ❌ chưa có key
    if (!snap.exists) return false;

    final encrypted = base64Decode(snap["encryptedKey"]);

    final privateKeyPem = await IdentityKeyService.readPrivateKey();
    if (privateKeyPem == null) {
      throw Exception("Identity private key not found");
    }

    final privateKey = _decodePrivateKeyFromPem(privateKeyPem);

    final cipher = OAEPEncoding.withSHA256(RSAEngine())
      ..init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));

    final sessionKey = _processInBlocks(cipher, encrypted);

    // 🔐 save local
    await _storage.write(
      key: "chat_${roomId}_session_key",
      value: base64Encode(sessionKey),
    );

    // 🔔 notify listeners
    _keyUpdateControllers[roomId]?.add(null);

    return true; // ✅ CỰC KỲ QUAN TRỌNG
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


}
