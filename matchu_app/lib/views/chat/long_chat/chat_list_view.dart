import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/routes/app_router.dart';
import 'package:matchu_app/controllers/chat/chat_list_controller.dart';
import 'package:matchu_app/services/chat/chat_service.dart';


class ChatListView extends StatelessWidget {
  const ChatListView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ChatListController());
    final service = ChatService();
    final uid = service.uid;

    return Scaffold(
      appBar: AppBar(title: const Text("Tin nhắn")),
      body: StreamBuilder(
        stream: controller.rooms,
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text("Chưa có cuộc trò chuyện"));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final room = docs[i].data();
              final roomId = docs[i].id;

              final lastMessage = room["lastMessage"] ?? "";
              final lastSender = room["lastSenderId"];
              final unread = room["unread"]?[uid] ?? 0;

              final isMe = lastSender == uid;

              return ListTile(
                leading: const CircleAvatar(
                  radius: 22,
                  child: Icon(Icons.person),
                ),
                title: Text(
                  isMe ? "Bạn: $lastMessage" : lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: unread > 0
                    ? CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.red,
                        child: Text(
                          unread.toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : null,
                onTap: () async {
                  await service.markAsRead(roomId);

                  Get.toNamed(
                    AppRouter.chat,
                    arguments: {"roomId": roomId},
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
