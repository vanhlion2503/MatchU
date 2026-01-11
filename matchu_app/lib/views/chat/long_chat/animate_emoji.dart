import 'package:flutter/material.dart';

class AnimatedEmoji extends StatelessWidget {
  final String text;
  final bool highlighted;
  final bool isMe;
  final bool pressed;

  const AnimatedEmoji({
    required this.text,
    required this.highlighted,
    required this.isMe,
    this.pressed = false,
  });

  @override
  Widget build(BuildContext context) {
    final targetScale = pressed ? 1.18 : (highlighted ? 1.12 : 1.0);
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
            scale: targetScale,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            child: child,
          ),
        );
      },
      child: Text(
        text,
        style: TextStyle(
          fontSize: 42,
          shadows: pressed
              ? [
                  Shadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}
