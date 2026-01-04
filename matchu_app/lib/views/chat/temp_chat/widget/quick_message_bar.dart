import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/temp_chat_controller.dart';

class QuickMessageBar extends StatelessWidget {
  final TempChatController controller;
  const QuickMessageBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(() {
      if (!controller.showQuickMessages.value) {
        return const SizedBox.shrink();
      }

      final messages = controller.currentQuickMessages;
      if (messages.isEmpty) return const SizedBox.shrink();

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        height: 55,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: messages.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final msg = messages[i];

            return GestureDetector(
              onTap: () {
                controller.send(
                  msg.text,
                  type: msg.type,
                );

                controller.switchToIceBreaker();

                controller.showQuickMessages.value = false;
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  msg.text,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            );
          },
        ),
      );
    });
  }
}
