import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:matchu_app/services/reputation/reputation_service.dart';
import 'package:matchu_app/services/user/presence_service.dart';

class AppLifecycleController extends GetxController
    with WidgetsBindingObserver {
  StreamSubscription<User?>? _authSub;
  bool _isLoggedIn = false;
  final ReputationService _reputationService = ReputationService();
  DateTime? _lastReputationTouchAt;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  void _onAuthChanged(User? user) {
    _isLoggedIn = user != null;

    if (_isLoggedIn) {
      PresenceService.setOnline();
      _touchDailyLoginTask();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isLoggedIn) return;

    if (state == AppLifecycleState.resumed) {
      PresenceService.setOnline();
      _touchDailyLoginTask();
    }
  }

  Future<void> _touchDailyLoginTask() async {
    if (!_isLoggedIn) return;

    final now = DateTime.now();
    final lastTouch = _lastReputationTouchAt;
    if (lastTouch != null &&
        now.difference(lastTouch) < const Duration(minutes: 2)) {
      return;
    }

    _lastReputationTouchAt = now;
    await _reputationService.touchDailyLoginTaskSilently();
  }

  @override
  void onClose() {
    _authSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}
