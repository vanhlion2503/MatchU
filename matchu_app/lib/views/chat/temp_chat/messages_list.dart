import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/controllers/chat/temp_chat_controller.dart';
import 'package:matchu_app/theme/app_theme.dart';

import 'package:matchu_app/views/chat/temp_chat/chat_row.dart';
import 'package:matchu_app/views/chat/temp_chat/animate_message_bubble.dart';
import 'package:matchu_app/views/chat/temp_chat/system_message_event.dart';
import 'package:matchu_app/views/chat/temp_chat/typing_bubble_row.dart';
import 'package:matchu_app/views/chat/chat_widget/reaction_picker.dart';

class MessagesList extends StatefulWidget {
  final String roomId;
  final TempChatController controller;

  const MessagesList(this.roomId, this.controller, {super.key});

  @override
  State<MessagesList> createState() => _MessagesListState();
}

class _MessagesListState extends State<MessagesList> {
  OverlayEntry? _reactionEntry;
  // ✅ Lưu bubbleKeys để không bị tạo lại mỗi lần rebuild
  final Map<String, GlobalKey> _bubbleKeys = {};

  void _cleanupBubbleKeys(Set<String> aliveIds) {
    _bubbleKeys.removeWhere((key, _) => !aliveIds.contains(key));
  }


  @override
  Widget build(BuildContext context) {
    final uid = Get.find<AuthController>().user!.uid;
    final theme = Theme.of(context);
    final controller = widget.controller;
    final roomId = widget.roomId;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("tempChats")
          .doc(roomId)
          .collection("messages")
          .orderBy("createdAt")
          .snapshots(),
      builder: (context, snap) {
        // Auto scroll khi có tin nhắn mới
        if (snap.hasData) {
          final docs = snap.data!.docs;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            controller.onNewMessages(
              docs.length,
              docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>(),
            );
          });
        }

        if (!snap.hasData) return const SizedBox();

        final docs = snap.data!.docs;

        final aliveIds = docs.map((e) => e.id).toSet();
        controller.cleanupMessageKeys(aliveIds);
        _cleanupBubbleKeys(aliveIds);

        return ListView.builder(
          controller: controller.scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: docs.length + 2,
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

          // ================= TYPING BUBBLE (CUỐI LIST) =================
          if (i == docs.length + 1) {
            return Obx(() {
              return MessengerTypingBubbleTemp(
                show: controller.otherTyping.value,
                controller: controller,
              );
            });
          }

          // ================= MESSAGE =================
          final index = i - 1;
          if (index < 0 || index >= docs.length) {
            return const SizedBox();
          }

          final doc = docs[index];
          final data = doc.data() as Map<String, dynamic>;
          final messageType = data["type"] ?? "text";


          // ================= SYSTEM MESSAGE =================
          if (messageType == "system") {
            final code = data["systemCode"];
            final senderId = data["senderId"];
            final targetUid = data["targetUid"];

            if (code == "like" && targetUid != uid) {
              return const SizedBox();
            }

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
          
          final key = controller.messageKeys.putIfAbsent(
            doc.id,
            () => GlobalKey(),
          );

          // ✅ Lưu bubbleKey để show reaction picker
          final bubbleKey = _bubbleKeys.putIfAbsent(
            doc.id,
            () => GlobalKey(),
          );

          double dragDx = 0;

          return Container(
            key: key,
            child: AnimatedMessageBubble(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      if (isMe) return;

                      dragDx += details.delta.dx;
                      dragDx = dragDx.clamp(0, 80);

                      setState(() {});
                    },
                    onHorizontalDragEnd: (_) {
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
                        // 🔄 ICON REPLY – TRƯỢT THEO TAY
                        Positioned(
                          left: 12 + dragDx * 0.5,
                          child: Opacity(
                            opacity: (dragDx / 40).clamp(0, 1),
                            child: Icon(
                              Icons.reply,
                              color: theme.colorScheme.primary,
                              size: 22,
                            ),
                          ),
                        ),

                        // 💬 BUBBLE – TRƯỢT + MỜ THEO LỰC
                        Transform.translate(
                          offset: Offset(dragDx, 0),
                          child: Opacity(
                            opacity: (1 - dragDx / 120).clamp(0.7, 1),
                            child: Obx(() {
                              final reactions = Map<String, String>.from(data["reactions"] ?? {});
                              
                              return ChatRow(
                                text: data["text"] ?? "",
                                type: messageType,
                                replyText: data["replyText"],
                                replyToId: data["replyToId"],
                                isMe: isMe,
                                showAvatar: showTime && !isMe,
                                smallMargin: grouped,
                                showTime: showTime,
                                time: _formatTime(data["createdAt"]),
                                onTapReply: data["replyToId"] != null
                                    ? () => controller.scrollToMessage(data["replyToId"])
                                    : null,
                                messageId: doc.id,
                                highlighted: controller.highlightedMessageId.value == doc.id,
                                anonymousAvatarKey: isMe? null: controller.otherAnonymousAvatar.value,
                                reactions: reactions.isNotEmpty ? reactions : null,
                                bubbleKey: bubbleKey,
                                // ❤️ DOUBLE TAP = LOVE
                                onDoubleTap: () {
                                  if (reactions[uid] == "love") return;
                                  controller.onReactMessage(
                                    messageId: doc.id,
                                    reactionId: "love",
                                  );
                                },
                                onLongPress: () {
                                  _showReactionPicker(
                                    context: context,
                                    controller: controller,
                                    messageId: doc.id,
                                    bubbleKey: bubbleKey,
                                    isMe: isMe,
                                  );
                                },
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
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

  // ✅ CÙNG NGƯỜI GỬI
  if (prev["senderId"] != curr["senderId"]) return false;

  final prevTime = _getTime(prev["createdAt"]);
  final currTime = _getTime(curr["createdAt"]);

  if (prevTime == null || currTime == null) return false;

  // ✅ < 2 PHÚT → GROUP
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

  void _showReactionPicker({
    required BuildContext context,
    required TempChatController controller,
    required String messageId,
    required GlobalKey bubbleKey,
    required bool isMe,
  }) {
    // Nếu đang mở → đóng cái cũ
    _reactionEntry?.remove();

    final box =
        bubbleKey.currentContext!.findRenderObject() as RenderBox;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;

    const pickerWidth = 270.0;
    const pickerHeight = 40.0;
    const verticalGap = 10.0;

    final left = isMe
        ? pos.dx + size.width - pickerWidth
        : pos.dx;

    final top = pos.dy - pickerHeight - verticalGap;

    _reactionEntry = OverlayEntry(
      builder: (_) => GestureDetector(
        behavior: HitTestBehavior.translucent, // 👈 BẮT BUỘC
        onTap: () {
          _reactionEntry?.remove();
          _reactionEntry = null;
        },
        child: Stack(
          children: [
            Positioned(
              left: left.clamp(
                8.0,
                MediaQuery.of(context).size.width - pickerWidth - 8,
              ),
              top: top,
              child: ReactionPicker(
                onSelect: (reactionId) {
                  controller.onReactMessage(
                    messageId: messageId,
                    reactionId: reactionId,
                  );
                  _reactionEntry?.remove();
                  _reactionEntry = null;
                },
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context).insert(_reactionEntry!);
  }

  @override
  void dispose() {
    _reactionEntry?.remove();
    super.dispose();
  }
}
