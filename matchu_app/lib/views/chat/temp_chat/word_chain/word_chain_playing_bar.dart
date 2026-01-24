import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/temp_chat_controller.dart';
import 'package:matchu_app/controllers/game/wordChain/word_chain_controller.dart';
import 'package:matchu_app/models/word_chain.dart';
import 'package:matchu_app/views/chat/temp_chat/word_chain/word_chain_countdown_view.dart';
import 'package:matchu_app/views/chat/temp_chat/word_chain/word_chain_feedback_overlay.dart';
import 'package:matchu_app/views/chat/temp_chat/word_chain/word_chain_gameplay_view.dart';
import 'package:matchu_app/views/chat/temp_chat/word_chain/word_chain_winner_view.dart';

class WordChainPlayingBar extends StatefulWidget {
  final TempChatController controller;

  const WordChainPlayingBar({
    super.key,
    required this.controller,
  });

  @override
  State<WordChainPlayingBar> createState() => _WordChainPlayingBarState();
}

class _WordChainPlayingBarState extends State<WordChainPlayingBar> {
  final TextEditingController _inputController = TextEditingController();
  Worker? _heartWorker;
  Worker? _statusWorker;
  Worker? _turnWorker;
  Worker? _wordWorker;
  Worker? _autoAcceptWorker;
  Timer? _feedbackTimer;
  Timer? _invalidTimer;
  Timer? _rewardTimer;
  Timer? _pendingSubmitTimer;
  bool _showHeartLoss = false;
  bool _showInvalidFeedback = false;
  bool _showMicroReward = false;
  String _invalidFeedbackText = '';
  int _rewardTick = 0;
  int? _lastHearts;
  bool _awaitingSubmitAck = false;
  String? _pendingWord;
  DateTime? _lastAutoAcceptAt;
  String? _lastAutoAcceptReason;

  @override
  void initState() {
    super.initState();

    final wordChain = widget.controller.wordChain;
    _heartWorker = ever<Map<String, int>>(wordChain.hearts, (hearts) {
      final current = hearts[wordChain.uid] ?? 0;
      if (_lastHearts != null && current < _lastHearts!) {
        _triggerHeartLoss();
      }
      _lastHearts = current;
    });

    _statusWorker = ever<WordChainStatus>(wordChain.status, (status) {
      if (!mounted) return;
      if (status != WordChainStatus.playing) {
        _clearInvalidFeedback();
        _clearPendingSubmit();
      }
    });

    _autoAcceptWorker =
        ever<DateTime?>(wordChain.rewardCompletedAt, (completedAt) {
      if (!mounted || completedAt == null) return;
      final reason = wordChain.rewardAutoAcceptedReason.value;
      if (reason == null) return;
      if (_lastAutoAcceptAt == completedAt &&
          _lastAutoAcceptReason == reason) {
        return;
      }
      _lastAutoAcceptAt = completedAt;
      _lastAutoAcceptReason = reason;
      _showAutoAcceptNotice(reason);
    });

    _turnWorker = ever<String>(wordChain.turnUid, (_) {
      if (!mounted) return;
      _inputController.clear();
      _clearInvalidFeedback();
      _resolvePendingSubmit(wordChain);
    });

    _wordWorker = ever<String>(wordChain.currentWord, (_) {
      if (!mounted) return;
      _inputController.clear();
      _clearInvalidFeedback();
      _resolvePendingSubmit(wordChain);
    });
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _invalidTimer?.cancel();
    _rewardTimer?.cancel();
    _pendingSubmitTimer?.cancel();
    _heartWorker?.dispose();
    _statusWorker?.dispose();
    _turnWorker?.dispose();
    _wordWorker?.dispose();
    _autoAcceptWorker?.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _triggerHeartLoss() {
    _feedbackTimer?.cancel();
    setState(() {
      _showHeartLoss = true;
    });
    _feedbackTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _showHeartLoss = false;
      });
    });
  }

  void _triggerInvalidFeedback(String message) {
    _invalidTimer?.cancel();
    setState(() {
      _invalidFeedbackText = message;
      _showInvalidFeedback = true;
    });
    _invalidTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _showInvalidFeedback = false;
      });
    });
  }

  void _clearInvalidFeedback() {
    _invalidTimer?.cancel();
    if (!_showInvalidFeedback) return;
    setState(() {
      _showInvalidFeedback = false;
    });
  }

  void _triggerMicroReward() {
    _rewardTimer?.cancel();
    setState(() {
      _showMicroReward = true;
      _rewardTick += 1;
    });
    _rewardTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _showMicroReward = false;
      });
    });
  }

  void _setPendingSubmit(String word) {
    _pendingSubmitTimer?.cancel();
    _pendingWord = word;
    _awaitingSubmitAck = true;
    _pendingSubmitTimer = Timer(const Duration(seconds: 4), () {
      _clearPendingSubmit();
    });
  }

  void _clearPendingSubmit() {
    _pendingSubmitTimer?.cancel();
    _pendingWord = null;
    _awaitingSubmitAck = false;
  }

  void _resolvePendingSubmit(WordChainController wordChain) {
    if (!_awaitingSubmitAck || _pendingWord == null) return;
    final currentWord = wordChain.currentWord.value.trim();
    final isOtherTurn = wordChain.turnUid.value != wordChain.uid;

    if (isOtherTurn && currentWord == _pendingWord) {
      _clearPendingSubmit();
      _triggerMicroReward();
      return;
    }

    if (isOtherTurn && currentWord != _pendingWord) {
      _clearPendingSubmit();
    }
  }

  String _lastWordPrefix(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final parts = trimmed.split(RegExp(r'\s+'));
    return parts.isEmpty ? '' : parts.last;
  }

  void _showAutoAcceptNotice(String reason) {
    if (!mounted) return;
    String? message;
    switch (reason) {
      case 'timeout':
        message =
            'Hệ thống đã tự động tiếp tục để đảm bảo trải nghiệm cho cả hai.';
        break;
      case 'max_declines':
        message =
            'Hệ thống đã tự động chấp nhận để đảm bảo công bằng cho cả hai.';
        break;
      case 'ask_timeout':
      case 'answer_timeout':
      case 'winner_left':
        return;
      default:
        return;
    }

    Get.snackbar(
      "Thông báo",
      message,
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _submitWord(WordChainController wordChain) async {
    final prefix = _lastWordPrefix(wordChain.currentWord.value);
    final rawInput = _inputController.text.trim();
    if (rawInput.isEmpty) return;

    final suffixWords = rawInput.split(RegExp(r'\s+'));
    if (prefix.isNotEmpty && suffixWords.length != 1) {
      _triggerInvalidFeedback('Chỉ cần nhập 1 từ sau "$prefix".');
      HapticFeedback.mediumImpact();
      return;
    }

    final fullWord = prefix.isEmpty ? rawInput : '$prefix ${suffixWords.first}';
    final cleanWord = fullWord.trim();
    final parts = cleanWord.split(RegExp(r'\s+'));
    if (parts.length != 2) {
      _triggerInvalidFeedback('Chỉ được 2 từ.');
      HapticFeedback.mediumImpact();
      return;
    }

    if (wordChain.usedWords.contains(cleanWord)) {
      _triggerInvalidFeedback('Từ này đã được dùng.');
      HapticFeedback.mediumImpact();
      return;
    }

    final valid = wordChain.service.validateWord(
      input: cleanWord,
      prevWord: wordChain.currentWord.value,
      usedWords: wordChain.usedWords,
    );

    if (!valid) {
      _triggerInvalidFeedback('Từ không hợp lệ.');
      HapticFeedback.mediumImpact();
      return;
    }

    _setPendingSubmit(cleanWord);
    try {
      await wordChain.submitWord(cleanWord);
      _inputController.clear();
      HapticFeedback.lightImpact();
    } catch (_) {
      _clearPendingSubmit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final wordChain = widget.controller.wordChain;

    return Obx(() {
      final status = wordChain.status.value;
      if (status != WordChainStatus.countdown &&
          status != WordChainStatus.playing &&
          status != WordChainStatus.reward) {
        return const SizedBox.shrink();
      }

      return Positioned.fill(
        child: Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Stack(
            children: [
              SafeArea(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  child: _buildStage(context, wordChain, status),
                ),
              ),
              if (_showHeartLoss) const WordChainHeartLossOverlay(),
              if (_showInvalidFeedback)
                WordChainInvalidToast(message: _invalidFeedbackText),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildStage(
    BuildContext context,
    WordChainController wordChain,
    WordChainStatus status,
  ) {
    switch (status) {
      case WordChainStatus.countdown:
        return WordChainCountdownView(
          seconds: wordChain.countdownSeconds.value,
        );
      case WordChainStatus.playing:
        return WordChainGameplayView(
          wordChain: wordChain,
          inputController: _inputController,
          onSubmit: () => _submitWord(wordChain),
          onSOS: wordChain.useSOS,
          otherAvatarKey: widget.controller.otherAnonymousAvatar.value,
          showReward: _showMicroReward,
          rewardTick: _rewardTick,
        );
      case WordChainStatus.reward:
        return WordChainRewardView(
          wordChain: wordChain,
          isWinner: wordChain.winnerUid.value == wordChain.uid,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
