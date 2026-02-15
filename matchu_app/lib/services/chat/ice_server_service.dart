import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class IceServerService {
  final FirebaseFunctions _functions;

  IceServerService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  List<Map<String, dynamic>>? _cachedIceServers;
  DateTime? _cacheExpiresAt;

  Future<List<Map<String, dynamic>>> getIceServers() async {
    final now = DateTime.now();
    final cached = _cachedIceServers;
    final expiresAt = _cacheExpiresAt;

    if (cached != null &&
        expiresAt != null &&
        now.isBefore(expiresAt) &&
        cached.isNotEmpty) {
      return cached;
    }

    try {
      final callable = _functions.httpsCallable('getTurnCredentials');
      final result = await callable.call();
      final data = result.data;

      if (data is! Map) {
        throw StateError('Invalid TURN response payload.');
      }

      final servers = _normalizeIceServers(data['iceServers']);
      if (servers.isEmpty) {
        throw StateError('No valid ICE servers returned.');
      }

      final ttlSecondsRaw = data['ttl'];
      final ttlSeconds = ttlSecondsRaw is num ? ttlSecondsRaw.toInt() : 600;
      final boundedTtl = ttlSeconds.clamp(60, 3600);

      _cachedIceServers = servers;
      _cacheExpiresAt = now.add(Duration(seconds: boundedTtl));
      return servers;
    } catch (error) {
      debugPrint('ICE server fetch failed: $error');
      return const <Map<String, dynamic>>[];
    }
  }

  void clearCache() {
    _cachedIceServers = null;
    _cacheExpiresAt = null;
  }

  List<Map<String, dynamic>> _normalizeIceServers(dynamic raw) {
    if (raw is! List) return const <Map<String, dynamic>>[];

    final output = <Map<String, dynamic>>[];

    for (final item in raw) {
      if (item is! Map) continue;

      final urls = item['urls'];
      if (urls is! String && urls is! List) continue;

      final server = <String, dynamic>{'urls': urls};

      final username = item['username'];
      if (username is String && username.isNotEmpty) {
        server['username'] = username;
      }

      final credential = item['credential'];
      if (credential is String && credential.isNotEmpty) {
        server['credential'] = credential;
      }

      output.add(server);
    }

    return output;
  }
}
