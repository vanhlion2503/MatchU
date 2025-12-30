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
        // Listen stream để detect messages mới
        if (snap.hasData) {
          final docs = snap.data!.docs;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            controller.onNewMessages(docs.length, docs);
          });
        }

        // Sử dụng allMessages từ controller
        return Obx(() {
          final docs = controller.allMessages;
          
          if (docs.isEmpty && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // ✅ Đảm bảo itemCount hợp lệ
          // +1 cho typing slot, +1 cho loading indicator nếu đang load more
          final itemCount = docs.length + 1 + (controller.isLoadingMore ? 1 : 0);

          return ScrollablePositionedList.builder(
            reverse: true, // ✅ Tin mới ở index 0, hiển thị ở đáy
            itemScrollController: controller.itemScrollController,
            itemPositionsListener: controller.itemPositionsListener,
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              bottomPadding,
            ),
            itemCount: itemCount,
          itemBuilder: (_, i) {
            /// ================= TYPING SLOT (Ở ĐÁY - index 0) =================
            if (i == 0) {
              return Obx(() {
                final otherUid = controller.otherUid.value;
                if (otherUid == null) return const SizedBox();

                return MessengerTypingBubble(
                  show: controller.otherTyping.value,
                  senderId: otherUid,
                );
              });
            }

            /// ================= LOADING INDICATOR (Ở ĐẦU - index cao nhất) =================
            if (controller.isLoadingMore && i == itemCount - 1) {
              return Obx(() {
                if (!controller.isLoadingMore) return const SizedBox();
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                    ),
                  ),
                );
              });
            }

            /// ================= MESSAGE =================
            // Với reverse: true, index 0 là typing, index 1+ là messages
            // docs[0] là tin mới nhất
            final messageIndex = i - 1;
            
            // ✅ Kiểm tra bounds để tránh RangeError
            if (messageIndex < 0 || messageIndex >= docs.length) {
              return const SizedBox();
            }
            
            final doc = docs[messageIndex];
            final data = doc.data();
            final isMe = data["senderId"] == uid;
            final isLastInGroup = _isLastInGroup(docs, messageIndex);
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
                              final isMyLastMessage = isMe && messageIndex == 0;
                              final isNewestMessage = messageIndex == 0;

                              return ChatRowPermanent(
                                messageId: doc.id,
                                senderId: data["senderId"],
                                text: data["text"] ?? "",
                                type: data["type"] ?? "text",
                                isMe: isMe,
                                showAvatar: !isMe && isLastInGroup,
                                status: isMyLastMessage
                                    ? unread == 0
                                        ? MessageStatus.seen
                                        : MessageStatus.sent
                                    : null,
                                seenByUid:
                                    isMyLastMessage && unread == 0 && otherUid != null
                                        ? otherUid
                                        : null,
                                smallMargin: _shouldGroup(docs, i),
                                showTime: isLastInGroup && !isNewestMessage,
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
        });
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
    // ✅ Kiểm tra bounds
    if (index < 0 || index >= docs.length) return false;
    
    // Với reverse: true, index 0 là tin mới nhất
    // Tin mới hơn có index nhỏ hơn
    if (index == docs.length - 1) return false; // Tin cũ nhất

    // ✅ Kiểm tra bounds cho next
    if (index + 1 >= docs.length) return false;

    final curr = docs[index];
    final next = docs[index + 1]; // Tin cũ hơn

    if (curr["senderId"] != next["senderId"]) return false;

    final currTime = _getTime(curr["createdAt"]);
    final nextTime = _getTime(next["createdAt"]);

    if (currTime == null || nextTime == null) return false;

    // currTime mới hơn nextTime (vì reverse)
    return currTime.difference(nextTime).inMinutes < 2;
  }

  bool _isLastInGroup(
      List<QueryDocumentSnapshot> docs, int index) {
    // ✅ Kiểm tra bounds
    if (index < 0 || index >= docs.length) return true;
    
    // Với reverse: true, index 0 là tin mới nhất
    if (index == 0) return true; // Tin mới nhất luôn show time

    // ✅ Kiểm tra bounds cho prev
    if (index - 1 < 0) return true;

    final curr = docs[index];
    final prev = docs[index - 1]; // Tin mới hơn

    if (curr["senderId"] != prev["senderId"]) return true;

    final currTime = _getTime(curr["createdAt"]);
    final prevTime = _getTime(prev["createdAt"]);

    if (currTime == null || prevTime == null) return true;

    // prevTime mới hơn currTime (vì reverse)
    return prevTime.difference(currTime).inMinutes >= 2;
  }

  String _formatTime(dynamic value) {
    final dt = _getTime(value);
    if (dt == null) return "";
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }
}
