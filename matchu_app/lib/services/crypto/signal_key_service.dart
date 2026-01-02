import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignalKeyService {
  static final _algo = X25519();
  static final _secure = FlutterSecureStorage();
  static final _db = FirebaseFirestore.instance;

  static Future<SimpleKeyPair> generateIdentityKey() async {
    return await _algo.newKeyPair();
  }

  static Future<void> saveIdentityPrivate(SimpleKeyPair keyPair) async {
    final privateBytes = await keyPair.extractPrivateKeyBytes();
    await _secure.write(
      key: 'identity_private', 
      value: base64Encode(privateBytes),
      );
  }

  static Future<Map<String, dynamic>> generateSignedPreKey(
    SimpleKeyPair identityKey,
  ) async {
    final preKey = await _algo.newKeyPair();
    final publicBytes = await preKey.extractPublicKey().then((k) => k.bytes);

    final signature = await Ed25519().sign(
      publicBytes,
      keyPair: identityKey,
    );

    final privateBytes = await preKey.extractPrivateKeyBytes();

    await _secure.write(
      key: 'signed_prekey_private',
      value: base64Encode(privateBytes),
    );

    return {
      "id": 1,
      "key": base64Encode(publicBytes),
      "signature": base64Encode(signature.bytes),
    };
  }

  static Future<List<Map<String, dynamic>>> generatePreKeys() async {
    final List<Map<String, dynamic>> list = [];

    for (int i = 1; i <= 20; i++) {
      final kp = await _algo.newKeyPair();
      final pub = await kp.extractPublicKey().then((k) => k.bytes);
      final priv = await kp.extractPrivateKeyBytes();

      await _secure.write(
        key: 'prekey_${i}_private',
        value: base64Encode(priv),
      );

      list.add({
        "id": i,
        "key": base64Encode(pub),
      });
    }
    return list;
  }

  static Future<void> uploadKeys({
    required String uid,
    required String identityPublic,
    required Map<String, dynamic> signedPreKey,
    required List<Map<String, dynamic>> preKeys,
  }) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('encryptionKeys')
        .doc('signal')
        .set({
      "identityKey": identityPublic,
      "signedPreKey": signedPreKey,
      "preKeys": preKeys,
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  static Future<void> initSignalForUser(String uid) async {
    // 1. Check đã có key chưa (Firestore)
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('encryptionKeys')
        .doc('signal')
        .get();

    if (snap.exists) return; // ✅ ĐÃ CÓ → KHÔNG TẠO LẠI

    // 2. Identity key
    final identityKey = await generateIdentityKey();
    final identityPub = await identityKey
        .extractPublicKey()
        .then((k) => base64Encode(k.bytes));

    await saveIdentityPrivate(identityKey);

    // 3. Signed prekey
    final signedPreKey = await generateSignedPreKey(identityKey);

    // 4. One-time prekeys
    final preKeys = await generatePreKeys();

    // 5. Upload Firestore
    await uploadKeys(
      uid: uid,
      identityPublic: identityPub,
      signedPreKey: signedPreKey,
      preKeys: preKeys,
    );
  }


}