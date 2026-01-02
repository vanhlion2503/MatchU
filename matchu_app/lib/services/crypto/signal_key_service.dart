import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:matchu_app/services/crypto/remote_signal_key.dart';

class SignalKeyService {
  // Algorithms
  static final Ed25519 _signAlgo = Ed25519();
  static final X25519 _dhAlgo = X25519();

  static const FlutterSecureStorage _secure = FlutterSecureStorage();
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const int _initialPreKeyCount = 20;
  
  static const int _minPreKeys = 5;
  static const int _refillCount = 20;


  // ===========================================================
  // INIT SIGNAL (RUN ONCE)
  // ===========================================================

  static Future<void> initSignalForUser(String uid) async {
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('encryptionKeys')
        .doc('signal');

    if ((await ref.get()).exists) return;

    // ===== Identity Signing (Ed25519) =====
    final identitySign = await _signAlgo.newKeyPair();
    final identitySignPub = await identitySign.extractPublicKey();

    await _secure.write(
      key: 'identity_sign_private',
      value: base64Encode(await identitySign.extractPrivateKeyBytes()),
    );

    // ===== Identity DH (X25519) =====
    final identityDh = await _dhAlgo.newKeyPair();
    final identityDhPub = await identityDh.extractPublicKey();

    await _secure.write(
      key: 'identity_dh_private',
      value: base64Encode(await identityDh.extractPrivateKeyBytes()),
    );
    await _secure.write(
      key: 'identity_dh_public',
      value: base64Encode(identityDhPub.bytes),
    );

    // ===== Signed PreKey =====
    final spk = await _dhAlgo.newKeyPair();
    final spkPub = await spk.extractPublicKey();

    final signature = await _signAlgo.sign(
      spkPub.bytes,
      keyPair: identitySign,
    );

    await _secure.write(
      key: 'signed_prekey_private',
      value: base64Encode(await spk.extractPrivateKeyBytes()),
    );

    // ===== One-time PreKeys =====
    final List<Map<String, dynamic>> preKeys = [];

    for (int i = 0; i < _initialPreKeyCount; i++) {
      final kp = await _dhAlgo.newKeyPair();
      final pub = await kp.extractPublicKey();
      final id = DateTime.now().millisecondsSinceEpoch + i;

      await _secure.write(
        key: 'prekey_${id}_private',
        value: base64Encode(await kp.extractPrivateKeyBytes()),
      );

      preKeys.add({
        "id": id,
        "key": base64Encode(pub.bytes),
      });
    }

    // ===== Upload PUBLIC keys =====
    await ref.set({
      "identitySigningKey": base64Encode(identitySignPub.bytes),
      "identityDhKey": base64Encode(identityDhPub.bytes),
      "signedPreKey": {
        "id": 1,
        "key": base64Encode(spkPub.bytes),
        "signature": base64Encode(signature.bytes),
      },
      "preKeys": preKeys,
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  // ===========================================================
  // FETCH + VERIFY REMOTE KEYS
  // ===========================================================

  static Future<RemoteSignalKeys> fetchRemoteKeys(String uid) async {
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('encryptionKeys')
        .doc('signal');

    final snap = await ref.get();
    if (!snap.exists) {
      throw Exception("Remote user chưa init Signal");
    }

    final data = snap.data()!;
    final List preKeys = List.from(data["preKeys"]);

    if (preKeys.isEmpty) {
      throw Exception("Remote user hết one-time preKeys");
    }

    final opk = preKeys.first;

    // Identity signing key (verify only)
    final identitySigningKey = SimplePublicKey(
      base64Decode(data["identitySigningKey"]),
      type: KeyPairType.ed25519,
    );

    // Signed prekey
    final spkData = data["signedPreKey"];
    final signedPreKey = SimplePublicKey(
      base64Decode(spkData["key"]),
      type: KeyPairType.x25519,
    );

    final ok = await _signAlgo.verify(
      base64Decode(spkData["key"]),
      signature: Signature(
        base64Decode(spkData["signature"]),
        publicKey: identitySigningKey,
      ),
    );

    if (!ok) {
      throw Exception("SignedPreKey signature invalid");
    }

    // Consume OPK
    await ref.update({
      "preKeys": FieldValue.arrayRemove([opk]),
    });

    return RemoteSignalKeys(
      identityDhKey: SimplePublicKey(
        base64Decode(data["identityDhKey"]),
        type: KeyPairType.x25519,
      ),
      signedPreKey: signedPreKey,
      oneTimePreKey: SimplePublicKey(
        base64Decode(opk["key"]),
        type: KeyPairType.x25519,
      ),
    );
  }

  static Future<void> refillPreKeysIfNeeded(String uid) async {
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('encryptionKeys')
        .doc('signal');

    final snap = await ref.get();
    if (!snap.exists) return;

    final data = snap.data()!;
    final List preKeys = List.from(data["preKeys"] ?? []);

    if (preKeys.length >= _minPreKeys) return;

    final List<Map<String, dynamic>> newPreKeys = [];

    for (int i = 0; i < _refillCount; i++) {
      final kp = await _dhAlgo.newKeyPair();
      final pub = await kp.extractPublicKey();
      final id = DateTime.now().millisecondsSinceEpoch + i;

      await _secure.write(
        key: 'prekey_${id}_private',
        value: base64Encode(await kp.extractPrivateKeyBytes()),
      );

      newPreKeys.add({
        "id": id,
        "key": base64Encode(pub.bytes),
      });
    }

    await ref.update({
      "preKeys": FieldValue.arrayUnion(newPreKeys),
    });
  }

}
