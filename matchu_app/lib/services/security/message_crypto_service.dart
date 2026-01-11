import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';

class MessageCryptoService {
  static final _storage = FlutterSecureStorage();

  // LOAD SESSION KEY

  static Future<Uint8List> _loadSessionKey(
    String roomId, {
    int keyId = 0,
  }) async {
    final storageKey = keyId == 0
        ? "chat_${roomId}_session_key"
        : "chat_${roomId}_session_key_$keyId";
    final b64 = await _storage.read(key: storageKey);
    if (b64 == null) {
      throw Exception(
        "Session key not found for room $roomId (keyId=$keyId)",
      );
    }
    return base64Decode(b64);
  }

  // ENCRYPT MESSAGE (AES-GCM)

  static Future<Map<String, String>> encrypt({
    required String roomId,
    required String plaintext,
    int keyId = 0,
  }) async {
    final key = await _loadSessionKey(roomId, keyId: keyId);

    final iv = _randomBytes(12);

    final cipher = GCMBlockCipher(AESFastEngine())
      ..init(
        true,
        AEADParameters(
          KeyParameter(key),
          128, // auth tag 128-bit
          iv,
          Uint8List(0), // AAD (optional)
        ),
      );
    
    final input = Uint8List.fromList(utf8.encode(plaintext));

    final cipherText = cipher.process(input);

    return {
      "ciphertext": base64Encode(cipherText),
      "iv": base64Encode(iv),
    };
  }

  /// DECRYPT MESSAGE
  

  static Future<String> decrypt({
    required String roomId,
    required String ciphertext,
    required String iv,
    int keyId = 0,
  }) async {
    final key = await _loadSessionKey(roomId, keyId: keyId);

    // 🔒 Validate key length
    if (key.length != 32) {
      throw Exception("Invalid session key length: ${key.length}, expected 32");
    }

    try {
      final cipher = GCMBlockCipher(AESFastEngine())
        ..init(
          false,
          AEADParameters(
            KeyParameter(key),
            128,
            base64Decode(iv),
            Uint8List(0),
          ),
        );
      
      final decrypted = cipher.process(base64Decode(ciphertext));

      return utf8.decode(decrypted);
    } catch (e) {
      // Re-throw với thông tin chi tiết hơn
      throw Exception("AES-GCM decrypt failed: $e");
    }
  }

  static Uint8List _randomBytes(int length){
    final rand = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => rand.nextInt(256)),
    );
  }
}
