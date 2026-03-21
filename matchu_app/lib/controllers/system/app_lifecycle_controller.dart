import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:matchu_app/controllers/system/notification_controller.dart';
import 'package:matchu_app/models/reputation_daily_state.dart';
import 'package:matchu_app/services/reputation/reputation_service.dart';
import 'package:matchu_app/services/user/presence_service.dart';

class AppLifecycleController extends GetxController
    with WidgetsBindingObserver {
  StreamSubscription<User?>? _authSub;
  Timer? _usageHeartbeatTimer;
  bool _isLoggedIn = false;
  final ReputationService _reputationService = ReputationService();
  final GetStorage _storage = GetStorage();
  DateTime? _lastReputationTouchAt;
  String? _usageTouchSuspendedDateKey;
  static const String _usageTouchSuspendedDateKeyStorageKey =
      "reputation_usage_touch_suspended_date_key";

  @override
  void onInit() {
    super.onInit();
    _usageTouchSuspendedDateKey = _readSuspendedDateKeyFromStorage();
    WidgetsBinding.instance.addObserver(this);
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  void _onAuthChanged(User? user) {
    final wasLoggedIn = _isLoggedIn;
    _isLoggedIn = user != null;

    if (!_isLoggedIn) {
      _stopUsageHeartbeat();
      _setUsageTouchSuspendedDateKey(null);
      return;
    }

    PresenceService.setOnline();
    if (Get.isRegistered<NotificationController>()) {
      Get.find<NotificationController>().setForegroundState(true);
    }
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
      if (Get.isRegistered<NotificationController>()) {
        Get.find<NotificationController>().setForegroundState(true);
      }
      _touchDailyLoginTask(source: "resume", force: true);
      _startUsageHeartbeat();
      return;
    }

    if (Get.isRegistered<NotificationController>()) {
      Get.find<NotificationController>().setForegroundState(false);
    }
    _touchDailyLoginTask(source: _sourceForInactiveState(state), force: true);
    _stopUsageHeartbeat();
  }

  Future<void> _touchDailyLoginTask({
    String source = "app_open",
    bool force = false,
  }) async {
    if (!_isLoggedIn) return;
    if (_isUsageTouchSuspendedForToday()) return;

    final now = DateTime.now();
    final lastTouch = _lastReputationTouchAt;
    if (!force &&
        lastTouch != null &&
        now.difference(lastTouch) < const Duration(seconds: 20)) {
      return;
    }

    _lastReputationTouchAt = now;
    final state = await _reputationService.touchDailyLoginTaskSilently(
      source: source,
    );
    if (state != null) {
      _syncUsageTouchSuspension(state);
    }
  }

  bool _isUsageTouchSuspendedForToday() {
    final suspendedDateKey = _usageTouchSuspendedDateKey;
    if (suspendedDateKey == null) return false;
    return suspendedDateKey == _currentDateKeyHoChiMinh();
  }

  void _syncUsageTouchSuspension(ReputationDailyState state) {
    final usageTask = state.appUsage15MinutesTask;
    if (usageTask == null) {
      _setUsageTouchSuspendedDateKey(null);
      return;
    }

    final isDoneForToday =
        usageTask.claimed || usageTask.progress >= usageTask.target;
    if (isDoneForToday) {
      _setUsageTouchSuspendedDateKey(state.dateKey);
    } else if (_usageTouchSuspendedDateKey == state.dateKey) {
      _setUsageTouchSuspendedDateKey(null);
    }
  }

  String? _readSuspendedDateKeyFromStorage() {
    final rawValue = _storage.read(_usageTouchSuspendedDateKeyStorageKey);
    if (rawValue is! String) return null;
    final value = rawValue.trim();
    if (value.isEmpty) return null;
    return value;
  }

  void _setUsageTouchSuspendedDateKey(String? value) {
    _usageTouchSuspendedDateKey = value;
    if (value == null || value.trim().isEmpty) {
      _storage.remove(_usageTouchSuspendedDateKeyStorageKey);
      return;
    }
    _storage.write(_usageTouchSuspendedDateKeyStorageKey, value.trim());
  }

  String _currentDateKeyHoChiMinh() {
    final nowInHoChiMinh = DateTime.now().toUtc().add(const Duration(hours: 7));
    final year = nowInHoChiMinh.year.toString().padLeft(4, "0");
    final month = nowInHoChiMinh.month.toString().padLeft(2, "0");
    final day = nowInHoChiMinh.day.toString().padLeft(2, "0");
    return "$year-$month-$day";
  }

  @override
  void onClose() {
    _authSub?.cancel();
    _stopUsageHeartbeat();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}
