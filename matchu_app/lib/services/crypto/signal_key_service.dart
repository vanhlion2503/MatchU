import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

class SignalKeyService {
  static final _secure = FlutterSecureStorage();
  static final _db = FirebaseFirestore.instance;

  static const int deviceId = 1;
  static const int preKeyCount = 30;

  static Future<void> initSignalForUser(String uid) async {
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('encryptionKeys')
        .doc('signal');

    // 🔥 Nếu đã tồn tại → KHÔNG tạo lại
    if ((await ref.get()).exists) return;

    // ===============================
    // 1️⃣ Identity Key (DÙNG METHOD)
    // ===============================
    final identityKeyPair = generateIdentityKeyPair();

    await _secure.write(
      key: 'signal_identity_private',
      value: base64Encode(
        identityKeyPair.getPrivateKey().serialize(),
      ),
    );

    await _secure.write(
      key: 'signal_identity_public',
      value: base64Encode(
        identityKeyPair.getPublicKey().serialize(),
      ),
    );

    // ===============================
    // 2️⃣ Signed PreKey (DÙNG FIELD)
    // ===============================
    final signedPreKeyId = 1;
    final signedPreKey =
        generateSignedPreKey(identityKeyPair, signedPreKeyId);

    await _secure.write(
      key: 'signal_signed_prekey_${signedPreKeyId}_private',
      value: base64Encode(
        signedPreKey.getKeyPair().privateKey.serialize(),
      ),
    );

    // ===============================
    // 3️⃣ One-time PreKeys (DÙNG FIELD)
    // ===============================
    final preKeys = generatePreKeys(100, preKeyCount);

    for (final p in preKeys) {
      await _secure.write(
        key: 'signal_prekey_${p.id}_private',
        value: base64Encode(
          p.getKeyPair().privateKey.serialize(),
        ),
      );
    }

    // ===============================
    // 4️⃣ Upload PUBLIC bundle
    // ===============================
    await ref.set({
      "identityKey": base64Encode(
        identityKeyPair.getPublicKey().serialize(),
      ),
      "signedPreKey": {
        "keyId": signedPreKeyId,
        "publicKey": base64Encode(
          signedPreKey.getKeyPair().publicKey.serialize(),
        ),
        "signature": base64Encode(
          signedPreKey.signature,
        ),
      },
      "preKeys": preKeys
          .map((p) => {
                "keyId": p.id,
                "publicKey": base64Encode(
                  p.getKeyPair().publicKey.serialize(),
                ),
              })
          .toList(),
      "deviceId": deviceId,
      "createdAt": FieldValue.serverTimestamp(),
    });
  }
}
