import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/asn1/primitives/asn1_integer.dart';
import 'package:pointycastle/asn1/primitives/asn1_sequence.dart';
import 'package:pointycastle/export.dart';

class IdentityKeyService {
  static final _storage = FlutterSecureStorage();
  static final _db = FirebaseFirestore.instance;

  static const _privateKeyStorageKey = 'identity_private_key';

  /// ===============================
  /// CHECK EXIST
  /// ===============================
  static Future<bool> hasIdentityKey() async {
    final key = await _storage.read(key: _privateKeyStorageKey);
    return key != null;
  }

  /// ===============================
  /// GENERATE RSA 2048
  /// ===============================
  static Future<void> generateIfNotExists() async {
    final exists = await hasIdentityKey();
    if (exists) return;

    final pair = _generateRSAKeyPair();

    final privatePem = _encodePrivateKeyToPem(pair.privateKey as RSAPrivateKey);
    final publicPem = _encodePublicKeyToPem(pair.publicKey as RSAPublicKey);

    // 🔐 Save private key (LOCAL)
    await _storage.write(
      key: _privateKeyStorageKey,
      value: privatePem,
    );

    // 🌍 Upload public key (FIRESTORE)
    final uid = FirebaseAuth.instance.currentUser!.uid;

    await _db
        .collection('users')
        .doc(uid)
        .collection('encryptionKeys')
        .doc('identity')
        .set({
      'publicKey': publicPem,
      'algorithm': 'RSA-2048',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// ===============================
  /// RSA KEY GENERATION
  /// ===============================
  static AsymmetricKeyPair<PublicKey, PrivateKey> _generateRSAKeyPair() {
    final secureRandom = FortunaRandom();
    final random = Random.secure();

    final seed = Uint8List(32);
    for (int i = 0; i < seed.length; i++) {
      seed[i] = random.nextInt(256);
    }

    secureRandom.seed(KeyParameter(seed));

    final keyGen = RSAKeyGenerator()
      ..init(
        ParametersWithRandom(
          RSAKeyGeneratorParameters(
            BigInt.parse('65537'),
            2048,
            64,
          ),
          secureRandom,
        ),
      );

    return keyGen.generateKeyPair();
  }

  /// ===============================
  /// PEM ENCODERS
  /// ===============================
  static String _encodePrivateKeyToPem(RSAPrivateKey key) {
    final BigInt p = key.p!;
    final BigInt q = key.q!;
    final BigInt d = key.privateExponent!; // 👈 THÊM !

    final BigInt dp = d % (p - BigInt.one);
    final BigInt dq = d % (q - BigInt.one);
    final BigInt qi = q.modInverse(p);

    final topLevel = ASN1Sequence()
      ..add(ASN1Integer(BigInt.zero))
      ..add(ASN1Integer(key.n))
      ..add(ASN1Integer(key.publicExponent))
      ..add(ASN1Integer(d))
      ..add(ASN1Integer(p))
      ..add(ASN1Integer(q))
      ..add(ASN1Integer(dp))
      ..add(ASN1Integer(dq))
      ..add(ASN1Integer(qi));

    final dataBase64 = base64Encode(topLevel.encode());
    return '''
  -----BEGIN RSA PRIVATE KEY-----
  $dataBase64
  -----END RSA PRIVATE KEY-----
  ''';
  }

  static String _encodePublicKeyToPem(RSAPublicKey key) {
    final seq = ASN1Sequence()
      ..add(ASN1Integer(key.n))
      ..add(ASN1Integer(key.exponent));

    final dataBase64 = base64Encode(seq.encode());
    return '-----BEGIN RSA PUBLIC KEY-----\n$dataBase64\n-----END RSA PUBLIC KEY-----';
  }

  static Future<String?> readPrivateKey() {
    return _storage.read(key: _privateKeyStorageKey);
  }

}
