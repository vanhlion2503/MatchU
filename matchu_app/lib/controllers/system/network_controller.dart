import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

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

  /// Shows the explicit reconnect state requested by the offline dialog.
  /// A short minimum duration prevents the loading dialog from flashing.
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

    if (connected) {
      lastRetryFailed.value = false;
      shouldShowOfflineOverlay.value = false;
    } else {
      lastRetryFailed.value = true;
    }
    isRetrying.value = false;
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
