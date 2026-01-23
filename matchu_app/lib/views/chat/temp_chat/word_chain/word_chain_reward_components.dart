import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import 'package:matchu_app/models/word_chain.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/chat/temp_chat/word_chain/word_chain_reward_data.dart';


const _rewardCardRadius = BorderRadius.all(Radius.circular(16));

Color _rewardBorderColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? AppTheme.darkBorder
      : AppTheme.lightBorder;
}

Color _rewardSurfaceColor(ThemeData theme) {
  return theme.cardTheme.color ?? theme.colorScheme.surface;
}

BoxDecoration rewardCardDecoration(
  ThemeData theme, {
  Color? color,
  BorderRadius? radius,
  BorderSide? border,
}) {
  final borderSide = border ?? BorderSide(color: _rewardBorderColor(theme));
  return BoxDecoration(
    color: color ?? _rewardSurfaceColor(theme),
    borderRadius: radius ?? _rewardCardRadius,
    border: Border.all(color: borderSide.color, width: borderSide.width),
  );
}

class RewardHeroCard extends StatelessWidget {
  final bool isWinner;

  const RewardHeroCard({
    required this.isWinner,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = isWinner ? AppTheme.successColor : theme.colorScheme.primary;
    final title = isWinner ? '🎉 Bạn đã chiến thắng!' : '😅 Bạn đã thua.';
    final subtitle = isWinner
        ? 'Hãy đặt một câu hỏi cho đối phương.'
        : 'Hãy chuẩn bị trả lời câu hỏi từ đối phương.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: rewardCardDecoration(theme).copyWith(
        gradient: LinearGradient(
          colors: [
            accent.withOpacity(theme.brightness == Brightness.dark ? 0.2 : 0.12),
            _rewardSurfaceColor(theme),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withOpacity(0.2),
            ),
            child: Icon(
              isWinner ? Icons.emoji_events : Icons.sentiment_satisfied_alt,
              color: accent,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Giai đoạn thưởng',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    height: 1.35,
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

class RewardMotto extends StatelessWidget {
  const RewardMotto();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        '“Chiến thắng cho bạn quyền đặt thử thách — nhưng kết nối chỉ xảy ra '
        'khi cả hai đều được tôn trọng.”',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          fontStyle: FontStyle.italic,
          color: theme.colorScheme.onSurface.withOpacity(0.55),
          height: 1.4,
        ),
      ),
    );
  }
}

class RewardStepIndicator extends StatelessWidget {
  final WordChainRewardPhase phase;

  const RewardStepIndicator({
    required this.phase,
  });

  static const _steps = <String>[
    'Kết quả',
    'Hỏi',
    'Đáp',
    'Duyệt',
  ];

  int _phaseIndex() {
    switch (phase) {
      case WordChainRewardPhase.idle:
        return 0;
      case WordChainRewardPhase.asking:
        return 1;
      case WordChainRewardPhase.answering:
        return 2;
      case WordChainRewardPhase.reviewing:
        return 3;
      case WordChainRewardPhase.done:
        return _steps.length;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeIndex = _phaseIndex();
    final accent = theme.colorScheme.primary;

    return Row(
      children: List.generate(_steps.length, (index) {
        final isComplete = index < activeIndex;
        final isActive = index == activeIndex && activeIndex < _steps.length;
        final color = isComplete
            ? AppTheme.successColor
            : isActive
                ? accent
                : theme.colorScheme.onSurface.withOpacity(0.35);

        return Expanded(
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isComplete
                      ? AppTheme.successColor.withOpacity(0.18)
                      : isActive
                          ? accent.withOpacity(0.15)
                          : theme.colorScheme.surfaceVariant,
                  border: Border.all(
                    color: color.withOpacity(isActive || isComplete ? 1 : 0.4),
                  ),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _steps[index],
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class RewardWaitingCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const RewardWaitingCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: rewardCardDecoration(theme),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.65),
                    height: 1.35,
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

class LockedQuestionCard extends StatelessWidget {
  final String question;

  const LockedQuestionCard({
    required this.question,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: rewardCardDecoration(
        theme,
        color: theme.colorScheme.surfaceVariant,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.lock_1, size: 16, color: accent),
              const SizedBox(width: 6),
              Text(
                'Câu hỏi',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            question,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class AnswerCard extends StatelessWidget {
  final String answer;

  const AnswerCard({
    required this.answer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: rewardCardDecoration(
        theme,
        color: theme.colorScheme.surfaceVariant,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.message, size: 16, color: accent),
              const SizedBox(width: 6),
              Text(
                'Câu trả lời',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            answer,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class CountdownChip extends StatelessWidget {
  final int secondsLeft;

  const CountdownChip({
    required this.secondsLeft,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accent.withOpacity(0.4),
          width: 1.5, 
         ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.timer_1, size: 16, color: accent),
          const SizedBox(width: 6),
          Text(
            'Tự động sau ${secondsLeft}s',
            style: theme.textTheme.bodySmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class SafetyNote extends StatelessWidget {
  final String text;

  const SafetyNote({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurface.withOpacity(0.55);

    return Row(
      children: [
        Icon(Icons.shield_outlined, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class RewardTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final int maxLength;
  final int minLines;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const RewardTextField({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.maxLength,
    required this.minLines,
    required this.maxLines,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        counterText: '',
      ),
    );
  }
}

class LengthRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLength;

  const LengthRow({
    required this.label,
    required this.controller,
    required this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final length = value.text.length;
        final overLimit = length > maxLength;
        final color =
            overLimit ? theme.colorScheme.error : theme.colorScheme.onSurface;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$length/$maxLength',
              style: theme.textTheme.bodySmall?.copyWith(
                color: color.withOpacity(overLimit ? 0.9 : 0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }
}

class WordChainRewardQuestionTile extends StatelessWidget {
  final WordChainRewardQuestion card;
  final bool selected;
  final VoidCallback? onTap;

  const WordChainRewardQuestionTile({
    super.key,
    required this.card,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final borderColor = selected ? accent : _rewardBorderColor(theme);
    final background = selected ? accent.withOpacity(0.08) : _rewardSurfaceColor(theme);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: _rewardCardRadius,
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: _rewardCardRadius,
            border: Border.all(color: borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(card.icon, size: 18, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.prompt,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (card.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        card.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle,
                  size: 18,
                  color: accent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
