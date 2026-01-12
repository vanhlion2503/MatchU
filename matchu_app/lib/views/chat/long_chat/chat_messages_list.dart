import 'dart:ui';
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
import 'package:matchu_app/views/chat/long_chat/animate_bubble.dart';
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
  OverlayEntry? _actionsEntry;
  String? _activeReactionMessageId;

  void _dismissMessageActions({bool notify = true}) {
    _actionsEntry?.remove();
    _actionsEntry = null;

    if (_activeReactionMessageId == null) return;

    if (notify && mounted) {
      setState(() => _activeReactionMessageId = null);
    } else {
      _activeReactionMessageId = null;
    }
  }

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
          final pending = widget.controller.pendingImageMessages;
          final pendingCount = pending.length;
          
          if (docs.isEmpty && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // ✅ Đảm bảo itemCount hợp lệ
          // +1 cho typing slot, +1 cho loading indicator nếu đang load more
          final itemCount = docs.length + pendingCount + 1 + (widget.controller.isLoadingMore ? 1 : 0);

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

            if (pendingCount > 0 && i <= pendingCount) {
              final pendingItem = pending[i - 1];
              return _buildPendingImageBubble(context, pendingItem);
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
            final messageIndex = i - 1 - pendingCount;
            
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
            final messageType = data["type"] ?? "text";
            final viewedByRaw = data["viewedBy"];
            final viewedBy = viewedByRaw is Map
                ? Map<String, dynamic>.from(viewedByRaw)
                : <String, dynamic>{};
            final hasViewed = viewedBy.containsKey(uid);
            final isViewOnce = data["viewOnce"] == true;
            final isViewOnceImage = isViewOnce && messageType == "image";
            final imagePath = data["imagePath"] is String
                ? data["imagePath"] as String
                : "";
            final isMissingImage = isViewOnceImage && imagePath.isEmpty;
            final isConsumedByRecipient = isViewOnceImage &&
                hasViewed && data["senderId"] != uid;
            final effectiveType = (messageType == "deleted" ||
                    widget.controller.deletedMessageIds.contains(doc.id) ||
                    isConsumedByRecipient ||
                    isMissingImage)
                ? "deleted"
                : messageType;
            final isDeleted = effectiveType == "deleted";

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
                        "text": widget.controller.decryptedCache[doc.id] ?? "…",
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

                            final rawText = data["text"];
                            final fallbackText =
                                rawText is String ? rawText : "...";
                            final decryptedText =
                                widget.controller.decryptedCache[doc.id] ?? fallbackText;
                            final displayText = isDeleted
                                ? (isViewOnce
                                    ? ChatController.viewOnceDeletedText
                                    : (rawText is String && rawText.isNotEmpty
                                        ? rawText
                                        : decryptedText))
                                : decryptedText;
                            final isPressed = _activeReactionMessageId == doc.id;
                            final reactions = Map<String, String>.from(
                              data["reactions"] ?? {},
                            );
                            final canOpenImage =
                                isViewOnceImage && !isDeleted;

                            return ChatRowPermanent(
                              key: ValueKey(doc.id), // 🔥 BẮT BUỘC
                              messageId: doc.id,
                              senderId: data["senderId"],
                              text: displayText,
                              type: effectiveType,
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
                              isPressed: isPressed,
                              onTapReply: data["replyToId"] != null
                                  ? () => widget.controller.scrollToMessage(
                                        docs: docs,
                                        messageId: data["replyToId"],
                                      )
                                  : null,
                              onTapMessage: canOpenImage
                                  ? () => widget.controller.openViewOnceImage(
                                        messageId: doc.id,
                                        senderId: data["senderId"],
                                        imagePath: imagePath,
                                        isLatest: isNewestMessage,
                                      )
                                  : null,
                              reactions: isDeleted ? null : reactions,
                              bubbleKey: bubbleKey,
                              // ❤️ DOUBLE TAP = LOVE
                              onDoubleTap: () {
                                if (isDeleted) return;
                                if (reactions[uid] == "love") return;

                                widget.controller.onReactMessage(
                                  messageId: doc.id,
                                  reactionId: "love",
                                );
                              },
                              onLongPress: () {
                                _showMessageActions(
                                  context: context,
                                  controller: widget.controller,
                                  messageId: doc.id,
                                  messageText: decryptedText,
                                  bubbleKey: bubbleKey,
                                  isMe: isMe,
                                  messageType: messageType,
                                  isDeleted: isDeleted,
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

  Widget _buildPendingImageBubble(
    BuildContext context,
    PendingImageMessage pending,
  ) {
    final theme = Theme.of(context);
    final bubbleColor = theme.colorScheme.primary;
    final textColor = theme.colorScheme.onPrimary;

    return Obx(() {
      final progress = pending.progress.value;
      final failed = pending.failed.value;

      final label = failed ? "Gửi ảnh" : "Đang gửi ảnh...";

      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * 0.65,
                    ),
                    child: AnimatedBubble(
                      isMe: true,
                      highlighted: false,
                      pressed: false,
                      bubbleColor: bubbleColor,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.image_outlined,
                                size: 20,
                                color: textColor,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  label,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: textColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: failed
                                ? null
                                : (progress > 0 ? progress : null),
                            minHeight: 3,
                            backgroundColor: textColor.withOpacity(0.2),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(textColor),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    });
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

  void _showMessageActions({
    required BuildContext context,
    required ChatController controller,
    required String messageId,
    required String messageText,
    required GlobalKey bubbleKey,
    required bool isMe,
    required String messageType,
    required bool isDeleted,
  }) {
    if (!mounted) return;

    final canCopy =
        messageType == "text" && messageText.trim().isNotEmpty && !isDeleted;
    final canEdit = isMe && !isDeleted && messageType == "text";
    final canDelete = isMe && !isDeleted;
    final canReact = !isDeleted;

    if (!canCopy && !canEdit && !canDelete && !canReact) {
      return;
    }

    final bubbleContext = bubbleKey.currentContext;
    if (bubbleContext == null) return;

    _dismissMessageActions();
    setState(() => _activeReactionMessageId = messageId);

    final box = bubbleContext.findRenderObject() as RenderBox;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;

    final screenSize = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    final actions = <_MessageActionItem>[
      if (canCopy)
        _MessageActionItem(
          icon: Icons.copy,
          label: "Sao chép",
          onTap: () {
            _dismissMessageActions();
            Clipboard.setData(ClipboardData(text: messageText));
          },
        ),
      if (canEdit)
        _MessageActionItem(
          icon: Icons.edit,
          label: "Chỉnh sửa",
          onTap: () {
            _dismissMessageActions();
            controller.startEdit(
              messageId: messageId,
              text: messageText,
            );
          },
        ),
      if (canDelete)
        _MessageActionItem(
          icon: Icons.delete,
          label: "Xóa",
          color: Theme.of(context).colorScheme.error,
          onTap: () async {
            _dismissMessageActions();
            final confirmed = await _confirmDelete(context);
            if (!confirmed) return;
            await controller.deleteMessage(messageId: messageId);
          },
        ),
    ];

    const holePadding = 8.0;
    final holeRect = Rect.fromLTWH(
      pos.dx - holePadding,
      pos.dy - holePadding,
      size.width + holePadding * 2,
      size.height + holePadding * 2,
    );
    const holeRadius = 20.0;

    const pickerWidth = 270.0;
    const pickerHeight = 40.0;
    const verticalGap = 10.0;
    const actionWidth = 200.0;
    const actionRowHeight = 44.0;

    final actionHeight = actions.isEmpty
        ? 0.0
        : actions.length * actionRowHeight + 12.0;

    final pickerLeft = (isMe
            ? pos.dx + size.width - pickerWidth
            : pos.dx)
        .clamp(8.0, screenSize.width - pickerWidth - 8.0);

    double pickerTop = pos.dy - pickerHeight - verticalGap;
    final safeTop = padding.top + 8.0;
    if (pickerTop < safeTop) {
      pickerTop = safeTop;
    }

    final actionLeft = (isMe
            ? pos.dx + size.width - actionWidth
            : pos.dx)
        .clamp(8.0, screenSize.width - actionWidth - 8.0);

    double actionsTop = pos.dy + size.height + verticalGap;
    final safeBottom = padding.bottom + 8.0;
    final maxActionsTop = screenSize.height - safeBottom - actionHeight;
    if (actionsTop > maxActionsTop) {
      actionsTop = maxActionsTop;
    }
    if (actionsTop < safeTop) {
      actionsTop = safeTop;
    }

    final minActionsTop = pickerTop + pickerHeight + 8.0;
    if (actionsTop < minActionsTop &&
        minActionsTop + actionHeight <= screenSize.height - safeBottom) {
      actionsTop = minActionsTop;
    }

    _actionsEntry = OverlayEntry(
      builder: (_) => Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _dismissMessageActions,
                child: ClipPath(
                  clipper: _HoleClipper(
                    holeRect: holeRect,
                    radius: holeRadius,
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: Container(
                      color: Colors.black.withOpacity(0.25),
                    ),
                  ),
                ),
              ),
            ),
            if (canReact)
              Positioned(
                left: pickerLeft,
                top: pickerTop,
                child: ReactionPicker(
                  onSelect: (reactionId) {
                    controller.onReactMessage(
                      messageId: messageId,
                      reactionId: reactionId,
                    );
                    _dismissMessageActions();
                  },
                ),
              ),
            if (actions.isNotEmpty)
              Positioned(
                left: actionLeft,
                top: actionsTop,
                child: SizedBox(
                  width: actionWidth,
                  child: _MessageActionList(actions: actions),
                ),
              ),
          ],
        ),
      ),
    );

    final overlay = Overlay.of(context);
    if (overlay == null) return;
    overlay.insert(_actionsEntry!);
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Xóa tin nhắn?"),
          content: const Text("Bạn có chắc muốn xóa tin nhắn này?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text("Hủy"),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text("Xóa"),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  @override
  void dispose() {
    _dismissMessageActions(notify: false);
    super.dispose();
  }


}

class _MessageActionItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _MessageActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
}

class _MessageActionList extends StatelessWidget {
  final List<_MessageActionItem> actions;

  const _MessageActionList({
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              blurRadius: 12,
              color: Colors.black.withOpacity(0.2),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(actions.length, (index) {
            final action = actions[index];
            final resolvedColor = action.color ?? theme.colorScheme.onSurface;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: action.onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(action.icon, size: 20, color: resolvedColor),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            action.label,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: resolvedColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (index != actions.length - 1)
                  Divider(
                    height: 1,
                    thickness: 0.6,
                    color: theme.dividerColor.withOpacity(0.4),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _HoleClipper extends CustomClipper<Path> {
  final Rect holeRect;
  final double radius;

  const _HoleClipper({
    required this.holeRect,
    required this.radius,
  });

  @override
  Path getClip(Size size) {
    final path = Path()..fillType = PathFillType.evenOdd;
    path.addRect(Offset.zero & size);
    path.addRRect(
      RRect.fromRectAndRadius(
        holeRect,
        Radius.circular(radius),
      ),
    );
    return path;
  }

  @override
  bool shouldReclip(_HoleClipper oldClipper) {
    return oldClipper.holeRect != holeRect ||
        oldClipper.radius != radius;
  }
}
