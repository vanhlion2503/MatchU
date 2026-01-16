import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/temp_chat_controller.dart';
import 'package:matchu_app/controllers/game/telepathy_controller.dart';

class TelepathyPinnedBanner extends StatelessWidget {
  final TempChatController controller;

  const TelepathyPinnedBanner({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final telepathy = controller.telepathy;

    return Obx(() {
      if (telepathy.status.value != TelepathyStatus.finished) {
        return const SizedBox.shrink();
      }

      final result = telepathy.result.value;
      if (result == null) return const SizedBox.shrink();

      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            // 🔼 Bóng phía trên
            BoxShadow(
              color: theme.brightness == Brightness.dark
                  ? Colors.black.withOpacity(0.30)
                  : Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, -6),
            ),

            // 🔽 Bóng phía dưới
            BoxShadow(
              color: theme.brightness == Brightness.dark
                  ? Colors.black.withOpacity(0.35)
                  : Colors.black.withOpacity(0.10),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome,
                color: theme.colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Độ tương thích • ${result.score}%",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    result.summaryText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => telepathy.showResultOverlay.value = true,
              child: const Text("Xem chi tiết"),
            ),
          ],
        ),
      );
    });
  }
}
