import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/auth/auth_gate_controller.dart';
import 'package:matchu_app/controllers/system/notification_controller.dart';

typedef ConnectivityChecker = Future<List<ConnectivityResult>> Function();
typedef InternetReachabilityProbe = Future<bool> Function();

/// Keeps a single, app-wide view of whether MatchU can actually reach the
/// internet. Connectivity alone is not enough: a device may be connected to a
/// Wi-Fi access point which has no internet access.
class NetworkController extends GetxController with WidgetsBindingObserver {
  NetworkController({
    Connectivity? connectivity,
    ConnectivityChecker? connectivityChecker,
    InternetReachabilityProbe? internetProbe,
  }) : _connectivity = connectivity ?? Connectivity(),
       _connectivityChecker = connectivityChecker,
       _internetProbe = internetProbe;

  final Connectivity _connectivity;
  final ConnectivityChecker? _connectivityChecker;
  final InternetReachabilityProbe? _internetProbe;

  final isOffline = false.obs;
  final shouldShowOfflineOverlay = false.obs;
  final isChecking = false.obs;
  final isRetrying = false.obs;
  final lastRetryFailed = false.obs;
  final isReady = false.obs;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _healthCheckTimer;
  Future<bool>? _activeCheck;
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
  Future<bool> checkConnection() {
    final activeCheck = _activeCheck;
    if (activeCheck != null) return activeCheck;

    final check = _performConnectionCheck();
    _activeCheck = check;
    return check.whenComplete(() {
      if (identical(_activeCheck, check)) {
        _activeCheck = null;
      }
    });
  }

  Future<bool> _performConnectionCheck() async {
    isChecking.value = true;
    try {
      final transports = await _checkConnectivity();
      if (transports.isEmpty ||
          transports.every((result) => result == ConnectivityResult.none)) {
        _markOffline();
        return false;
      }

      final hasInternet = await _canReachInternetReliably();
      if (hasInternet) {
        _markOnline();
      } else {
        _markOffline();
      }
      return hasInternet;
    } catch (_) {
      // A platform-channel/connectivity query can fail briefly while Android or
      // iOS is switching transports. That is not proof that internet was lost,
      // so preserve the last confirmed state and retry on the next event/tick.
      return !isOffline.value;
    } finally {
      isChecking.value = false;
      isReady.value = true;
    }
  }

  /// Restores the application services after the connection comes back. A
  /// successful HTTP probe alone is not enough during an explicit retry:
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

  Future<List<ConnectivityResult>> _checkConnectivity() {
    return _connectivityChecker?.call() ?? _connectivity.checkConnectivity();
  }

  Future<bool> _canReachInternetReliably() async {
    final probe = _internetProbe ?? _canReachInternet;
    if (await probe()) return true;

    // Do not block the whole app because of one short DNS/TLS/CDN hiccup.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return probe();
  }

  void _markOffline() {
    isOffline.value = true;
    shouldShowOfflineOverlay.value = true;
  }

  void _markOnline() {
    final wasOffline = isOffline.value || shouldShowOfflineOverlay.value;
    isOffline.value = false;
    lastRetryFailed.value = false;

    // A confirmed background recovery must also release an overlay raised by
    // an earlier failed check. Manual retry keeps its loading UI until the
    // existing Firebase/Auth recovery flow finishes.
    if (wasOffline && !isRetrying.value) {
      shouldShowOfflineOverlay.value = false;
      unawaited(_restoreApplicationServices());
    }
  }

  Future<bool> _canReachInternet() async {
    const probeUrls = <String>[
      'https://www.gstatic.com/generate_204',
      'https://cp.cloudflare.com/generate_204',
    ];

    for (final url in probeUrls) {
      if (await _canReach(Uri.parse(url))) return true;
    }
    return false;
  }

  Future<bool> _canReach(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 4));
      final response = await request.close().timeout(
        const Duration(seconds: 4),
      );
      await response.drain<void>();
      return response.statusCode >= HttpStatus.ok &&
          response.statusCode < HttpStatus.badRequest;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } on HttpException {
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
