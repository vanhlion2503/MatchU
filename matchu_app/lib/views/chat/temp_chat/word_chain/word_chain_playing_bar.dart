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
  Worker? _invalidReasonWorker;
  Worker? _pendingWordWorker;
  Timer? _feedbackTimer;
  Timer? _invalidTimer;
  Timer? _successTimer;
  Timer? _rewardTimer;
  Timer? _pendingSubmitTimer;
  bool _showHeartLoss = false;
  bool _showInvalidFeedback = false;
  bool _showSuccessFeedback = false;
  bool _showMicroReward = false;
  String _invalidFeedbackText = '';
  int _rewardTick = 0;
  int _errorTick = 0;
  int _successTick = 0;
  int? _lastHearts;
  bool _awaitingSubmitAck = false;
  String? _pendingWord;
  DateTime? _lastAutoAcceptAt;
  String? _lastAutoAcceptReason;
  String? _lastErrorMessage;
  DateTime? _lastErrorAt;

  static const Duration _feedbackDuration = Duration(milliseconds: 1200);
  static const Duration _successDuration = Duration(milliseconds: 900);
  static const int _feedbackMinRepeatMs = 1000;
  static const String _formatMessage =
      'Từ phải gồm đúng 2 tiếng nha 😄\nVí dụ: mưa rào, bình yên';
  static const String _usedMessage =
      'Từ này đã được dùng rồi, thử từ khác nhé!';
  static const String _dictionaryMessage =
      'Từ này hơi lạ 🤔\nHãy chọn từ quen thuộc hơn';

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

    _invalidReasonWorker =
        ever<String?>(wordChain.invalidReason, (reason) {
      if (!mounted || reason == null || reason.isEmpty) return;
      if (!_awaitingSubmitAck) return;
      _clearPendingSubmit();
      final message = _messageForInvalidReason(
        reason,
        wordChain.currentWord.value,
      );
      if (message != null) {
        _showErrorFeedback(message);
      }
    });

    _pendingWordWorker =
        ever<Map<String, dynamic>?>(wordChain.pendingWord, (pending) {
      if (!mounted || pending != null) return;
      if (!_awaitingSubmitAck) return;
      final reason = wordChain.invalidReason.value;
      if (reason == null || reason.isEmpty) return;
      _clearPendingSubmit();
      final message = _messageForInvalidReason(
        reason,
        wordChain.currentWord.value,
      );
      if (message != null) {
        _showErrorFeedback(message);
      }
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
    _successTimer?.cancel();
    _rewardTimer?.cancel();
    _pendingSubmitTimer?.cancel();
    _heartWorker?.dispose();
    _statusWorker?.dispose();
    _turnWorker?.dispose();
    _wordWorker?.dispose();
    _autoAcceptWorker?.dispose();
    _invalidReasonWorker?.dispose();
    _pendingWordWorker?.dispose();
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

  void _showErrorFeedback(String message) {
    final now = DateTime.now();
    if (_lastErrorMessage == message &&
        _lastErrorAt != null &&
        now.difference(_lastErrorAt!).inMilliseconds < _feedbackMinRepeatMs) {
      return;
    }
    _lastErrorMessage = message;
    _lastErrorAt = now;

    HapticFeedback.mediumImpact();
    _invalidTimer?.cancel();
    setState(() {
      _invalidFeedbackText = message;
      _showInvalidFeedback = true;
      _showSuccessFeedback = false;
      _errorTick += 1;
    });
    _invalidTimer = Timer(_feedbackDuration, () {
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

  void _triggerSuccessFeedback() {
    _successTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _showSuccessFeedback = true;
      _showInvalidFeedback = false;
      _successTick += 1;
    });
    _successTimer = Timer(_successDuration, () {
      if (!mounted) return;
      setState(() {
        _showSuccessFeedback = false;
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
      _triggerSuccessFeedback();
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

  String? _messageForInvalidReason(String reason, String prevWord) {
    switch (reason) {
      case 'format':
        return _formatMessage;
      case 'chain_mismatch':
        final last = _lastWordPrefix(prevWord);
        if (last.isEmpty) {
          return 'Từ mới cần nối tiếp theo từ trước nhé!';
        }
        return "Từ mới phải bắt đầu bằng '$last'";
      case 'used_word':
        return _usedMessage;
      case 'dictionary':
        return _dictionaryMessage;
      case 'not_your_turn':
        return 'Chờ chút, chưa đến lượt bạn.';
      case 'not_playing':
        return 'Ván đang tạm dừng, thử lại sau nhé!';
      default:
        return 'Chưa nhận được từ này, thử lại nhé!';
    }
  }

  Future<void> _submitWord(WordChainController wordChain) async {
    final prefix = _lastWordPrefix(wordChain.currentWord.value);
    final rawInput = _inputController.text.trim();
    if (rawInput.isEmpty) return;

    final suffixWords = rawInput.split(RegExp(r'\s+'));
    if (prefix.isNotEmpty && suffixWords.length != 1) {
      _showErrorFeedback(_formatMessage);
      return;
    }

    final fullWord = prefix.isEmpty ? rawInput : '$prefix ${suffixWords.first}';
    final cleanWord = fullWord.trim();
    final parts = cleanWord.split(RegExp(r'\s+'));
    if (parts.length != 2) {
      _showErrorFeedback(_formatMessage);
      return;
    }

    if (wordChain.usedWords.contains(cleanWord)) {
      _showErrorFeedback(_usedMessage);
      return;
    }

    final valid = wordChain.service.validateWord(
      input: cleanWord,
      prevWord: wordChain.currentWord.value,
      usedWords: wordChain.usedWords,
    );

    if (!valid) {
      final expected = prefix.isNotEmpty
          ? prefix
          : _lastWordPrefix(wordChain.currentWord.value);
      _showErrorFeedback(
        expected.isEmpty
            ? 'Từ mới cần nối tiếp theo từ trước nhé!'
            : "Từ mới phải bắt đầu bằng '$expected'",
      );
      return;
    }

    _setPendingSubmit(cleanWord);
    try {
      await wordChain.submitWord(cleanWord);
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
          inputFeedbackMessage:
              _showInvalidFeedback ? _invalidFeedbackText : null,
          showInputError: _showInvalidFeedback,
          showInputSuccess: _showSuccessFeedback,
          inputErrorTick: _errorTick,
          inputSuccessTick: _successTick,
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
