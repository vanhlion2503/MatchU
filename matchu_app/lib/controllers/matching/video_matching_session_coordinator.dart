import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Keeps the lightweight UI state needed while video matching is minimized.
/// The actual queue and WebRTC lifecycle remain owned by VideoMatchingController.
class VideoMatchingSessionCoordinator extends GetxController {
  final isActive = false.obs;
  final isMinimized = false.obs;
  final elapsedSeconds = 0.obs;
  final bubbleOffset = const Offset(20, 140).obs;

  VoidCallback? _onRestore;

  void begin({required VoidCallback onRestore}) {
    _onRestore = onRestore;
    elapsedSeconds.value = 0;
    isMinimized.value = false;
    isActive.value = true;
  }

  void updateElapsed(int seconds) {
    if (isActive.value) elapsedSeconds.value = seconds;
  }

  bool minimize() {
    if (!isActive.value) return false;
    isMinimized.value = true;
    return true;
  }

  void restore() {
    if (!isActive.value) return;
    isMinimized.value = false;
    _onRestore?.call();
  }

  void markVisible() {
    isMinimized.value = false;
  }

  void finish() {
    isActive.value = false;
    isMinimized.value = false;
    elapsedSeconds.value = 0;
    _onRestore = null;
  }
}
