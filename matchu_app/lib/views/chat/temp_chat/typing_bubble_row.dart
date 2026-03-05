import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/temp_chat_controller.dart';
import 'package:matchu_app/views/chat/temp_chat/anonymous_avatar.dart';
import 'package:matchu_app/widgets/chat_typing_dots.dart';

class TypingBubbleRow extends StatelessWidget {
  final TempChatController controller;

  const TypingBubbleRow({super.key, required this.controller});

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
            child: Obx(() {
              final key = controller.otherAnonymousAvatar.value;
              if (key == null) return const SizedBox();

              return AnonymousAvatar(avatarKey: key, radius: 16);
            }),
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

class MessengerTypingBubbleTemp extends StatelessWidget {
  final bool show;
  final TempChatController controller;

  const MessengerTypingBubbleTemp({
    super.key,
    required this.show,
    required this.controller,
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
              ? TypingBubbleRow(
                key: const ValueKey('typing-temp-visible'),
                controller: controller,
              )
              : const SizedBox.shrink(key: ValueKey('typing-temp-hidden')),
    );
  }
}
