import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/matching/matching_controller.dart';
import 'package:matchu_app/views/chat/temp_chat/bottom_action_bar.dart';
import '../../../controllers/chat/temp_chat_controller.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/views/chat/temp_chat/messages_list.dart';


class TempChatView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final args = Get.arguments as Map<String, dynamic>;
    final roomId = args["roomId"] as String;

    final controller = Get.put(TempChatController(roomId), tag: roomId);
    final matchController = Get.find<MatchingController>();

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 72,
        elevation: 0,
        backgroundColor: theme.colorScheme.surface.withOpacity(0.95),

        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Divider(
            height: 0.5,
            thickness: 0.5,
            color: theme.dividerColor.withOpacity(0.4),
          ),
        ),

        title: Obx(() {
          final rating = controller.otherAvgRating.value;
          final ratingCount = controller.otherRatingCount.value; // 👈 nếu có

          return Row(
            children: [
              /// 👤 Avatar + online dot
              Stack(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    child: Icon(
                      Iconsax.user,
                      color: theme.colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.surface,
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 12),

              /// 🧾 Name + rating
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Người lạ",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    if (rating != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFF86402),
                                  ),
                                ),
                                const SizedBox(width: 3),
                                const Icon(
                                  Iconsax.star1,
                                  size: 14,
                                  color: Color(0xFFFABC03),
                                ),
                              ],
                            ),
                          ),
                          if (ratingCount != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              "· $ratingCount đánh giá",
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        }),

        actions: [
          Obx(() {
            final sec = controller.remainingSeconds.value;
            final isDanger = sec <= 30;
            final minutes = sec ~/ 60;
            final seconds = sec % 60;

            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                height: 33,
                width: 92,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDanger
                      ? theme.colorScheme.error.withOpacity(0.12)
                      : theme.colorScheme.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDanger
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                    width: 0.6,
                  ),
                ),
                child: Text(
                  "⏱ ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}",
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.0,
                    color: isDanger
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                ),
              ),
            );
          }),
        ],
      ),

      body: SafeArea(child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Expanded(child: MessagesList(roomId, controller)),
            BottomActionBar(controller),
          ],
        ),
      )),
    );
  }
}

