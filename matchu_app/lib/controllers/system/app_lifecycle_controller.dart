import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:matchu_app/services/user/presence_service.dart';

class AppLifecycleController extends GetxController
    with WidgetsBindingObserver {

  StreamSubscription<User?>? _authSub;
  bool _isLoggedIn = false;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);

    // ✅ Lắng nghe auth state
    _authSub = FirebaseAuth.instance
        .authStateChanges()
        .listen(_onAuthChanged);
  }

  void _onAuthChanged(User? user) {
    _isLoggedIn = user != null;

    if (_isLoggedIn) {
      // ✅ CHỈ online khi đã login
      PresenceService.setOnline();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isLoggedIn) return; // ⛔ chưa login thì bỏ qua

    if (state == AppLifecycleState.resumed) {
      PresenceService.setOnline();
    }
  }

  @override
  void onClose() {
    _authSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}
