import 'package:get/get.dart';
import 'package:matchu_app/models/user_model.dart';
import 'package:matchu_app/services/user/user_service.dart';

class ChatUserCacheController extends GetxController {
  final UserService _service = UserService();

  /// uid → cached user
  final RxMap<String, _CachedUser> _cache = <String, _CachedUser>{}.obs;
  final Map<String, Future<UserModel?>> _pendingLoads = {};
  int _generation = 0;

  final RxInt version = 0.obs;

  /// TTL: 5 phút
  static const Duration ttl = Duration(minutes: 5);

  /// =========================
  /// LOAD USER
  /// =========================
  Future<UserModel?> loadIfNeeded(String uid) {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) return Future.value(null);

    final cached = _cache[normalizedUid];

    if (cached != null && !_isExpired(cached)) {
      return Future.value(cached.user);
    }

    final pending = _pendingLoads[normalizedUid];
    if (pending != null) return pending;

    final generation = _generation;
    final future = _service
        .getUser(normalizedUid)
        .then<UserModel?>((user) {
          if (user != null && generation == _generation) {
            _cache[normalizedUid] = _CachedUser(user);
            version.value++;
          }
          return user;
        })
        .catchError((_) => null)
        .whenComplete(() {
          _pendingLoads.remove(normalizedUid);
        });

    _pendingLoads[normalizedUid] = future;
    return future;
  }

  /// =========================
  /// GET USER
  /// =========================
  UserModel? getUser(String uid) {
    final cached = _cache[uid];
    if (cached == null) return null;
    if (_isExpired(cached)) return null;
    return cached.user;
  }

  /// =========================
  /// CLEANUP (CHỈ KHI UI YÊU CẦU)
  /// =========================
  void cleanupExcept(Set<String> aliveUids) {
    final now = DateTime.now();
    final beforeLength = _cache.length;

    _cache.removeWhere((uid, cached) {
      if (aliveUids.contains(uid)) return false;
      return now.difference(cached.cachedAt) > ttl;
    });

    if (_cache.length != beforeLength) {
      version.value++;
    }
  }

  void clearAll() {
    _generation++;
    _cache.clear();
    _pendingLoads.clear();
    version.value++;
  }

  bool _isExpired(_CachedUser cached) {
    return DateTime.now().difference(cached.cachedAt) > ttl;
  }
}

class _CachedUser {
  final UserModel user;
  final DateTime cachedAt;

  _CachedUser(this.user) : cachedAt = DateTime.now();
}
