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
}