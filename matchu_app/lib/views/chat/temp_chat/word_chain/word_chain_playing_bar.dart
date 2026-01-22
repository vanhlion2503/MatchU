import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
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
  Timer? _feedbackTimer;
  Timer? _invalidTimer;
  bool _showHeartLoss = false;
  bool _showInvalidFeedback = false;
  bool _winnerSelectionDone = false;
  bool _sendingReward = false;
  String _invalidFeedbackText = '';
  int? _lastHearts;

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
      if (status != WordChainStatus.finished &&
          (_winnerSelectionDone || _sendingReward)) {
        setState(() {
          _winnerSelectionDone = false;
          _sendingReward = false;
        });
      }
      if (status != WordChainStatus.playing) {
        _clearInvalidFeedback();
      }
    });

    _turnWorker = ever<String>(wordChain.turnUid, (_) {
      if (!mounted) return;
      _inputController.clear();
      _clearInvalidFeedback();
    });

    _wordWorker = ever<String>(wordChain.currentWord, (_) {
      if (!mounted) return;
      _inputController.clear();
      _clearInvalidFeedback();
    });
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _invalidTimer?.cancel();
    _heartWorker?.dispose();
    _statusWorker?.dispose();
    _turnWorker?.dispose();
    _wordWorker?.dispose();
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

  String _lastWordPrefix(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final parts = trimmed.split(RegExp(r'\s+'));
    return parts.isEmpty ? '' : parts.last;
  }

  String _winnerDisplayName() {
    final auth = Get.find<AuthController>();
    final name = auth.user?.displayName?.trim();
    if (name == null || name.isEmpty) {
      return 'Bạn';
    }
    return name;
  }

  Future<void> _handleWinnerCard(
    WordChainController wordChain,
    WordChainWinnerCard card,
  ) async {
    if (_sendingReward || _winnerSelectionDone) return;
    setState(() {
      _sendingReward = true;
    });
    HapticFeedback.lightImpact();

    try {
      final winnerName = _winnerDisplayName();
      final text =
          'Chúc mừng $winnerName đã chiến thắng! 🏆\n${card.title}: ${card.prompt}';

      await widget.controller.service.sendSystemMessage(
        roomId: widget.controller.roomId,
        text: text,
        code: 'word_chain_reward',
        senderId: wordChain.uid,
      );

      if (!mounted) return;
      setState(() {
        _winnerSelectionDone = true;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _sendingReward = false;
      });
    }
  }

  Future<void> _submitWord(WordChainController wordChain) async {
    final prefix = _lastWordPrefix(wordChain.currentWord.value);
    final suffix = _inputController.text.trim();
    if (suffix.isEmpty) return;

    if (prefix.isNotEmpty && suffix.contains(RegExp(r'\s'))) {
      _triggerInvalidFeedback('Không đúng');
      HapticFeedback.mediumImpact();
      return;
    }

    final fullWord = prefix.isEmpty ? suffix : '$prefix $suffix';
    final parts = fullWord.split(RegExp(r'\s+'));
    if (parts.length != 2) {
      _triggerInvalidFeedback('Không đúng');
      HapticFeedback.mediumImpact();
      return;
    }

    if (wordChain.usedWords.contains(fullWord)) {
      _triggerInvalidFeedback('Từ không hợp lệ');
      HapticFeedback.mediumImpact();
      return;
    }

    final valid = wordChain.service.validateWord(
      input: fullWord,
      prevWord: wordChain.currentWord.value,
      usedWords: wordChain.usedWords,
    );

    if (!valid) {
      _triggerInvalidFeedback('Từ không hợp lệ');
      HapticFeedback.mediumImpact();
      return;
    }

    await wordChain.submitWord(fullWord);
    _inputController.clear();
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final wordChain = widget.controller.wordChain;

    return Obx(() {
      final status = wordChain.status.value;
      if (status != WordChainStatus.countdown &&
          status != WordChainStatus.playing &&
          status != WordChainStatus.finished) {
        return const SizedBox.shrink();
      }

      if (status == WordChainStatus.finished) {
        final isWinner = wordChain.winnerUid.value == wordChain.uid;
        if (!isWinner || _winnerSelectionDone) {
          return const SizedBox.shrink();
        }
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
        );
      case WordChainStatus.finished:
        return WordChainWinnerView(
          isWinner: wordChain.winnerUid.value == wordChain.uid,
          sendingReward: _sendingReward,
          onSelectCard: (card) => _handleWinnerCard(wordChain, card),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
