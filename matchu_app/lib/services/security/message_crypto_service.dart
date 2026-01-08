import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';

class MessageCryptoService {
  static final _storage = FlutterSecureStorage();

  // LOAD SESSION KEY

  static Future<Uint8List> _loadSessionKey(String roomId) async {
    final b64 = await _storage.read(key: "chat_${roomId}_session_key");
    if (b64 == null) {
      throw Exception("Session key not found for room $roomId");
    }
    return base64Decode(b64);
  }

  // ENCRYPT MESSAGE (AES-GCM)

  static Future<Map<String, String>> encrypt({
    required String roomId,
    required String plaintext,
  }) async {
    final key = await _loadSessionKey(roomId);

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
  }) async {
    final key = await _loadSessionKey(roomId);

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
  }

  static Uint8List _randomBytes(int length){
    final rand = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => rand.nextInt(256)),
    );
  }
}