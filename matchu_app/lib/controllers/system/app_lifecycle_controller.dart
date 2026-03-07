import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:matchu_app/services/reputation/reputation_service.dart';
import 'package:matchu_app/services/user/presence_service.dart';

class AppLifecycleController extends GetxController
    with WidgetsBindingObserver {
  StreamSubscription<User?>? _authSub;
  Timer? _usageHeartbeatTimer;
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
    final wasLoggedIn = _isLoggedIn;
    _isLoggedIn = user != null;

    if (!_isLoggedIn) {
      _stopUsageHeartbeat();
      return;
    }

    PresenceService.setOnline();
    _touchDailyLoginTask(
      source: wasLoggedIn ? "auth_refresh" : "auth_login",
      force: true,
    );
    _startUsageHeartbeat();
  }

  void _startUsageHeartbeat() {
    if (!_isLoggedIn) return;
    _usageHeartbeatTimer?.cancel();
    _usageHeartbeatTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _touchDailyLoginTask(source: "heartbeat");
    });
  }

  void _stopUsageHeartbeat() {
    _usageHeartbeatTimer?.cancel();
    _usageHeartbeatTimer = null;
  }

  String _sourceForInactiveState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
        return "inactive";
      case AppLifecycleState.hidden:
        return "hidden";
      case AppLifecycleState.paused:
        return "pause";
      case AppLifecycleState.detached:
        return "detached";
      case AppLifecycleState.resumed:
        return "resume";
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isLoggedIn) return;

    if (state == AppLifecycleState.resumed) {
      PresenceService.setOnline();
      _touchDailyLoginTask(source: "resume", force: true);
      _startUsageHeartbeat();
      return;
    }

    _touchDailyLoginTask(source: _sourceForInactiveState(state), force: true);
    _stopUsageHeartbeat();
  }

  Future<void> _touchDailyLoginTask({
    String source = "app_open",
    bool force = false,
  }) async {
    if (!_isLoggedIn) return;

    final now = DateTime.now();
    final lastTouch = _lastReputationTouchAt;
    if (!force &&
        lastTouch != null &&
        now.difference(lastTouch) < const Duration(seconds: 20)) {
      return;
    }

    _lastReputationTouchAt = now;
    await _reputationService.touchDailyLoginTaskSilently(source: source);
  }

  @override
  void onClose() {
    _authSub?.cancel();
    _stopUsageHeartbeat();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}
