import 'dart:async';

import 'package:get/get.dart';

class TelepathyTimers {
  static const int questionDurationSeconds = 15;
  static const int countdownDurationSeconds = 3;
  static const int questionLeadMs = 500;
  static const int countdownLeadMs = 0;

  TelepathyTimers({
    required this.remainingSeconds,
    required this.countdownSeconds,
    required this.onQuestionTimeout,
    required this.onCountdownComplete,
  });

  final RxInt remainingSeconds;
  final RxInt countdownSeconds;
  final Future<void> Function() onQuestionTimeout;
  final Future<void> Function() onCountdownComplete;

  Timer? _questionTimer;
  Timer? _countdownTimer;
  DateTime? _questionStartedAt;
  DateTime? _countdownStartedAt;
  int _serverOffsetMs = 0;

  void syncQuestion(DateTime? startedAt) {
    if (startedAt != null) {
      _questionStartedAt = startedAt;
      _updateServerOffset(startedAt);
      _updateQuestionRemaining();
    } else {
      _questionStartedAt = null;
      remainingSeconds.value = questionDurationSeconds;
    }
  }

  void syncCountdown(DateTime? startedAt) {
    if (startedAt != null) {
      _countdownStartedAt = startedAt;
      _updateServerOffset(startedAt);
      _updateCountdownRemaining();
    } else {
      _countdownStartedAt = null;
      countdownSeconds.value = countdownDurationSeconds;
    }
  }

  void startLocalCountdown(DateTime startedAt) {
    _countdownStartedAt = startedAt;
    _updateServerOffset(startedAt);
    _updateCountdownRemaining();
    ensureCountdownTimer();
  }

  void ensureQuestionTimer() {
    if (_questionTimer != null) return;

    _questionTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      _updateQuestionRemaining();
      if (remainingSeconds.value <= 0) {
        await onQuestionTimeout();
      }
    });
  }

  void ensureCountdownTimer() {
    if (_countdownTimer != null) return;

    _countdownTimer =
        Timer.periodic(const Duration(milliseconds: 200), (_) async {
      _updateCountdownRemaining();

      if (countdownSeconds.value <= 0) {
        stopCountdownTimer();
        await onCountdownComplete();
      }
    });
  }

  void stopQuestionTimer() {
    _questionTimer?.cancel();
    _questionTimer = null;
  }

  void stopCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  void stopAll() {
    stopQuestionTimer();
    stopCountdownTimer();
  }

  void reset() {
    stopAll();
    _questionStartedAt = null;
    _countdownStartedAt = null;
    _serverOffsetMs = 0;
    remainingSeconds.value = questionDurationSeconds;
    countdownSeconds.value = countdownDurationSeconds;
  }

  void dispose() {
    stopAll();
  }

  void _updateQuestionRemaining() {
    if (_questionStartedAt == null) {
      remainingSeconds.value = questionDurationSeconds;
      return;
    }

    final effectiveStart = _questionStartedAt!
        .add(const Duration(milliseconds: questionLeadMs));
    final elapsedMs = _serverNow().difference(effectiveStart).inMilliseconds;
    final remainingMs = (questionDurationSeconds * 1000) - elapsedMs;
    final remaining = (remainingMs / 1000).ceil();
    remainingSeconds.value = remaining.clamp(0, questionDurationSeconds);
  }

  void _updateCountdownRemaining() {
    if (_countdownStartedAt == null) {
      countdownSeconds.value = countdownDurationSeconds;
      return;
    }

    final effectiveStart = _countdownStartedAt!
        .add(const Duration(milliseconds: countdownLeadMs));
    final elapsedMs = _serverNow().difference(effectiveStart).inMilliseconds;
    final remainingMs = (countdownDurationSeconds * 1000) - elapsedMs;
    final remaining = (remainingMs / 1000).ceil();
    countdownSeconds.value = remaining.clamp(0, countdownDurationSeconds);
  }

  DateTime _serverNow() {
    return DateTime.now().add(Duration(milliseconds: _serverOffsetMs));
  }

  void _updateServerOffset(DateTime serverTime) {
    final localNow = DateTime.now().millisecondsSinceEpoch;
    _serverOffsetMs = serverTime.millisecondsSinceEpoch - localNow;
  }
}
