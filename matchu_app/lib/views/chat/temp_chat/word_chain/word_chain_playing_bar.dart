import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/controllers/chat/temp_chat_controller.dart';
import 'package:matchu_app/controllers/game/wordChain/word_chain_controller.dart';
import 'package:matchu_app/models/word_chain.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/chat/temp_chat/anonymous_avatar.dart';

class WordChainPlayingBar extends StatefulWidget {
  final TempChatController controller;

  const WordChainPlayingBar({
    super.key,
    required this.controller,
  });

  @override
  State<WordChainPlayingBar> createState() => _WordChainPlayingBarState();
}

class _WordChainPlayingBarState extends State<WordChainPlayingBar>
    with TickerProviderStateMixin {
  static const _accentPink = Color(0xFFEC4899);
  static const _accentOrange = Color(0xFFF97316);
  static const _softBg = Color(0xFFF7F7FB);
  static const _timerBg = Color(0xFFFFF1F2);
  static const _mutedText = Color(0xFF9CA3AF);

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
      return 'B\u1ea1n';
    }
    return name;
  }

  Future<void> _handleWinnerCard(
    WordChainController wordChain,
    _WinnerCard card,
  ) async {
    if (_sendingReward || _winnerSelectionDone) return;
    setState(() {
      _sendingReward = true;
    });
    HapticFeedback.lightImpact();

    try {
      final winnerName = _winnerDisplayName();
      final text =
          'Ch\u00fac m\u1eebng $winnerName \u0111\u00e3 chi\u1ebfn th\u1eafng! \uD83C\uDFC6\n'
          '${card.title}: ${card.prompt}';

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
      _triggerInvalidFeedback('Kh\u00f4ng \u0111\u00fang');
      HapticFeedback.mediumImpact();
      return;
    }

    final fullWord = prefix.isEmpty ? suffix : '$prefix $suffix';
    final parts = fullWord.split(RegExp(r'\s+'));
    if (parts.length != 2) {
      _triggerInvalidFeedback('Kh\u00f4ng \u0111\u00fang');
      HapticFeedback.mediumImpact();
      return;
    }

    if (wordChain.usedWords.contains(fullWord)) {
      _triggerInvalidFeedback('T\u1eeb kh\u00f4ng h\u1ee3p l\u1ec7');
      HapticFeedback.mediumImpact();
      return;
    }

    final valid = wordChain.service.validateWord(
      input: fullWord,
      prevWord: wordChain.currentWord.value,
      usedWords: wordChain.usedWords,
    );

    if (!valid) {
      _triggerInvalidFeedback('T\u1eeb kh\u00f4ng h\u1ee3p l\u1ec7');
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
              if (_showHeartLoss) _buildHeartLossOverlay(context),
              if (_showInvalidFeedback) _buildInvalidToast(context),
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
        return _buildCountdown(context, wordChain);
      case WordChainStatus.playing:
        return _buildGameplay(context, wordChain);
      case WordChainStatus.finished:
        return _buildWinner(context, wordChain);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCountdown(
    BuildContext context,
    WordChainController wordChain,
  ) {
    final theme = Theme.of(context);
    final seconds = wordChain.countdownSeconds.value;

    return Center(
      child: Column(
        key: const ValueKey('word_chain_countdown'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'N\u1ed1i t\u1eeb',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) {
              return ScaleTransition(
                scale: Tween(begin: 0.7, end: 1.0).animate(anim),
                child: FadeTransition(opacity: anim, child: child),
              );
            },
            child: Text(
              seconds.toString(),
              key: ValueKey(seconds),
              style: theme.textTheme.displayLarge?.copyWith(
                color: _accentPink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'S\u1eb5n s\u00e0ng b\u1eaft \u0111\u1ea7u',
            style: theme.textTheme.bodySmall?.copyWith(
              color: _mutedText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameplay(
    BuildContext context,
    WordChainController wordChain,
  ) {
    final theme = Theme.of(context);
    final isMyTurn = wordChain.turnUid.value == wordChain.uid;
    final body = isMyTurn
        ? _buildMyTurn(context, wordChain)
        : _buildOpponentTurn(context, wordChain);

    return Column(
      key: ValueKey("word_chain_playing_${isMyTurn ? "me" : "other"}"),
      children: [
        _buildHeader(context, wordChain, isMyTurn),
        Expanded(child: body),
        if (isMyTurn) _buildActionBar(theme, wordChain),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WordChainController wordChain,
    bool isMyTurn,
  ) {
    final theme = Theme.of(context);
    final hearts = wordChain.hearts[wordChain.uid] ?? 0;
    final displaySeconds =
        wordChain.remainingSeconds.value < 0 ? 0 : wordChain.remainingSeconds.value;
    const totalHearts = 3;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Row(
            children: List.generate(totalHearts, (i) {
              final filled = i < hearts;
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  filled ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                  color: filled
                      ? _accentPink
                      : theme.colorScheme.onSurface.withOpacity(0.25),
                ),
              );
            }),
          ),
          const Spacer(),
          if (isMyTurn)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _timerBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 14,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${displaySeconds}s',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMyTurn(
    BuildContext context,
    WordChainController wordChain,
  ) {
    final theme = Theme.of(context);
    final current = wordChain.currentWord.value;
    final lastWord = _lastWordPrefix(current);
    final isSeed = wordChain.usedWords.length <= 1;
    final sourceLabel = isSeed
        ? 'T\u1eeb h\u1ec7 th\u1ed1ng'
        : 'T\u1eeb \u0111\u1ed1i ph\u01b0\u01a1ng';
    final helper = lastWord.isEmpty
        ? 'Nh\u1eadp 2 t\u1eeb b\u1ea5t k\u1ef3'
        : 'Nh\u1eadp t\u1eeb b\u1eaft \u0111\u1ea7u b\u1eb1ng "$lastWord"';
    final prefixText = lastWord.isEmpty ? null : '$lastWord ';
    final inputFormatters = lastWord.isEmpty
        ? null
        : [FilteringTextInputFormatter.deny(RegExp(r'\s'))];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        children: [
          Text(
            'T\u1eeb kh\u00f3a hi\u1ec7n t\u1ea1i',
            style: theme.textTheme.bodySmall?.copyWith(
              letterSpacing: 1.4,
              color: _mutedText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Stack(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? theme.colorScheme.surface
                      : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: theme.brightness == Brightness.dark
                        ? AppTheme.darkBorder
                        : AppTheme.lightBorder,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      current.isEmpty ? '...' : current,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      sourceLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                top: 14,
                bottom: 14,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: _accentOrange,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? theme.colorScheme.surface
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _accentPink.withOpacity(0.35),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _accentPink.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _inputController,
                  minLines: 1,
                  maxLines: 1,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submitWord(wordChain),
                  inputFormatters: inputFormatters,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: lastWord.isEmpty ? '...' : '...',
                    prefixText: prefixText,
                    prefixStyle: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Positioned(
                left: 12,
                top: -10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark
                        ? theme.colorScheme.surface
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '\u0110\u1ebfn l\u01b0\u1ee3t b\u1ea1n',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _accentPink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              helper,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _mutedText,
              ),
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: wordChain.useSOS,
            icon: Icon(
              Icons.help_outline,
              size: 18,
              color: _mutedText,
            ),
            label: Text(
              'SOS \u2022 C\u1ea7u c\u1ee9u',
              style: theme.textTheme.labelMedium?.copyWith(
                color: _mutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: theme.brightness == Brightness.dark
                    ? AppTheme.darkBorder
                    : AppTheme.lightBorder,
                style: BorderStyle.solid,
              ),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpponentTurn(
    BuildContext context,
    WordChainController wordChain,
  ) {
    final theme = Theme.of(context);
    final current = wordChain.currentWord.value;
    final lastWord = current.isEmpty ? '...' : current;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  color: _accentOrange.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
              ),
              AnonymousAvatar(
                avatarKey: widget.controller.otherAnonymousAvatar.value,
                radius: 40,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? theme.colorScheme.surface
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: theme.brightness == Brightness.dark
                    ? AppTheme.darkBorder
                    : AppTheme.lightBorder,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _ThinkingDots(),
                const SizedBox(width: 6),
                Text(
                  '\u0110ang suy ngh\u0129...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'T\u1eeb kh\u00f3a tr\u01b0\u1edbc: $lastWord',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _mutedText,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 48,
            width: 200,
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? theme.colorScheme.surfaceVariant
                  : _softBg,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(
    ThemeData theme,
    WordChainController wordChain,
  ) {
    final buttonColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.onSurface
        : const Color(0xFF111827);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? theme.colorScheme.surface
            : _softBg,
        border: Border(
          top: BorderSide(
            color: theme.brightness == Brightness.dark
                ? AppTheme.darkBorder
                : AppTheme.lightBorder,
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _submitWord(wordChain),
          icon: const Icon(Icons.send, size: 18),
          label: const Text('G\u1eedi c\u00e2u tr\u1ea3 l\u1eddi'),
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWinner(
    BuildContext context,
    WordChainController wordChain,
  ) {
    final theme = Theme.of(context);
    final isWinner = wordChain.winnerUid.value == wordChain.uid;
    final cards = _winnerCards();
    final headline =
        isWinner ? 'Ch\u00fac m\u1eebng! \uD83C\uDF89' : 'K\u1ebft th\u00fac';
    final description = isWinner
        ? 'B\u1ea1n \u0111\u00e3 th\u1eafng! H\u00e3y ch\u1ecdn 1 \u0111i\u1ec1u '
            'b\u1ea1n mu\u1ed1n bi\u1ebft v\u1ec1 \u0111\u1ed1i ph\u01b0\u01a1ng:'
        : '\u0110ang ch\u1edd \u0111\u1ed1i ph\u01b0\u01a1ng ch\u1ecdn th\u1ebb.';

    return SingleChildScrollView(
      key: const ValueKey('word_chain_winner'),
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: _accentPink.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
              ),
              Icon(
                Icons.emoji_events,
                size: 52,
                color: Colors.amber.shade400,
              ),
              Positioned(
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isWinner ? 'WINNER' : 'MATCH',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            headline,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: _mutedText,
            ),
          ),
          const SizedBox(height: 24),
          Column(
            children: cards.map((card) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _WinnerCardTile(
                  card: card,
                  enabled: isWinner && !_sendingReward,
                  onTap: () => _handleWinnerCard(wordChain, card),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeartLossOverlay(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned.fill(
      child: Container(
        color: theme.scaffoldBackgroundColor.withOpacity(0.96),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close,
                  size: 36,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'H\u1ebft gi\u1edd',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'B\u1ea1n m\u1ea5t 1 tim',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _mutedText,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'M\u1ea5t 1 tim \uD83D\uDC94',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvalidToast(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned(
      left: 24,
      right: 24,
      bottom: 110,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.error.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.error.withOpacity(0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 18,
              color: theme.colorScheme.error,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _invalidFeedbackText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_WinnerCard> _winnerCards() {
    return const [
      _WinnerCard(
        title: 'Th\u1ebb K\u1ef7 Ni\u1ec7m',
        subtitle:
            'K\u1ec3 v\u1ec1 m\u1ed9t tr\u1ea3i nghi\u1ec7m x\u1ea5u h\u1ed5 nh\u1ea5t th\u1eddi \u0111i h\u1ecdc?',
        prompt:
            'K\u1ec3 v\u1ec1 m\u1ed9t tr\u1ea3i nghi\u1ec7m x\u1ea5u h\u1ed5 nh\u1ea5t th\u1eddi \u0111i h\u1ecdc?',
        icon: Icons.auto_awesome,
        color: Color(0xFFD8B4FE),
      ),
      _WinnerCard(
        title: 'Th\u1ebb Quan \u0110i\u1ec3m',
        subtitle:
            'T\u1eadt x\u1ea5u n\u00e0o c\u1ee7a ng\u01b0\u1eddi kh\u00e1c m\u00e0 b\u1ea1n kh\u00f4ng th\u1ec3 ch\u1ecbu \u0111\u1ef1ng n\u1ed5i?',
        prompt:
            'T\u1eadt x\u1ea5u n\u00e0o c\u1ee7a ng\u01b0\u1eddi kh\u00e1c m\u00e0 b\u1ea1n kh\u00f4ng th\u1ec3 ch\u1ecbu \u0111\u1ef1ng n\u1ed5i?',
        icon: Icons.chat_bubble_outline,
        color: Color(0xFFFDBA74),
      ),
      _WinnerCard(
        title: 'Th\u1ebb S\u1edf Th\u00edch',
        subtitle:
            'N\u1ebfu c\u00f3 1 t\u1ef7, \u0111i\u1ec1u \u0111\u1ea7u ti\u00ean b\u1ea1n mua l\u00e0 g\u00ec?',
        prompt:
            'N\u1ebfu c\u00f3 1 t\u1ef7, \u0111i\u1ec1u \u0111\u1ea7u ti\u00ean b\u1ea1n mua l\u00e0 g\u00ec?',
        icon: Icons.sports_esports,
        color: Color(0xFF86EFAC),
      ),
    ];
  }
}

class _ThinkingDots extends StatefulWidget {
  const _ThinkingDots();

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            final t = (_controller.value + i * 0.2) % 1.0;
            final dy = math.sin(t * math.pi * 2) * 2;
            return Transform.translate(
              offset: Offset(0, -dy),
              child: Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

class _WinnerCard {
  final String title;
  final String subtitle;
  final String prompt;
  final IconData icon;
  final Color color;

  const _WinnerCard({
    required this.title,
    required this.subtitle,
    required this.prompt,
    required this.icon,
    required this.color,
  });
}

class _WinnerCardTile extends StatelessWidget {
  final _WinnerCard card;
  final bool enabled;
  final VoidCallback onTap;

  const _WinnerCardTile({
    required this.card,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? theme.colorScheme.surface
                : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.brightness == Brightness.dark
                  ? AppTheme.darkBorder
                  : AppTheme.lightBorder,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: card.color.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(card.icon, color: card.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      card.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

