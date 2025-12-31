import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/utils/format_date_lable.dart';
import 'package:matchu_app/views/chat/chat_widget/reaction_picker.dart';
import 'package:matchu_app/views/chat/long_chat/date_separator.dart';
import 'package:matchu_app/views/chat/long_chat/messenger_typing_bubble.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/controllers/chat/chat_controller.dart';
import 'package:matchu_app/views/chat/long_chat/chat_row_permanent.dart';
import 'package:matchu_app/views/chat/temp_chat/animate_message_bubble.dart';
import 'package:matchu_app/models/message_status.dart';


class ChatMessagesList extends StatefulWidget {
  final ChatController controller;
  const ChatMessagesList({super.key, required this.controller});

  @override
  State<ChatMessagesList> createState() => _ChatMessagesListState();
}

class _ChatMessagesListState extends State<ChatMessagesList> {
  // ✅ Lưu bubbleKeys để không bị tạo lại mỗi lần rebuild
  final Map<String, GlobalKey> _bubbleKeys = {};
  OverlayEntry? _reactionEntry;

  @override
  Widget build(BuildContext context) {
    final uid = Get.find<AuthController>().user!.uid;
    final theme = Theme.of(context);

    final bottomPadding =
        widget.controller.bottomBarHeight.value +
        MediaQuery.of(context).padding.bottom;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.controller.listenMessages(),
      builder: (context, snap) {
        // Listen stream để detect messages mới
        if (snap.connectionState == ConnectionState.active && snap.hasData) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            widget.controller.onNewMessages(
              snap.data!.docs.length,
              snap.data!.docs,
            );
          });
        }

        
        // Sử dụng allMessages từ controller
        return Obx(() {
          final docs = widget.controller.allMessages;
          
          if (docs.isEmpty && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // ✅ Đảm bảo itemCount hợp lệ
          // +1 cho typing slot, +1 cho loading indicator nếu đang load more
          final itemCount = docs.length + 1 + (widget.controller.isLoadingMore ? 1 : 0);

          return ScrollablePositionedList.builder(
            reverse: true, // ✅ Tin mới ở index 0, hiển thị ở đáy
            itemScrollController: widget.controller.itemScrollController,
            itemPositionsListener: widget.controller.itemPositionsListener,
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
                final otherUid = widget.controller.otherUid.value;
                if (otherUid == null) return const SizedBox();

                return MessengerTypingBubble(
                  show: widget.controller.otherTyping.value,
                  senderId: otherUid,
                );
              });
            }

            /// ================= LOADING INDICATOR (Ở ĐẦU - index cao nhất) =================
            if (widget.controller.isLoadingMore && i == itemCount - 1) {
              return Obx(() {
                if (!widget.controller.isLoadingMore) return const SizedBox();
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
            final createdAt = _getTime(data["createdAt"]);
            final isNewestMessage = messageIndex == 0;

            // ✅ Lưu bubbleKey để không bị tạo lại mỗi lần rebuild
            final bubbleKey = _bubbleKeys.putIfAbsent(
              doc.id,
              () => GlobalKey(),
            );

            double dragDx = 0;

            final bubbleContent = StatefulBuilder(
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
                      widget.controller.startReply({
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
                            Iconsax.rotate_right,
                            color: theme.colorScheme.primary,
                            size: 26,
                          ),
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(dragDx, 0),
                        child: Opacity(
                          opacity: (1 - dragDx / 120).clamp(0.7, 1),
                          child: Obx(() {
                            final unread = widget.controller.otherUnread.value;
                            final otherUid = widget.controller.otherUid.value;
                            final isMyLastMessage = isMe && messageIndex == 0;
                            return ChatRowPermanent(
                              key: ValueKey(doc.id), // 🔥 BẮT BUỘC
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
                              smallMargin: _shouldGroup(docs, messageIndex),
                              showTime: isLastInGroup && messageIndex != 0,
                              time: _formatTime(data["createdAt"]),
                              replyText: data["replyText"],
                              replyToId: data["replyToId"],
                              highlighted:
                                  widget.controller.highlightedMessageId.value == doc.id,
                              onTapReply: data["replyToId"] != null
                                  ? () => widget.controller.scrollToMessage(
                                        docs: docs,
                                        messageId: data["replyToId"],
                                      )
                                  : null,
                              reactions: Map<String, String>.from(data["reactions"] ?? {}),
                              bubbleKey: bubbleKey,
                              // ❤️ DOUBLE TAP = LOVE
                              onDoubleTap: () {
                                final reactions = Map<String, String>.from(
                                  data["reactions"] ?? {},
                                );
                                if (reactions[uid] == "love") return;

                                  widget.controller.onReactMessage(
                                    messageId: doc.id,
                                    reactionId: "love",
                                  );
                              },
                              onLongPress: () {
                                _showReactionPicker(
                                  context: context,
                                  controller: widget.controller,
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
            );
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (createdAt != null &&
                    _shouldShowDateSeparator(docs, messageIndex))
                  DateSeparator(
                    text: formatDateLabel(createdAt),
                  ),

                isNewestMessage
                    ? AnimatedMessageBubble(child: bubbleContent)
                    : bubbleContent,
              ],
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

  bool _shouldShowDateSeparator(
    List<QueryDocumentSnapshot> docs,
    int index,
  ) {
    // index là messageIndex (0 → mới nhất)
    if (index == docs.length - 1) return true; // tin cũ nhất → luôn show

    final curr = _getTime(docs[index]["createdAt"]);
    final next = _getTime(docs[index + 1]["createdAt"]); // tin cũ hơn

    if (curr == null || next == null) return false;

    return curr.year != next.year ||
          curr.month != next.month ||
          curr.day != next.day;
  }

  void _showReactionPicker({
    required BuildContext context,
    required ChatController controller,
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


}
