import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/controllers/chat/temp_chat_controller.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:matchu_app/views/chat/temp_chat/chat_row.dart';
import 'package:matchu_app/views/chat/temp_chat/animate_message_bubble.dart';


class MessagesList extends StatelessWidget {
  final String roomId;
  final TempChatController controller;
  
  const MessagesList(this.roomId,this.controller);


  @override
  Widget build(BuildContext context) {
    final uid = Get.find<AuthController>().user!.uid;
    final theme = Theme.of(context);
    return StreamBuilder(
      stream: FirebaseFirestore.instance
              .collection("tempChats")
              .doc(roomId)
              .collection("messages")
              .orderBy("createdAt")
              .snapshots(), 

      builder: (context, snap){
        if (!snap.hasData) return const SizedBox();
        final docs = snap.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length + 2,
          itemBuilder: (_, i) {
            if (i == 0) {
              return Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  )
                ),
                child: Text(
                  "Bắt đầu cuộc trò chuyện",
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
            }
            if (i == docs.length + 1) {
              return Obx(() {
                if (controller.remainingSeconds.value == 30) {
                  return Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "⚠️ Sắp hết giờ! Còn 30 giây.",
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: theme.colorScheme.error),
                      ),
                    ),
                  );
                }
                return const SizedBox();
              });
            }

            final index = i - 1;
            final doc = docs[index];
            final isMe = doc["senderId"] == uid;

            final grouped = _shouldGroup(docs, index);
            final showTime = _isLastInGroup(docs, index);

            return AnimatedMessageBubble(
              child: ChatRow(
                text: doc["text"],
                isMe: isMe,
                showAvatar: !grouped && !isMe,
                smallMargin: grouped,
                showTime: showTime,
                time: _formatTime(doc["createdAt"]),
              ),
            );
          },
        );
      });
  }

  DateTime? _getTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    return null;
  }

  bool _shouldGroup(List docs, int index) {
    if (index == 0) return false;

    final prev = docs[index - 1];
    final curr = docs[index];

    if (prev["senderId"] != curr["senderId"]) return false;

    final prevTime = _getTime(prev["createdAt"]);
    final currTime = _getTime(curr["createdAt"]);

    if (prevTime == null || currTime == null) return false;

    return currTime.difference(prevTime).inMinutes < 2;
  }


  bool _isLastInGroup(List docs, int index) {
    if (index == docs.length - 1) return true;

    final curr = docs[index];
    final next = docs[index + 1];

    if (curr["senderId"] != next["senderId"]) return true;

    final currTime = _getTime(curr["createdAt"]);
    final nextTime = _getTime(next["createdAt"]);

    if (currTime == null || nextTime == null) return true;

    return nextTime.difference(currTime).inMinutes >= 2;
  }


  String _formatTime(dynamic value) {
  final dt = _getTime(value);
    if (dt == null) return ""; // 👈 ĐANG GỬI
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }


}