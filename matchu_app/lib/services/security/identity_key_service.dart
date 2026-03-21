import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:matchu_app/services/security/device_service.dart';
import 'package:pointycastle/asn1/primitives/asn1_integer.dart';
import 'package:pointycastle/asn1/primitives/asn1_sequence.dart';
import 'package:pointycastle/export.dart';

class IdentityKeyService {
  static final _storage = FlutterSecureStorage();
  static final _db = FirebaseFirestore.instance;

  static String _privateKeyKey(String uid, String deviceId) =>
      'identity_${uid}_$deviceId';

  /// ===============================
  /// CHECK EXIST
  /// ===============================
  static Future<bool> hasIdentityKey() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final uid = user.uid;
    final deviceId = await DeviceService.getDeviceId();

    final key = await _storage.read(key: _privateKeyKey(uid, deviceId));
    return key != null;
  }

  /// ===============================
  /// GENERATE RSA 2048
  /// ===============================
  static Future<void> generateIfNotExists() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final deviceId = await DeviceService.getDeviceId();
    final keyKey = _privateKeyKey(uid, deviceId);

    String? privatePem = await _storage.read(key: keyKey);
    late final String publicPem;

    if (privatePem == null) {
      final pair = _generateRSAKeyPair();
      privatePem = _encodePrivateKeyToPem(pair.privateKey as RSAPrivateKey);
      publicPem = _encodePublicKeyToPem(pair.publicKey as RSAPublicKey);

      await _storage.write(key: keyKey, value: privatePem);
    } else {
      publicPem = _extractPublicKeyFromPrivatePem(privatePem);
    }

    await _ensureDeviceDoc(uid: uid, deviceId: deviceId, publicPem: publicPem);
  }

  static Future<void> _ensureDeviceDoc({
    required String uid,
    required String deviceId,
    required String publicPem,
  }) async {
    final docRef = _db
        .collection('users')
        .doc(uid)
        .collection('devices')
        .doc(deviceId);
    final snap = await docRef.get();

    if (snap.exists) {
      await docRef.set({
        'publicKey': publicPem,
        'algorithm': 'RSA-2048',
        'platform': _platformName(),
        'lastActiveAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    await docRef.set({
      'publicKey': publicPem,
      'algorithm': 'RSA-2048',
      'platform': _platformName(),
      'createdAt': FieldValue.serverTimestamp(),
      'lastActiveAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static String _platformName() {
    if (kIsWeb) return 'web';

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  static String _extractPublicKeyFromPrivatePem(String pem) {
    final clean = pem
        .replaceAll('-----BEGIN RSA PRIVATE KEY-----', '')
        .replaceAll('-----END RSA PRIVATE KEY-----', '')
        .replaceAll(RegExp(r'\s'), '');

    final bytes = base64Decode(clean);
    final seq = ASN1Sequence.fromBytes(bytes);

    final modulus = (seq.elements![1] as ASN1Integer).integer!;
    final exponent = (seq.elements![2] as ASN1Integer).integer!;
    return _encodePublicKeyToPem(RSAPublicKey(modulus, exponent));
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

    final keyGen =
        RSAKeyGenerator()..init(
          ParametersWithRandom(
            RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
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

    final topLevel =
        ASN1Sequence()
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
    final seq =
        ASN1Sequence()
          ..add(ASN1Integer(key.n))
          ..add(ASN1Integer(key.exponent));

    final dataBase64 = base64Encode(seq.encode());
    return '-----BEGIN RSA PUBLIC KEY-----\n$dataBase64\n-----END RSA PUBLIC KEY-----';
  }

  static Future<String?> readPrivateKey() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final uid = user.uid;
    final deviceId = await DeviceService.getDeviceId();

    return _storage.read(key: _privateKeyKey(uid, deviceId));
  }
}
