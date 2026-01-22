import 'package:flutter/material.dart';

class WordChainCountdownView extends StatelessWidget {
  final int seconds;

  const WordChainCountdownView({
    super.key,
    required this.seconds,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final muted = theme.textTheme.bodySmall?.color ??
        theme.colorScheme.onSurface.withOpacity(0.6);

    return Center(
      child: Column(
        key: const ValueKey('word_chain_countdown'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Nối từ',
            style: theme.textTheme.headlineMedium?.copyWith(
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
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sẵn sàng bắt đầu',
            style: theme.textTheme.bodySmall?.copyWith(
              color: muted,
            ),
          ),
        ],
      ),
    );
  }
}
