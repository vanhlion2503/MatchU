import 'package:flutter/material.dart';
import 'package:matchu_app/views/chat/chat_widget/user_avatar.dart';
import 'package:matchu_app/widgets/chat_typing_dots.dart';

class TypingBubbleRowPermanent extends StatelessWidget {
  final String senderId;
  final bool showAvatar;

  const TypingBubbleRowPermanent({
    super.key,
    required this.senderId,
    this.showAvatar = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bubbleColor =
        theme.brightness == Brightness.dark
            ? theme.colorScheme.surface
            : const Color(0xFFEEF2F7);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 36,
            child: showAvatar ? UserAvatar(userId: senderId) : const SizedBox(),
          ),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: SizedBox(
              width: 56,
              height: 34,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Center(
                  child: ChatTypingDots(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                    dotSize: 5,
                    spacing: 3,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
