import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/auth/auth_gate_controller.dart';
import 'package:matchu_app/controllers/system/notification_controller.dart';

/// Keeps a single, app-wide view of whether MatchU can actually reach the
/// internet. Connectivity alone is not enough: a device may be connected to a
/// Wi-Fi access point which has no internet access.
class NetworkController extends GetxController with WidgetsBindingObserver {
  NetworkController({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  final isOffline = false.obs;
  // Once shown, this overlay is dismissed only by a successful manual retry.
  final shouldShowOfflineOverlay = false.obs;
  final isChecking = false.obs;
  final isRetrying = false.obs;
  final lastRetryFailed = false.obs;
  final isReady = false.obs;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _healthCheckTimer;
  bool _isForeground = true;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (_) => unawaited(checkConnection()),
    );
    unawaited(checkConnection());
    _startHealthChecks();
  }

  /// Called by the retry button and after a transport change.
  Future<bool> checkConnection() async {
    if (isChecking.value) return !isOffline.value;

    isChecking.value = true;
    try {
      final transports = await _connectivity.checkConnectivity();
      if (transports.contains(ConnectivityResult.none)) {
        isOffline.value = true;
        shouldShowOfflineOverlay.value = true;
        return false;
      }

      final hasInternet = await _canReachInternet();
      isOffline.value = !hasInternet;
      if (!hasInternet) shouldShowOfflineOverlay.value = true;
      return hasInternet;
    } catch (_) {
      // A failed probe is treated as offline. The next transport event, the
      // periodic probe, or a manual retry can immediately recover the app.
      isOffline.value = true;
      shouldShowOfflineOverlay.value = true;
      return false;
    } finally {
      isChecking.value = false;
      isReady.value = true;
    }
  }

  /// Restores the application services after the user explicitly confirms that
  /// their connection is back. A successful HTTP probe alone is not enough:
  /// Firestore may have been disabled during logout and startup work may have
  /// failed while the device was offline.
  ///
  /// The overlay is dismissed only after the essential Firebase/Auth recovery
  /// succeeds. Firestore listeners owned by feature controllers automatically
  /// reconnect once Firestore networking is enabled again.
  Future<void> retryConnection() async {
    if (isRetrying.value) return;

    isRetrying.value = true;
    lastRetryFailed.value = false;
    final startedAt = DateTime.now();
    final connected = await checkConnection();
    final elapsed = DateTime.now().difference(startedAt);
    const minimumLoadingTime = Duration(milliseconds: 650);
    if (elapsed < minimumLoadingTime) {
      await Future<void>.delayed(minimumLoadingTime - elapsed);
    }

    final recovered = connected && await _restoreApplicationServices();
    if (!recovered) {
      lastRetryFailed.value = true;
    } else {
      lastRetryFailed.value = false;
      shouldShowOfflineOverlay.value = false;
    }
    isRetrying.value = false;
  }

  Future<bool> _restoreApplicationServices() async {
    try {
      // This is idempotent. It also recovers the explicit disableNetwork call
      // used by the logout flow without recreating any controllers or streams.
      await FirebaseFirestore.instance.enableNetwork().timeout(
        const Duration(seconds: 10),
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Force an authenticated server request before proceeding. This avoids
        // hiding the dialog while an expired token or Firestore session is
        // still unusable.
        await user.getIdToken(true).timeout(const Duration(seconds: 10));
      }

      if (Get.isRegistered<AuthGateController>()) {
        await Get.find<AuthGateController>().recoverAfterNetworkRestored();
      }

      // Push registration and presence are non-critical for opening the app;
      // retry them here but never keep the user behind the offline overlay when
      // the core Auth/Firestore recovery has already succeeded.
      if (Get.isRegistered<NotificationController>()) {
        unawaited(
          Get.find<NotificationController>()
              .resumeAfterNetworkRecovery()
              .catchError((_) {}),
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _canReachInternet() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final request = await client
          .getUrl(Uri.parse('https://www.gstatic.com/generate_204'))
          .timeout(const Duration(seconds: 5));
      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );
      await response.drain<void>();
      return response.statusCode == HttpStatus.noContent;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  void _startHealthChecks() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_isForeground) unawaited(checkConnection());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (_isForeground) unawaited(checkConnection());
  }

  @override
  void onClose() {
    _connectivitySubscription?.cancel();
    _healthCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}
