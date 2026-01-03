import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:matchu_app/services/crypto/remote_signal_key.dart';

class SignalKeyService {
  // ================== ALGORITHMS ==================
  static final Ed25519 _signAlgo = Ed25519();
  static final X25519 _dhAlgo = X25519();

  // ================== STORAGE ==================
  static const FlutterSecureStorage _secure = FlutterSecureStorage();
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ================== CONFIG ==================
  static const int _initialPreKeyCount = 20;
  static const int _minPreKeys = 5;
  static const int _refillCount = 20;

  // ===========================================================
  // INIT SIGNAL (CLIENT-SAFE, MULTI-DEVICE SAFE)
  // ===========================================================

  static Future<void> initSignalForUser(String uid) async {
    // 1️⃣ CHECK LOCAL PRIVATE KEYS (SOURCE OF TRUTH)
    final hasLocalIdentity =
        await _secure.containsKey(key: 'identity_sign_private') &&
        await _secure.containsKey(key: 'identity_dh_private') &&
        await _secure.containsKey(key: 'identity_dh_public');

    if (!hasLocalIdentity) {
      await _generateLocalIdentity();
    }

    // 2️⃣ CHECK FIRESTORE PUBLIC KEYS
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('encryptionKeys')
        .doc('signal');

    if ((await ref.get()).exists) {
      return; // ✅ public keys đã publish
    }

    // 3️⃣ UPLOAD PUBLIC KEYS (RUN ONCE)
    await _publishPublicKeys(ref);
  }

  // ===========================================================
  // LOCAL IDENTITY GENERATION
  // ===========================================================

  static Future<void> _generateLocalIdentity() async {
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
    for (int i = 0; i < _initialPreKeyCount; i++) {
      final kp = await _dhAlgo.newKeyPair();
      final id = DateTime.now().millisecondsSinceEpoch + i;

      await _secure.write(
        key: 'prekey_${id}_private',
        value: base64Encode(await kp.extractPrivateKeyBytes()),
      );
    }
  }

  // ===========================================================
  // PUBLISH PUBLIC KEYS TO FIRESTORE
  // ===========================================================

  static Future<void> _publishPublicKeys(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    final identityDhPub =
        base64Decode((await _secure.read(key: 'identity_dh_public'))!);

    final identitySignPriv =
        base64Decode((await _secure.read(key: 'identity_sign_private'))!);

    final identitySign = SimpleKeyPairData(
      identitySignPriv,
      publicKey: await Ed25519()
          .newKeyPairFromSeed(identitySignPriv)
          .then((k) => k.extractPublicKey()),
      type: KeyPairType.ed25519,
    );

    final spkPriv =
        base64Decode((await _secure.read(key: 'signed_prekey_private'))!);

    final spk = SimpleKeyPairData(
      spkPriv,
      publicKey: SimplePublicKey(
        await X25519()
            .newKeyPairFromSeed(spkPriv)
            .then((k) => k.extractPublicKey())
            .then((k) => k.bytes),
        type: KeyPairType.x25519,
      ),
      type: KeyPairType.x25519,
    );

    final spkPub = await spk.extractPublicKey();

    final signature = await _signAlgo.sign(
      spkPub.bytes,
      keyPair: identitySign,
    );

    // build preKeys public list
    final List<Map<String, dynamic>> preKeys = [];

    final allKeys = await _secure.readAll();
    for (final entry in allKeys.entries) {
      if (!entry.key.startsWith("prekey_")) continue;

      final id =
          int.tryParse(entry.key.replaceAll("prekey_", "").replaceAll("_private", ""));
      if (id == null) continue;

      final priv = base64Decode(entry.value);
      final kp = await _dhAlgo.newKeyPairFromSeed(priv);
      final pub = await kp.extractPublicKey();

      preKeys.add({
        "id": id,
        "key": base64Encode(pub.bytes),
      });
    }

    await ref.set({
      "identityDhKey": base64Encode(identityDhPub),
      "identitySigningKey":
          base64Encode((await identitySign.extractPublicKey()).bytes),
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
  // FETCH + VERIFY REMOTE KEYS (READ ONLY)
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
    final List preKeys = List.from(data["preKeys"] ?? []);

    if (preKeys.isEmpty) {
      throw Exception("Remote user hết one-time preKeys");
    }

    final opk = preKeys.first;

    // Verify signed prekey
    final identitySigningKey = SimplePublicKey(
      base64Decode(data["identitySigningKey"]),
      type: KeyPairType.ed25519,
    );

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
      oneTimePreKeyId: opk["id"],
    );
  }

  // ===========================================================
  // REFILL PREKEYS (LOCAL + FIRESTORE)
  // ===========================================================

  static Future<void> refillPreKeysIfNeeded(String uid) async {
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('encryptionKeys')
        .doc('signal');

    final snap = await ref.get();
    if (!snap.exists) return;

    final List preKeys = List.from(snap.data()!["preKeys"] ?? []);
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
