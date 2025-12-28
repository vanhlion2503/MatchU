import 'package:flutter/material.dart';

class AnimatedEmoji extends StatelessWidget {
  final String text;
  final bool highlighted;
  final bool isMe;

  const AnimatedEmoji({
    required this.text,
    required this.highlighted,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: highlighted ? 1 : 0),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final shake =
            highlighted ? (value < 0.5 ? value : (1 - value)) * 4 : 0;

        return Transform.translate(
          offset: Offset(shake * (isMe ? -1 : 1), 0),
          child: AnimatedScale(
            scale: highlighted ? 1.12 : 1.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            child: child,
          ),
        );
      },
      child: Text(
        text,
        style: const TextStyle(fontSize: 42),
      ),
    );
  }
}
