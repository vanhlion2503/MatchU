import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/temp_chat_controller.dart';
import 'package:matchu_app/widgets/animated_dots.dart';
import 'package:matchu_app/views/chat/temp_chat/anonymous_avatar.dart';

class TypingBubbleRow extends StatelessWidget {
  final TempChatController controller;

  const TypingBubbleRow({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 36,
            child: Obx(() {
              final key = controller.otherAnonymousAvatar.value;
              if (key == null) return const SizedBox();

              return AnonymousAvatar(
                avatarKey: key,
                radius: 16,
              );
            }),
          ),
          const SizedBox(width: 6),

          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: SizedBox(
              width: 52,
              height: 36,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? theme.colorScheme.surface
                      : const Color(0xFFEEF2F7),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: AnimatedDots(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  size: 3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

