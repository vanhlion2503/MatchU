import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/game/wordChain/word_chain_controller.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/chat/temp_chat/anonymous_avatar.dart';

class WordChainGameplayView extends StatelessWidget {
  final WordChainController wordChain;
  final TextEditingController inputController;
  final VoidCallback onSubmit;
  final VoidCallback onSOS;
  final String? otherAvatarKey;

  const WordChainGameplayView({
    super.key,
    required this.wordChain,
    required this.inputController,
    required this.onSubmit,
    required this.onSOS,
    required this.otherAvatarKey,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isMyTurn = wordChain.turnUid.value == wordChain.uid;

      return Column(
        key: ValueKey("word_chain_playing_${isMyTurn ? 'me' : 'other'}"),
        children: [
          _WordChainHeader(
            isMyTurn: isMyTurn,
            hearts: wordChain.hearts[wordChain.uid] ?? 0,
            remainingSeconds: wordChain.remainingSeconds.value,
          ),
          Expanded(
            child: isMyTurn
                ? _WordChainMyTurn(
                    currentWord: wordChain.currentWord.value,
                    isSeed: wordChain.usedWords.length <= 1,
                    inputController: inputController,
                    onSubmit: onSubmit,
                    onSOS: onSOS,
                  )
                : _WordChainOpponentTurn(
                    currentWord: wordChain.currentWord.value,
                    otherAvatarKey: otherAvatarKey,
                  ),
          ),
          if (isMyTurn)
            _WordChainActionBar(
              onSubmit: onSubmit,
            ),
        ],
      );
    });
  }
}

class _WordChainHeader extends StatelessWidget {
  final bool isMyTurn;
  final int hearts;
  final int remainingSeconds;

  const _WordChainHeader({
    required this.isMyTurn,
    required this.hearts,
    required this.remainingSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final muted = theme.colorScheme.onSurface.withOpacity(0.25);
    final displaySeconds = remainingSeconds < 0 ? 0 : remainingSeconds;
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
                  color: filled ? accent : muted,
                ),
              );
            }),
          ),
          const Spacer(),
          if (isMyTurn)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withOpacity(0.08),
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
}

class _WordChainMyTurn extends StatefulWidget {
  final String currentWord;
  final bool isSeed;
  final TextEditingController inputController;
  final VoidCallback onSubmit;
  final VoidCallback onSOS;

  const _WordChainMyTurn({
    required this.currentWord,
    required this.isSeed,
    required this.inputController,
    required this.onSubmit,
    required this.onSOS,
  });

  @override
  State<_WordChainMyTurn> createState() => _WordChainMyTurnState();
}

class _WordChainMyTurnState extends State<_WordChainMyTurn> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  double _measureTextWidth(
    String text,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();

    return painter.width;
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final secondary = theme.colorScheme.secondary;
    final muted = theme.textTheme.bodySmall?.color ??
        theme.colorScheme.onSurface.withOpacity(0.6);
    final lastWord = _lastWordPrefix(widget.currentWord);

    final sourceLabel = widget.isSeed ? 'Từ hệ thống' : 'Từ đối phương';
    final helper = lastWord.isEmpty
        ? 'Nhập 2 từ bất kỳ'
        : 'Nhập từ bắt đầu bằng "$lastWord"';
    final prefixText = lastWord.isEmpty ? '' : '$lastWord ';
    final textStyle = theme.textTheme.bodyLarge!.copyWith(
      fontWeight: FontWeight.w600,
    );

    final prefixWidth = prefixText.isEmpty
        ? 0.0
        : _measureTextWidth(prefixText, textStyle);


    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        children: [
          Text(
            'Từ khóa hiện tại',
            style: theme.textTheme.bodySmall?.copyWith(
              letterSpacing: 1.4,
              color: muted,
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
                  color: theme.colorScheme.surface,
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
                      widget.currentWord.isEmpty ? '...' : widget.currentWord,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      sourceLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: muted,
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
                    color: secondary,
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
              // ===== KHUNG Ô NHẬP =====
              GestureDetector(
                onTap: () => _focusNode.requestFocus(),
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: accent.withOpacity(0.35),
                      width: 2,
                    ),
                  ),
                ),
              ),

              // ===== TEXTFIELD ẨN (NHẬN INPUT THẬT) =====
              Positioned.fill(
                child: TextField(
                  controller: widget.inputController,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => widget.onSubmit(),
                  cursorColor: theme.colorScheme.primary,

                  // ⚠️ chữ ẩn nhưng GIỮ fontSize & lineHeight
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.transparent,
                  ),

                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.fromLTRB(
                      16 + prefixWidth, // 👈 ĐẨY CURSOR SAU PREFIX
                      16,
                      16,
                      16,
                    ),
                  ),
                ),
              ),


              // ===== TEXTFIELD ẨN (CHỈ ĐỂ NHẬN INPUT) =====
              Positioned.fill(
                child: IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: widget.inputController,
                        builder: (context, value, _) {
                          final suffix = value.text;

                          return RichText(
                            text: TextSpan(
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              children: [
                                if (lastWord.isNotEmpty)
                                  TextSpan(
                                    text: '$lastWord ',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                TextSpan(
                                  text: suffix.isEmpty ? '...' : suffix,
                                  style: TextStyle(
                                    color: suffix.isEmpty
                                        ? muted
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),

              // ===== LABEL "Đến lượt bạn" =====
              Positioned(
                left: 12,
                top: -10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Đến lượt bạn',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: accent,
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
                color: muted,
              ),
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: widget.onSOS,
            icon: Icon(
              Icons.help_outline,
              size: 18,
              color: muted,
            ),
            label: Text(
              'SOS • Cầu cứu',
              style: theme.textTheme.labelMedium?.copyWith(
                color: muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: theme.brightness == Brightness.dark
                    ? AppTheme.darkBorder
                    : AppTheme.lightBorder,
              ),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}

class _WordChainOpponentTurn extends StatelessWidget {
  final String currentWord;
  final String? otherAvatarKey;

  const _WordChainOpponentTurn({
    required this.currentWord,
    required this.otherAvatarKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.color ??
        theme.colorScheme.onSurface.withOpacity(0.6);
    final lastWord = currentWord.isEmpty ? '...' : currentWord;

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
                  color: theme.colorScheme.secondary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
              ),
              AnonymousAvatar(
                avatarKey: otherAvatarKey,
                radius: 40,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
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
                  'Đang suy nghĩ...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Từ khóa trước: $lastWord',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: muted,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 48,
            width: 200,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ],
      ),
    );
  }
}

class _WordChainActionBar extends StatelessWidget {
  final VoidCallback onSubmit;

  const _WordChainActionBar({
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
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
          onPressed: onSubmit,
          icon: const Icon(Icons.send, size: 18),
          label: const Text('Gửi câu trả lời'),
        ),
      ),
    );
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
    final color =
        Theme.of(context).colorScheme.onSurface.withOpacity(0.4);

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
                  color: color,
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

String _lastWordPrefix(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  final parts = trimmed.split(RegExp(r'\s+'));
  return parts.isEmpty ? '' : parts.last;
}
