import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/chat_controller.dart';
import 'chat_messages_list.dart';
import 'chat_bottom_bar.dart';

class ChatBody extends StatefulWidget {
  final ChatController controller;
  const ChatBody({super.key, required this.controller});

  @override
  State<ChatBody> createState() => _ChatBodyState();
}

class _ChatBodyState extends State<ChatBody> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.updateBottomBarHeight();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return Column(
      children: [
        /// ================= MESSAGES =================
        Expanded(
          child: Stack(
            children: [
              ChatMessagesList(controller: controller),

              Obx(() {
                if (!controller.showNewMessageBtn.value) {
                  return const SizedBox();
                }

                return Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton(
                    mini: true,
                    onPressed: controller.onTapScrollToBottom,
                    child: const Icon(Icons.arrow_downward),
                  ),
                );
              }),
            ],
          ),
        ),

        /// ================= INPUT =================
        ChatBottomBar(controller: controller),
      ],
    );
  }
}
