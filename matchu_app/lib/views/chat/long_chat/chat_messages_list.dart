import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/views/chat/long_chat/messenger_typing_bubble.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/controllers/chat/chat_controller.dart';
import 'package:matchu_app/views/chat/long_chat/chat_row_permanent.dart';
import 'package:matchu_app/views/chat/temp_chat/animate_message_bubble.dart';
import 'package:matchu_app/models/message_status.dart';


class ChatMessagesList extends StatelessWidget {
  final ChatController controller;
  const ChatMessagesList({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final uid = Get.find<AuthController>().user!.uid;
    final theme = Theme.of(context);

    final bottomPadding =
        controller.bottomBarHeight.value +
        MediaQuery.of(context).padding.bottom;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: controller.listenMessages(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        final count = docs.length;

        // ❗ Logic này KHÔNG cần Obx
        if (count != controller.lastMessageCount) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            controller.onNewMessages(count);
          });
        }

        return ScrollablePositionedList.builder(
          itemScrollController: controller.itemScrollController,
          itemPositionsListener: controller.itemPositionsListener,
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            bottomPadding,
          ),
          itemCount: docs.length + 1, // slot typing cố định
          itemBuilder: (_, i) {
            /// ================= TYPING SLOT =================
            if (i == docs.length) {
              return Obx(() {
                final otherUid = controller.otherUid.value;
                if (otherUid == null) return const SizedBox();

                return MessengerTypingBubble(
                  show: controller.otherTyping.value,
                  senderId: otherUid,
                );
              });
            }

            /// ================= MESSAGE =================
            final doc = docs[i];
            final data = doc.data();
            final isMe = data["senderId"] == uid;
            final isLastInGroup = _isLastInGroup(docs, i);
            final isLastMessage = i == docs.length - 1;
            final isMyLast = isMe && isLastMessage;
            final otherUid = controller.otherUid.value;

            double dragDx = 0;

            return AnimatedMessageBubble(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return Listener(
                    onPointerMove: (event) {
                      if (isMe) return;

                      final dx = event.delta.dx;
                      final dy = event.delta.dy;

                      if (dx <= 0) return;
                      if (dx.abs() < dy.abs()) return;

                      dragDx += dx;
                      dragDx = dragDx.clamp(0, 80);
                      setState(() {});
                    },
                    onPointerUp: (_) {
                      if (dragDx > 32) {
                        HapticFeedback.lightImpact();
                        controller.startReply({
                          "id": doc.id,
                          "text": data["text"],
                        });
                      }
                      setState(() => dragDx = 0);
                    },
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Positioned(
                          left: 12 + dragDx * 0.5,
                          child: Opacity(
                            opacity: (dragDx / 40).clamp(0, 1),
                            child: Icon(
                              Iconsax.redo,
                              color: theme.colorScheme.primary,
                              size: 24,
                            ),
                          ),
                        ),
                        Transform.translate(
                          offset: Offset(dragDx, 0),
                          child: Opacity(
                            opacity:
                                (1 - dragDx / 120).clamp(0.7, 1),
                            child: Obx(() {
                              final unread = controller.otherUnread.value;
                              final otherUid = controller.otherUid.value;

                              return ChatRowPermanent(
                                messageId: doc.id,
                                senderId: data["senderId"],
                                text: data["text"] ?? "",
                                type: data["type"] ?? "text",
                                isMe: isMe,
                                showAvatar: !isMe && isLastInGroup,
                                status: isMyLast
                                    ? unread == 0
                                        ? MessageStatus.seen
                                        : MessageStatus.sent
                                    : null,
                                seenByUid:
                                    isMyLast && unread == 0 && otherUid != null
                                        ? otherUid
                                        : null,
                                smallMargin: _shouldGroup(docs, i),
                                showTime: isLastInGroup,
                                time: _formatTime(data["createdAt"]),
                                replyText: data["replyText"],
                                replyToId: data["replyToId"],
                                highlighted:
                                    controller.highlightedMessageId.value == doc.id,
                                onTapReply: data["replyToId"] != null
                                    ? () => controller.scrollToMessage(
                                          docs: docs,
                                          messageId: data["replyToId"],
                                        )
                                    : null,
                              );
                            }),


                          ),
                        ),
                      ],
                    ),
                  );
                },
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

  bool _shouldGroup(
      List<QueryDocumentSnapshot> docs, int index) {
    if (index == 0) return false;

    final prev = docs[index - 1];
    final curr = docs[index];

    if (prev["senderId"] != curr["senderId"]) return false;

    final prevTime = _getTime(prev["createdAt"]);
    final currTime = _getTime(curr["createdAt"]);

    if (prevTime == null || currTime == null) return false;

    return currTime.difference(prevTime).inMinutes < 2;
  }

  bool _isLastInGroup(
      List<QueryDocumentSnapshot> docs, int index) {
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
