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
        leading: IconButton(
          icon: const Icon(Iconsax.logout),
          onPressed: () => _confirmLeave(controller,matchController,),
        ),

        title: RichText(
          text: TextSpan(
            style: theme.textTheme.headlineSmall,
            children: [
              TextSpan(
                text: "● ",
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const TextSpan(
                text: "Người lạ",
              ),
            ]
          ),
        ),
        actions: [
          Obx(() {
            final sec = controller.remainingSeconds.value;
            final isDanger = sec <= 30;
            final minutes = sec ~/ 60;
            final seconds = sec % 60;

            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                backgroundColor: isDanger
                    ? theme.colorScheme.error.withOpacity(0.15)
                    : theme.colorScheme.primary.withOpacity(0.12),

                side: BorderSide(
                  color: isDanger
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),

                label: Text(
                  "⏱ ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}",
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
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

  Future<void> _confirmLeave(TempChatController controller, MatchingController matchController) async{
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: Text(
          "Thoát chat", 
          style: Get.textTheme.headlineMedium,
        ),
        content: Text(
          "Bạn có chắc muốn thoát chat không?",
          style: Get.textTheme.headlineSmall,
          ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text("Hủy"),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: Text("Thoát"),
          ),
        ],
      )
    );
    if (ok == true) {
      await controller.leaveRoom();
      matchController.isMatched.value = false;
    }
  }
}

