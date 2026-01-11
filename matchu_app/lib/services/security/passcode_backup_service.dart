import 'dart:convert';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PasscodeBackupService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static final _storage = FlutterSecureStorage();
  static final _aesGcm = AesGcm.with256bits();

  static const int _backupKeyLength = 32;
  static const int _saltLength = 16;
  static const int _nonceLength = 12;
  static const int _kdfIterations = 150000;

  static String get uid => _auth.currentUser!.uid;
  static String _backupStorageKey(String uid) => 'backup_key_$uid';
  static String _historyLockedKey(String uid) => 'backup_history_locked_$uid';

  static DocumentReference<Map<String, dynamic>> _backupDoc() {
    return _db.collection('users').doc(uid).collection('security').doc('backup');
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
    if (trimmed.isEmpty) {
      throw Exception('Passcode cannot be empty');
    }

    final backupKey = _randomBytes(_backupKeyLength);
    final salt = _randomBytes(_saltLength);
    final nonce = _randomBytes(_nonceLength);

    final derivedKey = await _deriveKey(
      passcode: trimmed,
      salt: salt,
      iterations: _kdfIterations,
    );

    final secretBox = await _aesGcm.encrypt(
      backupKey,
      secretKey: derivedKey,
      nonce: nonce,
    );

    await _backupDoc().set({
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonce),
      'ciphertext': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': _kdfIterations,
      'version': 1,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _storage.write(
      key: _backupStorageKey(uid),
      value: base64Encode(backupKey),
    );

    await setHistoryLocked(lockHistory);
    await backupAllLocalSessionKeys();
  }

  static Future<bool> unlockPasscode(String passcode) async {
    final snap = await _backupDoc().get();
    if (!snap.exists) return false;

    final data = snap.data();
    if (data == null) return false;

    final saltB64 = data['salt'];
    final nonceB64 = data['nonce'];
    final cipherB64 = data['ciphertext'];
    final macB64 = data['mac'];
    if (saltB64 == null ||
        nonceB64 == null ||
        cipherB64 == null ||
        macB64 == null) {
      return false;
    }

    final salt = base64Decode(saltB64);
    final nonce = base64Decode(nonceB64);
    final ciphertext = base64Decode(cipherB64);
    final macBytes = base64Decode(macB64);
    final iterations = (data['iterations'] ?? _kdfIterations) as int;

    try {
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

      final backupKey = await _aesGcm.decrypt(
        secretBox,
        secretKey: derivedKey,
      );

      await _storage.write(
        key: _backupStorageKey(uid),
        value: base64Encode(backupKey),
      );

      await setHistoryLocked(false);
      return true;
    } catch (_) {
      return false;
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

  static Future<void> backupSessionKey({
    required String roomId,
    required Uint8List sessionKey,
    int keyId = 0,
  }) async {
    final backupKey = await _loadBackupKey();
    if (backupKey == null) return;

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
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> backupSessionKeyForRoom(
    String roomId, {
    int keyId = 0,
  }) async {
    final b64 = await _storage.read(
      key: _localSessionKeyKey(roomId, keyId),
    );
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
      if (!keyName.startsWith('chat_') ||
          !keyName.contains('_session_key')) {
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

  static Future<void> resetPasscode() async {
    try {
      await _backupDoc().delete();
    } catch (_) {}

    final snap = await _backupKeysCollection().get();
    if (snap.docs.isNotEmpty) {
      WriteBatch batch = _db.batch();
      int opCount = 0;

      for (final doc in snap.docs) {
        final keysSnap = await doc.reference.collection('keys').get();
        for (final keyDoc in keysSnap.docs) {
          batch.delete(keyDoc.reference);
          opCount++;
          if (opCount >= 400) {
            await batch.commit();
            batch = _db.batch();
            opCount = 0;
          }
        }

        batch.delete(doc.reference);
        opCount++;

        if (opCount >= 400) {
          await batch.commit();
          batch = _db.batch();
          opCount = 0;
        }
      }

      if (opCount > 0) {
        await batch.commit();
      }
    }

    await clearLocalBackupKey();
    await setHistoryLocked(true);
    await _clearLocalSessionKeys();
  }

  static Future<Uint8List?> _loadBackupKey() async {
    final b64 = await _storage.read(key: _backupStorageKey(uid));
    if (b64 == null) return null;
    return base64Decode(b64);
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

  static Future<void> _clearLocalSessionKeys() async {
    final keys = await _storage.readAll();
    for (final k in keys.keys) {
      if (k.startsWith('chat_') && k.contains('_session_key')) {
        await _storage.delete(key: k);
      }
    }
  }
}
