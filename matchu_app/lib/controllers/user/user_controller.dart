import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:matchu_app/models/user_model.dart';
import 'package:matchu_app/services/user/user_service.dart';
import 'package:matchu_app/controllers/chat/chat_user_cache_controller.dart';


class UserController extends GetxController {
  final UserService _service = UserService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 🔥 UserModel hiện tại (realtime)
  final Rxn<UserModel> userRx = Rxn<UserModel>();
  UserModel? get user => userRx.value;
  Timer? _heartbeat;

  StreamSubscription<UserModel?>? _userSub;

  // ====================================================
  // INIT
  // ====================================================
  @override
  void onInit() {
    super.onInit();

    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      _bindUser(firebaseUser.uid);
      startHeartbeat();
    }

    /// Lắng nghe đăng xuất / đăng nhập lại
    _auth.authStateChanges().listen((u) {
      if (u == null) {
        userRx.value = null;
        _userSub?.cancel();
        _heartbeat?.cancel();

        if (Get.isRegistered<ChatUserCacheController>()) {
          Get.find<ChatUserCacheController>().clearAll();
        }
      } else {
        _bindUser(u.uid);
        startHeartbeat();
      }
    });

  }

  void startHeartbeat() {
    _heartbeat?.cancel();

    _heartbeat = Timer.periodic(
      const Duration(seconds: 60),
      (_) {
        if (user == null) return;

        _service.updateUser(user!.uid, {
          "lastActiveAt": FieldValue.serverTimestamp(),
          "activeStatus": "online",
        });
      },
    );
  }

  // ====================================================
  // 🔥 BIND USER REALTIME
  // ====================================================
  void _bindUser(String uid) {
    _userSub?.cancel();

    _userSub = _service.streamUser(uid).listen((user) {
      userRx.value = user;
    });
  }

  // ====================================================
  // GETTERS TIỆN DÙNG CHO UI
  // ====================================================
  String get uid => user?.uid ?? "";
  String get avatarUrl => user?.avatarUrl ?? "";
  String get nickname => user?.nickname ?? "";
  String get fullname => user?.fullname ?? "";
  String get email => user?.email ?? "";
  String get status => user?.activeStatus ?? "offline";

  bool get isLoggedIn => user != null;

  // ====================================================
  // 🔥 UPDATE PROFILE (MERGE)
  // ====================================================
  Future<void> updateProfile(Map<String, dynamic> data) async {
    if (user == null) return;
    await _service.updateUser(user!.uid, data);
  }

  // ====================================================
  // FOLLOW / UNFOLLOW
  // ====================================================
  Future<void> follow(String targetUid) {
    return _service.followUser(targetUid);
  }

  Future<void> unfollow(String targetUid) {
    return _service.unfollowUser(targetUid);
  }

  Future<bool> isFollowing(String targetUid) {
    return _service.isFollowing(targetUid);
  }

  // ====================================================
  // 🔥 CLEANUP FOR LOGOUT
  // ====================================================
  void stopHeartbeatAndSubscriptions() {
    _heartbeat?.cancel();
    _heartbeat = null;
    _userSub?.cancel();
    _userSub = null;
  }

  @override
  void onClose() {
    stopHeartbeatAndSubscriptions();
    super.onClose();
  }
}
