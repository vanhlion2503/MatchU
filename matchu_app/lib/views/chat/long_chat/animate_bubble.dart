import 'package:flutter/material.dart';

class AnimatedBubble extends StatelessWidget {
  final Widget child;
  final bool highlighted;
  final bool isMe;
  final Color bubbleColor;

  const AnimatedBubble({
    required this.child,
    required this.highlighted,
    required this.isMe,
    required this.bubbleColor,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: highlighted ? 1 : 0),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, childWidget) {
        final shake =
            highlighted ? (value < 0.5 ? value : (1 - value)) * 4 : 0;

        return Transform.translate(
          offset: Offset(shake * (isMe ? -1 : 1), 0),
          child: AnimatedScale(
            scale: highlighted ? 1.2 : 1.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft:
                      isMe ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight:
                      isMe ? const Radius.circular(4) : const Radius.circular(16),
                ),
                boxShadow: highlighted
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.14),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : [],
              ),
              child: childWidget,
            ),
          ),
        );
      },
      child: child,
    );
  }
}
