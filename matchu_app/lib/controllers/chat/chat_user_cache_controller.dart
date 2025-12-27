import 'dart:async';
import 'package:get/get.dart';
import 'package:matchu_app/models/user_model.dart';
import 'package:matchu_app/services/user/user_service.dart';

class ChatUserCacheController extends GetxController {
  final UserService _service = UserService();

  /// UID → CachedUser
  final RxMap<String, _CachedUser> _cache = <String, _CachedUser>{}.obs;

  /// TTL (5 phút)
  static const Duration ttl = Duration(minutes: 5);

  /// Timer dọn rác
  Timer? _cleanupTimer;

  @override
  void onInit() {
    super.onInit();

    /// Mỗi 1 phút dọn cache
    _cleanupTimer =
        Timer.periodic(const Duration(minutes: 1), (_) => _cleanup());
  }

  /// ===========================================
  /// LOAD USER NẾU CHƯA CÓ / HẾT TTL
  /// ===========================================
  void loadIfNeeded(String uid) {
    final cached = _cache[uid];

    if (cached != null && !_isExpired(cached)) {
      return; // ✅ cache còn hạn
    }

    _service.getUser(uid).then((user) {
      if (user != null) {
        _cache[uid] = _CachedUser(user);
      }
    });
  }

  void clearAll() {
    _cache.clear();
  }

  /// ===========================================
  /// GET USER (CHO UI)
  /// ===========================================
  UserModel? getUser(String uid) {
    final cached = _cache[uid];
    if (cached == null) return null;
    if (_isExpired(cached)) return null;
    return cached.user;
  }

  /// ===========================================
  /// TTL CHECK
  /// ===========================================
  bool _isExpired(_CachedUser cached) {
    return DateTime.now().difference(cached.cachedAt) > ttl;
  }

  /// ===========================================
  /// CLEANUP
  /// ===========================================
  void _cleanup() {
    final now = DateTime.now();

    _cache.removeWhere((_, cached) {
      return now.difference(cached.cachedAt) > ttl;
    });
  }

  @override
  void onClose() {
    _cleanupTimer?.cancel();
    super.onClose();
  }
}

class _CachedUser {
  final UserModel user;
  final DateTime cachedAt;

  _CachedUser(this.user) : cachedAt = DateTime.now();
}

