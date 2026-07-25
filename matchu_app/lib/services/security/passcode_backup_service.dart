import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:matchu_app/services/security/message_crypto_service.dart';

class FaceRecoveryBackupStatus {
  const FaceRecoveryBackupStatus({
    required this.faceVerified,
    required this.backupAvailable,
  });

  final bool faceVerified;
  final bool backupAvailable;

  static const unavailable = FaceRecoveryBackupStatus(
    faceVerified: false,
    backupAvailable: false,
  );
}

class PasscodeVerificationException implements Exception {
  const PasscodeVerificationException();

  @override
  String toString() => 'Mã PIN hiện tại không đúng.';
}

class PasscodeBackupService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static final _storage = FlutterSecureStorage();
  static final _functions = FirebaseFunctions.instance;
  static final _aesGcm = AesGcm.with256bits();

  static const int _backupKeyLength = 32;
  static const int _saltLength = 16;
  static const int _nonceLength = 12;
  static const int _kdfIterations = 150000;

  static String get uid => _auth.currentUser!.uid;
  static String _backupStorageKey(String uid) => 'backup_key_$uid';
  static String _historyLockedKey(String uid) => 'backup_history_locked_$uid';
  static String _generationStorageKey(String uid) => 'backup_generation_$uid';

  static bool isValidPasscode(String passcode) {
    return RegExp(r'^\d{6}$').hasMatch(passcode.trim());
  }

  static DocumentReference<Map<String, dynamic>> _backupDoc() {
    return _db
        .collection('users')
        .doc(uid)
        .collection('security')
        .doc('backup');
  }

  static CollectionReference<Map<String, dynamic>> _backupKeysCollection() {
    return _db.collection('users').doc(uid).collection('sessionKeyBackups');
  }

  static Uint8List _randomBytes(int length) {
    final rand = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => rand.nextInt(256)),
    );
  }

  static Future<bool> hasLocalBackupKey() async {
    final key = await _storage.read(key: _backupStorageKey(uid));
    return key != null;
  }

  static Future<bool> hasBackupOnServer() async {
    final snap = await _backupDoc().get();
    return snap.exists;
  }

  static Future<void> setHistoryLocked(bool locked) async {
    await _storage.write(
      key: _historyLockedKey(uid),
      value: locked ? '1' : '0',
    );
  }

  static Future<bool> isHistoryLocked() async {
    final value = await _storage.read(key: _historyLockedKey(uid));
    return value == '1';
  }

  static Future<void> clearLocalBackupKey() async {
    await _storage.delete(key: _backupStorageKey(uid));
  }

  static Future<void> setPasscode(
    String passcode, {
    bool lockHistory = false,
  }) async {
    final trimmed = passcode.trim();
    if (!isValidPasscode(trimmed)) {
      throw ArgumentError('Mã PIN phải gồm đúng 6 chữ số.');
    }

    final backupKey = _randomBytes(_backupKeyLength);
    final payload = await _wrapBackupKey(
      backupKey: backupKey,
      passcode: trimmed,
    );

    await _backupDoc().set({
      ...payload,
      'generation': 0,
      'credentialVersion': 1,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _storage.write(
      key: _backupStorageKey(uid),
      value: base64Encode(backupKey),
    );
    await _storeGeneration(0);

    await setHistoryLocked(lockHistory);
    await backupAllLocalSessionKeys();
    await syncFaceRecoveryBackupIfEligible();
  }

  static Future<bool> unlockPasscode(String passcode) async {
    if (!isValidPasscode(passcode)) return false;

    final snap = await _backupDoc().get();
    if (!snap.exists) return false;

    final data = snap.data();
    if (data == null) return false;

    try {
      final backupKey = await _unwrapBackupKey(passcode: passcode, data: data);

      await _storage.write(
        key: _backupStorageKey(uid),
        value: base64Encode(backupKey),
      );
      await _storeGeneration(_readGeneration(data));

      await setHistoryLocked(false);
      await _storeFaceRecoveryBackupIfEligible(Uint8List.fromList(backupKey));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Changes only the PIN-derived wrapper. The recovery key and every encrypted
  /// session-key backup remain unchanged, so chat history is preserved.
  static Future<void> changePasscode({
    required String currentPasscode,
    required String newPasscode,
  }) async {
    if (!isValidPasscode(currentPasscode) || !isValidPasscode(newPasscode)) {
      throw ArgumentError('Mã PIN phải gồm đúng 6 chữ số.');
    }
    if (currentPasscode.trim() == newPasscode.trim()) {
      throw ArgumentError('Mã PIN mới phải khác mã PIN hiện tại.');
    }

    final reference = _backupDoc();
    final snapshot = await reference.get();
    final currentData = snapshot.data();
    if (!snapshot.exists || currentData == null) {
      throw StateError('Tài khoản chưa thiết lập mã PIN.');
    }

    Uint8List backupKey;
    try {
      backupKey = await _unwrapBackupKey(
        passcode: currentPasscode,
        data: currentData,
      );
    } catch (_) {
      throw const PasscodeVerificationException();
    }

    final nextWrapper = await _wrapBackupKey(
      backupKey: backupKey,
      passcode: newPasscode,
    );
    final expectedCiphertext = currentData['ciphertext'];
    final currentCredentialVersion =
        (currentData['credentialVersion'] as num?)?.toInt() ?? 1;

    await _db.runTransaction((transaction) async {
      final latest = await transaction.get(reference);
      final latestData = latest.data();
      if (!latest.exists ||
          latestData == null ||
          latestData['ciphertext'] != expectedCiphertext) {
        throw StateError(
          'Mã PIN đã được cập nhật trên thiết bị khác. Vui lòng thử lại.',
        );
      }

      transaction.update(reference, {
        ...nextWrapper,
        'credentialVersion': currentCredentialVersion + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    await _storage.write(
      key: _backupStorageKey(uid),
      value: base64Encode(backupKey),
    );
    await _storeGeneration(_readGeneration(currentData));
    await setHistoryLocked(false);
    await _storeFaceRecoveryBackupIfEligible(backupKey);
  }

  /// Called after face recovery has restored the local recovery key.
  static Future<void> replacePasscodeAfterRecovery(String newPasscode) async {
    if (!isValidPasscode(newPasscode)) {
      throw ArgumentError('Mã PIN phải gồm đúng 6 chữ số.');
    }

    final backupKey = await _loadBackupKey();
    if (backupKey == null) {
      throw StateError('Không tìm thấy khóa khôi phục trên thiết bị.');
    }

    final reference = _backupDoc();
    final snapshot = await reference.get();
    final currentData = snapshot.data();
    if (!snapshot.exists || currentData == null) {
      throw StateError('Không tìm thấy dữ liệu PIN cần khôi phục.');
    }
    final recoveredGeneration = await _loadGeneration();
    if (_readGeneration(currentData) != recoveredGeneration) {
      throw StateError(
        'Khóa khôi phục đã được đặt lại trên thiết bị khác. Vui lòng thử lại.',
      );
    }

    final wrapper = await _wrapBackupKey(
      backupKey: backupKey,
      passcode: newPasscode,
    );
    await _db.runTransaction((transaction) async {
      final latest = await transaction.get(reference);
      final latestData = latest.data();
      if (!latest.exists ||
          latestData == null ||
          _readGeneration(latestData) != recoveredGeneration) {
        throw StateError(
          'Khóa khôi phục đã được đặt lại trên thiết bị khác. Vui lòng thử lại.',
        );
      }
      transaction.update(reference, {
        ...wrapper,
        'credentialVersion':
            ((latestData['credentialVersion'] as num?)?.toInt() ?? 1) + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    await setHistoryLocked(false);
    await _storeFaceRecoveryBackupIfEligible(backupKey);
  }

  static Future<FaceRecoveryBackupStatus> getFaceRecoveryBackupStatus() async {
    try {
      final callable = _functions.httpsCallable('getFaceRecoveryBackupStatus');
      final result = await callable.call();
      final data = result.data;
      if (data is Map) {
        return FaceRecoveryBackupStatus(
          faceVerified: data['faceVerified'] == true,
          backupAvailable: data['available'] == true,
        );
      }
    } catch (e) {
      debugPrint('getFaceRecoveryBackupStatus failed: $e');
    }
    return FaceRecoveryBackupStatus.unavailable;
  }

  static Future<bool> hasFaceRecoveryBackupOnServer() async {
    final status = await getFaceRecoveryBackupStatus();
    return status.faceVerified && status.backupAvailable;
  }

  static Future<bool> unlockWithFaceSession(String sessionId) async {
    final trimmedSessionId = sessionId.trim();
    if (trimmedSessionId.isEmpty) {
      return false;
    }

    try {
      final callable = _functions.httpsCallable('recoverBackupKeyWithFace');
      final result = await callable.call(<String, dynamic>{
        'sessionId': trimmedSessionId,
      });

      final data = result.data;
      if (data is! Map ||
          data['backupKey'] is! String ||
          data['generation'] is! num) {
        return false;
      }

      final backupKey = base64Decode(data['backupKey'] as String);
      if (backupKey.length != _backupKeyLength) {
        return false;
      }

      await _storage.write(
        key: _backupStorageKey(uid),
        value: base64Encode(backupKey),
      );
      await _storeGeneration((data['generation'] as num).toInt());
      await setHistoryLocked(false);
      return true;
    } catch (e) {
      debugPrint('recoverBackupKeyWithFace failed: $e');
      return false;
    }
  }

  static Future<void> syncFaceRecoveryBackupIfEligible() async {
    try {
      final backupKey = await _loadBackupKey();
      if (backupKey == null) return;
      await _storeFaceRecoveryBackupIfEligible(backupKey);
    } catch (e) {
      debugPrint('syncFaceRecoveryBackupIfEligible failed: $e');
    }
  }

  static Future<List<String>> restoreAllSessionKeys() async {
    final backupKey = await _loadBackupKey();
    if (backupKey == null) return [];

    final snap = await _backupKeysCollection().get();
    final restored = <String>{};

    for (final doc in snap.docs) {
      final roomId = doc.id;
      final restoredLegacy = await _restoreKeyFromData(
        roomId: roomId,
        keyId: 0,
        backupKey: backupKey,
        data: doc.data(),
      );
      if (restoredLegacy) {
        restored.add(roomId);
      }

      final keySnap = await doc.reference.collection('keys').get();
      for (final keyDoc in keySnap.docs) {
        final keyId = int.tryParse(keyDoc.id);
        if (keyId == null) continue;
        final restoredKey = await _restoreKeyFromData(
          roomId: roomId,
          keyId: keyId,
          backupKey: backupKey,
          data: keyDoc.data(),
        );
        if (restoredKey) {
          restored.add(roomId);
        }
      }
    }

    return restored.toList();
  }

  static Future<bool> restoreSessionKeyForRoom(
    String roomId, {
    int keyId = 0,
  }) async {
    final backupKey = await _loadBackupKey();
    if (backupKey == null) return false;

    final snap = await _backupKeyDoc(roomId, keyId).get();
    if (!snap.exists) return false;

    final data = snap.data();
    if (data == null) return false;

    return _restoreKeyFromData(
      roomId: roomId,
      keyId: keyId,
      backupKey: backupKey,
      data: data,
    );
  }

  static Future<void> backupSessionKey({
    required String roomId,
    required Uint8List sessionKey,
    int keyId = 0,
  }) async {
    final backupKey = await _loadBackupKey();
    if (backupKey == null) return;
    final generation = await _loadGeneration();

    final nonce = _randomBytes(_nonceLength);
    final secretBox = await _aesGcm.encrypt(
      sessionKey,
      secretKey: SecretKey(backupKey),
      nonce: nonce,
    );

    await _backupKeyDoc(roomId, keyId).set({
      'nonce': base64Encode(nonce),
      'ciphertext': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
      'keyId': keyId,
      'version': 1,
      'generation': generation,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> backupSessionKeyForRoom(
    String roomId, {
    int keyId = 0,
  }) async {
    final b64 = await _storage.read(key: _localSessionKeyKey(roomId, keyId));
    if (b64 == null) return;
    await backupSessionKey(
      roomId: roomId,
      sessionKey: base64Decode(b64),
      keyId: keyId,
    );
  }

  static Future<void> backupAllLocalSessionKeys() async {
    final keys = await _storage.readAll();
    for (final entry in keys.entries) {
      final keyName = entry.key;
      if (!keyName.startsWith('chat_') || !keyName.contains('_session_key')) {
        continue;
      }

      final sessionIndex = keyName.lastIndexOf('_session_key');
      if (sessionIndex == -1) continue;

      final roomId = keyName.substring('chat_'.length, sessionIndex);
      final tail = keyName.substring(sessionIndex + '_session_key'.length);
      int keyId = 0;
      if (tail.startsWith('_')) {
        keyId = int.tryParse(tail.substring(1)) ?? 0;
      }

      try {
        await backupSessionKey(
          roomId: roomId,
          sessionKey: base64Decode(entry.value),
          keyId: keyId,
        );
      } catch (_) {
        continue;
      }
    }
  }

  /// Performs the destructive "forgot PIN" reset. Firebase Auth must have been
  /// reauthenticated immediately before this call.
  static Future<void> resetPasscodeWithNewValue(String newPasscode) async {
    if (!isValidPasscode(newPasscode)) {
      throw ArgumentError('Mã PIN phải gồm đúng 6 chữ số.');
    }

    final backupKey = _randomBytes(_backupKeyLength);
    final wrapper = await _wrapBackupKey(
      backupKey: backupKey,
      passcode: newPasscode,
    );
    final callable = _functions.httpsCallable('resetChatPasscode');
    final result = await callable.call(<String, dynamic>{'backup': wrapper});
    final rawData = result.data;
    if (rawData is! Map || rawData['generation'] is! num) {
      throw StateError('Máy chủ không trả về thế hệ khóa khôi phục hợp lệ.');
    }
    final generation = (rawData['generation'] as num).toInt();

    // Persist the new recovery key first. If best-effort local cleanup is
    // interrupted, the account still remains unlockable with the new PIN.
    await _storage.write(
      key: _backupStorageKey(uid),
      value: base64Encode(backupKey),
    );
    await _storeGeneration(generation);
    await setHistoryLocked(true);
    try {
      await _clearLocalSessionKeys();
    } catch (error) {
      debugPrint('Local session-key cleanup after PIN reset failed: $error');
    }
    MessageCryptoService.clearSessionKeyCache();
    await syncFaceRecoveryBackupIfEligible();
  }

  static Future<Uint8List?> _loadBackupKey() async {
    final b64 = await _storage.read(key: _backupStorageKey(uid));
    if (b64 == null) return null;
    return base64Decode(b64);
  }

  static Future<void> _storeGeneration(int generation) {
    return _storage.write(
      key: _generationStorageKey(uid),
      value: generation.toString(),
    );
  }

  static Future<int> _loadGeneration() async {
    final value = await _storage.read(key: _generationStorageKey(uid));
    return int.tryParse(value ?? '') ?? 0;
  }

  static int _readGeneration(Map<String, dynamic>? data) {
    return (data?['generation'] as num?)?.toInt() ?? 0;
  }

  static Future<bool> _isCurrentUserFaceVerified() async {
    try {
      final snap = await _db.collection('users').doc(uid).get();
      return snap.data()?['isFaceVerified'] == true;
    } catch (e) {
      debugPrint('read face verification state failed: $e');
      return false;
    }
  }

  static Future<void> _storeFaceRecoveryBackupIfEligible(
    Uint8List backupKey,
  ) async {
    if (backupKey.length != _backupKeyLength) return;
    if (!await _isCurrentUserFaceVerified()) return;

    try {
      final callable = _functions.httpsCallable('storeFaceRecoveryBackup');
      final generation = await _loadGeneration();
      await callable.call(<String, dynamic>{
        'backupKey': base64Encode(backupKey),
        'generation': generation,
      });
    } catch (e) {
      debugPrint('storeFaceRecoveryBackup failed: $e');
    }
  }

  static DocumentReference<Map<String, dynamic>> _backupKeyDoc(
    String roomId,
    int keyId,
  ) {
    if (keyId == 0) {
      return _backupKeysCollection().doc(roomId);
    }
    return _backupKeysCollection()
        .doc(roomId)
        .collection('keys')
        .doc(keyId.toString());
  }

  static String _localSessionKeyKey(String roomId, int keyId) {
    if (keyId == 0) {
      return 'chat_${roomId}_session_key';
    }
    return 'chat_${roomId}_session_key_$keyId';
  }

  static Future<bool> _restoreKeyFromData({
    required String roomId,
    required int keyId,
    required Uint8List backupKey,
    required Map<String, dynamic> data,
  }) async {
    final activeGeneration = await _loadGeneration();
    final backupGeneration = _readGeneration(data);
    if (backupGeneration != activeGeneration) return false;

    final nonce = data['nonce'];
    final ciphertext = data['ciphertext'];
    final mac = data['mac'];
    if (nonce == null || ciphertext == null || mac == null) {
      return false;
    }

    try {
      final secretBox = SecretBox(
        base64Decode(ciphertext),
        nonce: base64Decode(nonce),
        mac: Mac(base64Decode(mac)),
      );

      final sessionKey = await _aesGcm.decrypt(
        secretBox,
        secretKey: SecretKey(backupKey),
      );

      if (sessionKey.length != 32) return false;

      await _storage.write(
        key: _localSessionKeyKey(roomId, keyId),
        value: base64Encode(sessionKey),
      );
      MessageCryptoService.cacheSessionKey(
        roomId: roomId,
        keyId: keyId,
        key: Uint8List.fromList(sessionKey),
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<SecretKey> _deriveKey({
    required String passcode,
    required Uint8List salt,
    required int iterations,
  }) {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );

    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passcode)),
      nonce: salt,
    );
  }

  static Future<Map<String, dynamic>> _wrapBackupKey({
    required Uint8List backupKey,
    required String passcode,
  }) async {
    final salt = _randomBytes(_saltLength);
    final nonce = _randomBytes(_nonceLength);
    final derivedKey = await _deriveKey(
      passcode: passcode.trim(),
      salt: salt,
      iterations: _kdfIterations,
    );
    final secretBox = await _aesGcm.encrypt(
      backupKey,
      secretKey: derivedKey,
      nonce: nonce,
    );

    return {
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonce),
      'ciphertext': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': _kdfIterations,
      'version': 1,
    };
  }

  static Future<Uint8List> _unwrapBackupKey({
    required String passcode,
    required Map<String, dynamic> data,
  }) async {
    final salt = base64Decode(data['salt'] as String);
    final nonce = base64Decode(data['nonce'] as String);
    final ciphertext = base64Decode(data['ciphertext'] as String);
    final macBytes = base64Decode(data['mac'] as String);
    final iterations = (data['iterations'] as num?)?.toInt() ?? _kdfIterations;
    final derivedKey = await _deriveKey(
      passcode: passcode.trim(),
      salt: Uint8List.fromList(salt),
      iterations: iterations,
    );
    final secretBox = SecretBox(
      Uint8List.fromList(ciphertext),
      nonce: Uint8List.fromList(nonce),
      mac: Mac(macBytes),
    );
    final clearText = await _aesGcm.decrypt(secretBox, secretKey: derivedKey);
    if (clearText.length != _backupKeyLength) {
      throw StateError('Khóa khôi phục không hợp lệ.');
    }
    return Uint8List.fromList(clearText);
  }

  static Future<void> _clearLocalSessionKeys() async {
    final keys = await _storage.readAll();
    for (final k in keys.keys) {
      if (k.startsWith('chat_') && k.contains('_session_key')) {
        await _storage.delete(key: k);
      }
    }
    MessageCryptoService.clearSessionKeyCache();
  }
}
