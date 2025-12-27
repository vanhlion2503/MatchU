import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/views/chat/chatInput.dart';
import 'package:matchu_app/controllers/chat/chat_controller.dart';

class ChatView extends StatelessWidget {
  const ChatView({super.key});

  @override
  Widget build(BuildContext context) {
    /// 1️⃣ LẤY roomId TỪ ARGUMENT
    final roomId = Get.arguments["roomId"] as String;

    /// 2️⃣ KHỞI TẠO CONTROLLER (MỖI ROOM 1 CONTROLLER)
    final ChatController controller =
        Get.put(ChatController(roomId), tag: roomId);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Chat Test"),
      ),

      /// ================= BODY =================
      body: Column(
        children: [
          /// ================= MESSAGE LIST =================
          Expanded(
            child: StreamBuilder(
              stream: controller.listenMessages(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (!snapshot.hasData ||
                    snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text("Chưa có tin nhắn"),
                  );
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  controller: controller.scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final msg = docs[index].data();
                    final isMe =
                        msg["senderId"] == controller.uid;

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin:
                            const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(10),
                        constraints: const BoxConstraints(
                          maxWidth: 280,
                        ),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.blueAccent
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          msg["text"] ?? "",
                          style: TextStyle(
                            color:
                                isMe ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          /// ================= INPUT =================
          ChatInput(controller: controller),
        ],
      ),
    );
  }
}
