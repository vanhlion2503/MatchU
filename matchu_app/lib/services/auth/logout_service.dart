import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:matchu_app/controllers/chat/call_controller.dart';
import 'package:matchu_app/controllers/chat/chat_controller.dart';

import '../../controllers/user/user_controller.dart';
import '../../controllers/chat/anonymous_avatar_controller.dart';
import '../../controllers/chat/chat_user_cache_controller.dart';
import '../../controllers/user/presence_controller.dart';
import '../../controllers/chat/unread_controller.dart';
import '../../controllers/chat/chat_list_controller.dart';
import '../../controllers/profile/profile_controller.dart';
import '../../controllers/auth/avatar_controller.dart';
import '../../services/user/presence_service.dart';
import '../../services/security/device_service.dart';
import '../../services/security/message_crypto_service.dart';

class LogoutService {
  static final _auth = FirebaseAuth.instance;
  static final _storage = FlutterSecureStorage();

  /// 🔥 LOGOUT CHUẨN – DÙNG CHO TOÀN APP
  static Future<bool> logout() async {
    // 🔥 LẤY UID TRƯỚC KHI LOGOUT (QUAN TRỌNG!)
    final currentUser = _auth.currentUser;
    final uid = currentUser?.uid;

    try {
      // 1️⃣ Update offline (Firestore + Realtime Database) - TRƯỚC KHI DỪNG CÁC SERVICES
      if (currentUser != null && uid != null) {
        try {
          // 1️⃣.1️⃣ Update Firestore offline
          var didUpdateFirestorePresence = false;
          if (Get.isRegistered<UserController>()) {
            try {
              await Get.find<UserController>().updateProfile({
                "activeStatus": "offline",
              });
              didUpdateFirestorePresence = true;
            } catch (e) {
              // Ignore errors - continue
            }
          }

          if (!didUpdateFirestorePresence) {
            try {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .set({
                    "activeStatus": "offline",
                    "lastActiveAt": FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
            } catch (e) {
              // Ignore errors - continue
            }
          }

          // 1️⃣.2️⃣ Update Realtime Database offline (QUAN TRỌNG!)
          // 🔥 PHẢI SET OFFLINE TRƯỚC KHI SIGN OUT!
          try {
            await PresenceService.setOffline();
          } catch (e) {
            // Nếu có lỗi, thử set offline với uid trực tiếp
            try {
              await PresenceService.setOfflineForUid(uid);
            } catch (_) {
              // Ignore - đã cố gắng hết cách
            }
          }

          await _markCurrentDeviceInactive(uid);
        } catch (e) {
          // Ignore errors - continue with logout
        }
      }

      // 2️⃣ DỪNG HEARTBEAT VÀ SUBSCRIPTIONS TRƯỚC KHI CLEAR STATE
      if (Get.isRegistered<UserController>()) {
        try {
          final u = Get.find<UserController>();
          await u.stopHeartbeatAndSubscriptionsAsync();
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
          await Get.find<UnreadController>().cleanupAsync();
        } catch (e) {
          // Ignore errors - continue with logout
        }
      }

      // 4️⃣.5️⃣ DỪNG CHAT LIST STREAM
      if (Get.isRegistered<ChatListController>()) {
        try {
          await Get.find<ChatListController>().cleanupAsync();
        } catch (e) {
          // Ignore errors - continue with logout
        }
      }

      // 4️⃣.6️⃣ DỪNG PROFILE STREAM
      if (Get.isRegistered<ProfileController>()) {
        try {
          await Get.find<ProfileController>().cleanupAsync();
        } catch (e) {
          // Ignore errors - continue with logout
        }
      }

      // 4️⃣.7️⃣ DỪNG AVATAR STREAM
      if (Get.isRegistered<AvatarController>()) {
        try {
          await Get.find<AvatarController>().cleanupAsync();
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
          await Get.find<AnonymousAvatarController>().resetAsync();
        } catch (e) {
          // Ignore errors - continue with logout
        }
      }

      // 7️⃣.5️⃣ 🔥 HUỶ TẤT CẢ CHAT CONTROLLERS
      try {
        Get.delete<ChatController>(force: true);
      } catch (_) {}

      if (Get.isRegistered<CallController>()) {
        try {
          await Get.find<CallController>().endCall();
        } catch (_) {}
      }

      // 8️⃣ ❗ CLEAR SESSION KEYS (KHÔNG XOÁ IDENTITY KEY)
      try {
        final keys = await _storage.readAll();
        for (final k in keys.keys) {
          if (k.startsWith("chat_") && k.contains("_session_key")) {
            await _storage.delete(key: k);
          }
        }
        MessageCryptoService.clearSessionKeyCache();
      } catch (e) {
        // Ignore errors - continue with logout
      }

      // 8️⃣.5️⃣ 🔥 ĐỢI MỘT CHÚT ĐỂ ĐẢM BẢO TẤT CẢ LISTENERS ĐÃ ĐƯỢC CANCEL
      // Tránh race condition khi signOut() được gọi trong khi listeners còn active
      await Future.delayed(const Duration(milliseconds: 100));

      // 8️⃣.6️⃣ 🔥 TẮT NETWORK FIRESTORE TRƯỚC KHI SIGN OUT
      // Tránh listener còn active bắn permission denied sau khi auth = null
      try {
        await FirebaseFirestore.instance.disableNetwork();
      } catch (e) {
        // Ignore errors - continue with logout
      }

      // 9️⃣ Firebase sign out
      await _auth.signOut();
      return true;
    } catch (e) {
      debugPrint('Logout error: $e');
      return false;
    }
  }

  static Future<void> _markCurrentDeviceInactive(String uid) async {
    try {
      final deviceId = await DeviceService.getDeviceId();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('devices')
          .doc(deviceId)
          .set({
            'e2eeStatus': 'inactive',
            'signedOutAt': FieldValue.serverTimestamp(),
            'e2eeUpdatedAt': FieldValue.serverTimestamp(),
            'lastActiveAt': FieldValue.serverTimestamp(),
            'pushEnabled': false,
            'fcmToken': FieldValue.delete(),
            'fcmTokenUpdatedAt': FieldValue.delete(),
          }, SetOptions(merge: true));
    } catch (_) {}
  }
}
