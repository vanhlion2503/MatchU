import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/matching/matching_controller.dart';
import '../../controllers/chat/temp_chat_controller.dart';

class TempChatView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final args = Get.arguments as Map<String, dynamic>;
    final roomId = args["roomId"] as String;

    final controller = Get.put(TempChatController(roomId), tag: roomId);
    final controllerMatch = Get.find<MatchingController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Chat tạm"),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () async {
            await controller.leaveRoom();
            controllerMatch.isMatched.value = false;
          }
        ),
      ),
      body: const Center(
        child: Text("💬 Chat ở đây"),
      ),
    );
  }
}
