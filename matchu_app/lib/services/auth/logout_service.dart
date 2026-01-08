import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../controllers/user/user_controller.dart';
import '../../controllers/chat/anonymous_avatar_controller.dart';
import '../../controllers/chat/chat_user_cache_controller.dart';
import '../../controllers/user/presence_controller.dart';
import '../../controllers/chat/unread_controller.dart';

class LogoutService {
  static final _auth = FirebaseAuth.instance;
  static final _storage = FlutterSecureStorage();

  /// 🔥 LOGOUT CHUẨN – DÙNG CHO TOÀN APP
  static Future<void> logout() async {
    try {
      // 1️⃣ Update offline (Firestore) - TRƯỚC KHI DỪNG CÁC SERVICES
      if (_auth.currentUser != null) {
        try {
          if (Get.isRegistered<UserController>()) {
            await Get.find<UserController>()
                .updateProfile({"activeStatus": "offline"});
          }
        } catch (e) {
          // Ignore errors - continue with logout
        }
      }

      // 2️⃣ DỪNG HEARTBEAT VÀ SUBSCRIPTIONS TRƯỚC KHI CLEAR STATE
      if (Get.isRegistered<UserController>()) {
        try {
          final u = Get.find<UserController>();
          u.stopHeartbeatAndSubscriptions();
        } catch (e) {
          // Ignore errors - continue with logout
        }
      }

      // 3️⃣ DỪNG PRESENCE REALTIME
      if (Get.isRegistered<PresenceController>()) {
        try {
          Get.find<PresenceController>().cleanup();
        } catch (e) {
          // Ignore errors - continue with logout
        }
      }

      // 4️⃣ DỪNG UNREAD STREAM
      if (Get.isRegistered<UnreadController>()) {
        try {
          Get.find<UnreadController>().cleanup();
        } catch (e) {
          // Ignore errors - continue with logout
        }
      }

      // 5️⃣ CLEAR USER STATE
      if (Get.isRegistered<UserController>()) {
        try {
          Get.find<UserController>().userRx.value = null;
        } catch (e) {
          // Ignore errors - continue with logout
        }
      }

      // 6️⃣ Clear chat cache
      if (Get.isRegistered<ChatUserCacheController>()) {
        try {
          Get.find<ChatUserCacheController>().clearAll();
        } catch (e) {
          // Ignore errors - continue with logout
        }
      }

      // 7️⃣ Reset anonymous avatar
      if (Get.isRegistered<AnonymousAvatarController>()) {
        try {
          Get.find<AnonymousAvatarController>().reset();
        } catch (e) {
          // Ignore errors - continue with logout
        }
      }

      // 8️⃣ ❗ CLEAR SESSION KEYS (KHÔNG XOÁ IDENTITY KEY)
      try {
        final keys = await _storage.readAll();
        for (final k in keys.keys) {
          if (k.startsWith("chat_") && k.endsWith("_session_key")) {
            await _storage.delete(key: k);
          }
        }
      } catch (e) {
        // Ignore errors - continue with logout
      }

      // 9️⃣ Firebase sign out
      await _auth.signOut();

      // 🔟 Điều hướng
      Get.offAllNamed('/');
    } catch (e) {
      // Đảm bảo luôn điều hướng ngay cả khi có lỗi
      Get.offAllNamed('/');
    }
  }
}
