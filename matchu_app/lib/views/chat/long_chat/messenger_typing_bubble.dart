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
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        opacity: show ? 1 : 0,
        child: show
            ? TypingBubbleRowPermanent(
                senderId: senderId,
                showAvatar: showAvatar,
              )
            : const SizedBox(height: 0),
      ),
    );
  }
}
