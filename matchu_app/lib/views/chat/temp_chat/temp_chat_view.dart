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
        toolbarHeight: 78,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.8),
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withOpacity(0.4),
                width: 0.5, // 👈 mảnh
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).brightness == Brightness.dark 
                        ? Colors.black.withOpacity(0.08)
                        : Colors.white.withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ),

        title: Stack(
          alignment: Alignment.center,
          children: [
            Obx(() {
              final rating = controller.otherAvgRating.value;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: theme.textTheme.headlineSmall,
                      children: const [
                        TextSpan(
                          text: "● ",
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(text: "Người lạ"),
                      ],
                    ),
                  ),
                  if (rating != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2), // 🌕 nền vàng nhạt
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: Colors.amber.withOpacity(0.6), // viền vàng nhẹ
                          width: 0.3,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            rating.toStringAsFixed(1),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color.fromARGB(255, 248, 100, 2)
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Iconsax.star,
                            size: 16,
                            color: const Color.fromARGB(255, 250, 188, 3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            }),
          ],
        ),      
        actions: [
          Obx(() {
            final sec = controller.remainingSeconds.value;
            final isDanger = sec <= 30;
            final minutes = sec ~/ 60;
            final seconds = sec % 60;

            return Padding(
              padding: const EdgeInsets.only(
                right: 12,
                top: 10,
                bottom: 10,
              ),
              child: Align( 
                alignment: Alignment.center,
                child: Container(
                  height: 33,        
                  width: 94, 
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDanger
                        ? theme.colorScheme.error.withOpacity(0.15)
                        : theme.colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDanger
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                      width: 0.6,
                    ),
                  ),
                  child: Text(
                    "⏱ ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      height: 1.0, // 👈 QUAN TRỌNG: FIX LỆCH BASELINE
                      fontWeight: FontWeight.w600,
                      color: isDanger
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
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

