import 'package:flutter/material.dart';
import 'package:matchu_app/widgets/animated_dots.dart';
import 'package:matchu_app/views/chat/temp_chat/anonymous_avatar.dart';

class TypingBubbleRow extends StatelessWidget {
  const TypingBubbleRow({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // 👤 Avatar
          const SizedBox(
            width: 36,
            child: AnonymousAvatar(),
          ),
          const SizedBox(width: 6),

          // ❗ KHÔNG DÙNG Flexible
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 16,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark 
                                            ? theme.colorScheme.surface
                                            : Color(0xFFEEF2F7),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: AnimatedDots(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              size: 4,
            ),
          ),
        ],
      ),
    );
  }
}
