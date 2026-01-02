import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:matchu_app/services/crypto/remote_signal_key.dart';
import 'session_state.dart';
import 'session_store.dart';

class X3dhService {
  static final X25519 _algo = X25519();
  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  static Future<SimpleKeyPair> _loadDhIdentity() async {
    final priv = await _secure.read(key: 'identity_dh_private');
    final pub = await _secure.read(key: 'identity_dh_public');

    return SimpleKeyPairData(
      base64Decode(priv!),
      publicKey: SimplePublicKey(
        base64Decode(pub!),
        type: KeyPairType.x25519,
      ),
      type: KeyPairType.x25519,
    );
  }

  static Future<void> establishSession({
    required String remoteUid,
    required RemoteSignalKeys remote,
    required bool initiator,
  }) async {
    final identityDh = await _loadDhIdentity();
    final eph = await _algo.newKeyPair();

    final dh1 = await _algo.sharedSecretKey(
      keyPair: identityDh,
      remotePublicKey: remote.signedPreKey,
    );

    final dh2 = await _algo.sharedSecretKey(
      keyPair: eph,
      remotePublicKey: remote.identityDhKey,
    );

    final dh3 = await _algo.sharedSecretKey(
      keyPair: eph,
      remotePublicKey: remote.signedPreKey,
    );

    final dh4 = await _algo.sharedSecretKey(
      keyPair: eph,
      remotePublicKey: remote.oneTimePreKey,
    );

    final combined = <int>[
      ...await dh1.extractBytes(),
      ...await dh2.extractBytes(),
      ...await dh3.extractBytes(),
      ...await dh4.extractBytes(),
    ];

    final hkdf = Hkdf(
      hmac: Hmac.sha256(),
      outputLength: 64,
    );

    final material = await hkdf.deriveKey(
      secretKey: SecretKey(combined),
      info: utf8.encode("X3DH"),
    );

    final bytes = await material.extractBytes();

    final rootKey = bytes.sublist(0, 32);
    final chainKey = bytes.sublist(32, 64);

    final session = SessionState(
      rootKey: rootKey,
      sendingChainKey: initiator ? chainKey : rootKey,
      receivingChainKey: initiator ? rootKey : chainKey,
    );

    SessionStore.save(remoteUid, session);
  }
}
