import 'package:flutter/material.dart';
import 'typing_bubble_row_permanent.dart';

class MessengerTypingBubble extends StatelessWidget {
  final bool show;
  final String senderId;
  final bool showAvatar;

  const MessengerTypingBubble({
    super.key,
    required this.show,
    required this.senderId,
    this.showAvatar = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));

        return FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            axisAlignment: 1,
            child: SlideTransition(position: slide, child: child),
          ),
        );
      },
      child:
          show
              ? TypingBubbleRowPermanent(
                key: const ValueKey('typing-long-visible'),
                senderId: senderId,
                showAvatar: showAvatar,
              )
              : const SizedBox.shrink(key: ValueKey('typing-long-hidden')),
    );
  }
}
