import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/temp_chat_controller.dart';
import 'package:matchu_app/controllers/game/telepathy_controller.dart';

class TelepathyInviteBar extends StatelessWidget {
  final TempChatController controller;

  const TelepathyInviteBar({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final telepathy = controller.telepathy;

    return Obx(() {
      if (telepathy.status.value != TelepathyStatus.inviting) {
        return const SizedBox.shrink();
      }

      final waiting = telepathy.myConsent.value;
      final otherAccepted = telepathy.otherConsent.value;

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.flash_on,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Minigame: Kiểm tra độ hợp nhau?",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "Cả 2 cùng đồng ý mới bắt đầu.",
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            if (waiting)
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      otherAccepted
                          ? "Đang bắt đầu..."
                          : "Đã đồng ý, chờ người kia...",
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => telepathy.respond(false),
                    child: const Text("Để sau"),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => telepathy.respond(false),
                      child: const Text("Bỏ qua 🙅"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => telepathy.respond(true),
                      child: const Text("Đồng ý 🤙"),
                    ),
                  ),
                ],
              ),
          ],
        ),
      );
    });
  }
}
