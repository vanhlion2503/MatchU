import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:matchu_app/services/crypto/session_state.dart';

class SecureSessionStore {
  static final _secure = FlutterSecureStorage();
  static final Map<String, SessionState> _cache = {};

  static Future<bool> has(String uid) async {
    if (_cache.containsKey(uid)) return true;
    return await _secure.containsKey(key: 'session_$uid');
  }

  static Future<SessionState?> get(String uid) async {
    if (_cache.containsKey(uid)) return _cache[uid];

    final raw = await _secure.read(key: 'session_$uid');
    if (raw == null) return null;

    final session =
        SessionState.fromJson(jsonDecode(raw));
    _cache[uid] = session;
    return session;
  }

  static Future<void> save(
    String uid,
    SessionState session,
  ) async {
    _cache[uid] = session;
    await _secure.write(
      key: 'session_$uid',
      value: jsonEncode(session.toJson()),
    );
  }

  static Future<void> clear(String uid) async {
    _cache.remove(uid);
    await _secure.delete(key: 'session_$uid');
  }
}
