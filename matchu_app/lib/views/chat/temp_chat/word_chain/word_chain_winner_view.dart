import 'package:flutter/material.dart';
import 'package:matchu_app/theme/app_theme.dart';

class WordChainWinnerView extends StatelessWidget {
  final bool isWinner;
  final bool sendingReward;
  final ValueChanged<WordChainWinnerCard> onSelectCard;

  const WordChainWinnerView({
    super.key,
    required this.isWinner,
    required this.sendingReward,
    required this.onSelectCard,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.color ??
        theme.colorScheme.onSurface.withOpacity(0.6);
    final headline =
        isWinner ? 'Chúc mừng! 🎉' : 'Kết thúc';
    final description = isWinner
        ? 'Bạn đã thắng! Hãy chọn 1 điều bạn muốn biết về đối phương:'
        : 'Đang chờ đối phương chọn thẻ.';

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
                  color: theme.colorScheme.primary.withOpacity(0.12),
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
              color: muted,
            ),
          ),
          const SizedBox(height: 24),
          Column(
            children: kWordChainWinnerCards.map((card) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: WordChainWinnerCardTile(
                  card: card,
                  enabled: isWinner && !sendingReward,
                  onTap: () => onSelectCard(card),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class WordChainWinnerCard {
  final String title;
  final String subtitle;
  final String prompt;
  final IconData icon;
  final Color color;

  const WordChainWinnerCard({
    required this.title,
    required this.subtitle,
    required this.prompt,
    required this.icon,
    required this.color,
  });
}

const List<WordChainWinnerCard> kWordChainWinnerCards = [
  WordChainWinnerCard(
    title: 'Thẻ Kỷ Niệm',
    subtitle: 'Kể về một trải nghiệm xấu hổ nhất thời đi học?',
    prompt: 'Kể về một trải nghiệm xấu hổ nhất thời đi học?',
    icon: Icons.auto_awesome,
    color: Color(0xFFD8B4FE),
  ),
  WordChainWinnerCard(
    title: 'Thẻ Quan Điểm',
    subtitle: 'Tật xấu nào của người khác mà bạn không thể chịu đựng nổi?',
    prompt: 'Tật xấu nào của người khác mà bạn không thể chịu đựng nổi?',
    icon: Icons.chat_bubble_outline,
    color: Color(0xFFFDBA74),
  ),
  WordChainWinnerCard(
    title: 'Thẻ Sở Thích',
    subtitle: 'Nếu có 1 tỷ, điều đầu tiên bạn mua là gì?',
    prompt: 'Nếu có 1 tỷ, điều đầu tiên bạn mua là gì?',
    icon: Icons.sports_esports,
    color: Color(0xFF86EFAC),
  ),
];

class WordChainWinnerCardTile extends StatelessWidget {
  final WordChainWinnerCard card;
  final bool enabled;
  final VoidCallback onTap;

  const WordChainWinnerCardTile({
    super.key,
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
            color: theme.colorScheme.surface,
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
