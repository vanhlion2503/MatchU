import 'package:flutter/material.dart';
import 'package:matchu_app/controllers/chat/chat_controller.dart';

class ChatInput extends StatelessWidget {
  final ChatController controller;
  const ChatInput({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller.inputController,
                decoration: const InputDecoration(
                  hintText: "Nhập tin nhắn...",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: () => controller.sendMessage(),
            ),
          ],
        ),
      ),
    );
  }
}
