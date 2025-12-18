import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/controllers/chat/temp_chat_controller.dart';
import 'package:matchu_app/theme/app_theme.dart';

import 'package:matchu_app/views/chat/temp_chat/chat_row.dart';
import 'package:matchu_app/views/chat/temp_chat/animate_message_bubble.dart';
import 'package:matchu_app/views/chat/temp_chat/system_message_event.dart';

class MessagesList extends StatelessWidget {
  final String roomId;
  final TempChatController controller;

  const MessagesList(this.roomId, this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final uid = Get.find<AuthController>().user!.uid;
    final theme = Theme.of(context);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("tempChats")
          .doc(roomId)
          .collection("messages")
          .orderBy("createdAt")
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();

        final docs = snap.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length + 1,
          itemBuilder: (_, i) {
            // ================= HEADER =================
            if (i == 0) {
              return Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: theme.brightness == Brightness.dark
                          ? AppTheme.darkBorder
                          : AppTheme.lightBorder,
                    ),
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

            final index = i - 1;
            if (index < 0 || index >= docs.length) {
              return const SizedBox();
            }

            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final type = data["type"] ?? "text";

            // ================= SYSTEM MESSAGE =================
            if (type == "system") {
              final code = data["systemCode"];
              final senderId = data["senderId"];
              final targetUid = data["targetUid"];

              // 👀 LIKE: chỉ hiện cho đối phương
              if (code == "like" && targetUid != uid) {
                return const SizedBox();
              }

              // 👀 END: không hiện cho người bấm thoát
              if (code == "ended" && senderId == uid) {
                return const SizedBox();
              }

              return SystemMessageEvent(
                text: data["text"] ?? "",
              );
            }

            // ================= TEXT MESSAGE =================
            final isMe = data["senderId"] == uid;

            final grouped = _shouldGroup(docs, index);
            final showTime = _isLastInGroup(docs, index);

            return AnimatedMessageBubble(
              child: ChatRow(
                text: data["text"] ?? "",
                isMe: isMe,
                showAvatar: !grouped && !isMe,
                smallMargin: grouped,
                showTime: showTime,
                time: _formatTime(data["createdAt"]),
              ),
            );
          },
        );
      },
    );
  }

  // ================= HELPER =================

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
    if (dt == null) return "";
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }
}
