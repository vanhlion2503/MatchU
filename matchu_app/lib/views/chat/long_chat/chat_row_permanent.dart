import 'package:flutter/material.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/utils/reaction_registry.dart';
import 'package:matchu_app/views/chat/chat_widget/user_avatar.dart';
import 'package:matchu_app/views/chat/long_chat/animate_bubble.dart';
import 'package:matchu_app/views/chat/long_chat/animate_emoji.dart';
import 'package:matchu_app/models/message_status.dart';
import 'package:matchu_app/views/chat/long_chat/seen_avatar_animated.dart';

class ChatRowPermanent extends StatelessWidget {
  final String messageId;
  final String senderId;

  final String text;
  final String type;

  final bool isMe;
  final bool showAvatar;   // chỉ true ở tin CUỐI nhóm
  final bool smallMargin;
  final bool showTime;
  final String time;

  final String? replyText;
  final String? replyToId;
  final VoidCallback? onTapReply;

  final bool highlighted;

  final MessageStatus? status;
  final String? seenByUid;

  final Map<String, String>? reactions;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;

  final GlobalKey bubbleKey;

  const ChatRowPermanent({
    super.key,
    required this.messageId,
    required this.senderId,
    required this.text,
    required this.type,
    required this.isMe,
    required this.showAvatar,
    required this.smallMargin,
    required this.showTime,
    required this.time,
    required this.bubbleKey,
    this.replyText,
    this.replyToId,
    this.onTapReply,
    this.highlighted = false,
    this.status,
    this.seenByUid,
    this.reactions,
    this.onLongPress,
    this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bubbleColor = isMe
        ? theme.colorScheme.primary
        : theme.brightness == Brightness.dark
            ? AppTheme.darkBorder
            : const Color(0xFFF4F6F8);

    final textColor =
        isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;

    // ================= EMOJI ONLY =================
    final isEmojiOnly = _isEmojiOnly(text);

    if (isEmojiOnly) {
      return Padding(
        padding: EdgeInsets.only(top: smallMargin ? 2 : 10),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe)
              SizedBox(
                width: 36,
                child: showAvatar
                    ? UserAvatar(userId: senderId)
                    : const SizedBox(),
              ),
            if (!isMe) const SizedBox(width: 6),

            AnimatedEmoji(
              text: text,
              highlighted: highlighted,
              isMe: isMe,
            ),
          ],
        ),
      );
    }


    // ================= TEXT MESSAGE =================
    return Padding(
      padding: EdgeInsets.only(top: smallMargin ? 6 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          /// ================= AVATAR =================
          if (!isMe)
            SizedBox(
              width: 36,
              child: showAvatar
                  ? UserAvatar(userId: senderId)
                  : const SizedBox(),
            ),

          if (!isMe) const SizedBox(width: 6),

          /// ================= MESSAGE =================
          Flexible(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * 0.65,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ===== REPLY PREVIEW =====
                      if (replyText != null && replyToId != null)
                        GestureDetector(
                          onTap: onTapReply,
                          child: Container(
                            // margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: theme.brightness == Brightness.dark
                                  ? const Color.fromARGB(255, 77, 76, 76)
                                  : const Color(0xFFF4F6F8)
                                      .withOpacity(0.8),
                              borderRadius: BorderRadius.circular(10),
                              border: Border(
                                left: BorderSide(
                                  color: theme.colorScheme.primary,
                                  width: 4,
                                ),
                              ),
                            ),
                            child: Text(
                              replyText!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ),

                      // ===== MESSAGE BUBBLE =====
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          GestureDetector(
                            onLongPress: onLongPress,
                            onDoubleTap: onDoubleTap,
                            child: Container(
                              key: bubbleKey,
                              child: AnimatedBubble(
                                isMe: isMe,
                                highlighted: highlighted,
                                bubbleColor: bubbleColor,
                                child: Text(
                                  text,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: textColor,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          if (reactions != null && reactions!.isNotEmpty)
                            Positioned(
                              bottom: -10,
                              right: isMe ? -6 : null,
                              left: isMe ? null : -6,
                              child: _MessengerReactionBadge(
                                reactions: reactions!,
                                isMe: isMe,
                              ),
                            ),
                        ],
                      ),

                      SizedBox(height: 3),
                      // ===== TIME
                      if (showTime && time.isNotEmpty)
                      Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            time,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ),

                      // ===== TIME + STATUS ROW =====
                      if (isMe && status != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // ===== SEEN / SENT =====
                              if (status == MessageStatus.seen)
                                SeenAvatarAnimated(
                                  userId: seenByUid,
                                  size: 14,
                                )
                              else if (status == MessageStatus.sent)
                                Text(
                                  "Đã gửi",
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                            ],
                          ),
                        ),


                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

bool _isEmojiOnly(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return false;

  final emojiRegex = RegExp(
    r'^(?:\p{Emoji_Presentation}|\p{Extended_Pictographic})+$',
    unicode: true,
  );

  return emojiRegex.hasMatch(trimmed);
}

Map<String, int> _groupReactions(Map<String, String> reactions) {
  final Map<String, int> result = {};
  for (final id in reactions.values) {
    result[id] = (result[id] ?? 0) + 1;
  }
  return result;
}


class _MessengerReactionBadge extends StatelessWidget {
  final Map<String, String> reactions;
  final bool isMe;

  const _MessengerReactionBadge({
    required this.reactions,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final grouped = _groupReactions(reactions);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: grouped.entries.map((e) {
        final reaction = ReactionRegistry.get(e.key);
        if (reaction == null) return const SizedBox();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  blurRadius: 4,
                  color: Colors.black.withOpacity(0.15),
                )
              ],
            ),
            child: Row(
              children: [
                reaction.icon,
                if (e.value > 1) ...[
                  const SizedBox(width: 2),
                  Text(
                    e.value.toString(),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}


