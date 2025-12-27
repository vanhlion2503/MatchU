import 'package:get/get.dart';
import 'package:matchu_app/models/user_model.dart';
import 'package:matchu_app/services/user/user_service.dart';

class ChatUserCacheController extends GetxController {
  final UserService _service = UserService();

  /// uid → cached user
  final Map<String, _CachedUser> _cache = {};

  /// TTL: 5 phút
  static const Duration ttl = Duration(minutes: 5);

  /// =========================
  /// LOAD USER
  /// =========================
  void loadIfNeeded(String uid) {
    final cached = _cache[uid];

    if (cached != null && !_isExpired(cached)) {
      return;
    }

    _service.getUser(uid).then((user) {
      if (user != null) {
        _cache[uid] = _CachedUser(user);
      }
    });
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

    _cache.removeWhere((uid, cached) {
      if (aliveUids.contains(uid)) return false;
      return now.difference(cached.cachedAt) > ttl;
    });
  }

  void clearAll() {
    _cache.clear();
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
