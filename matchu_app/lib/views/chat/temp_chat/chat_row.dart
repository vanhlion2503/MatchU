import 'package:flutter/material.dart';
import 'package:matchu_app/views/chat/temp_chat/anonymous_avatar.dart';
import 'package:matchu_app/views/chat/long_chat/animate_emoji.dart';
import 'package:matchu_app/utils/reaction_registry.dart';

class ChatRow extends StatelessWidget {
  final String text;
  final bool isMe;
  final bool showAvatar;
  final bool smallMargin;
  final bool showTime;
  final String time;
  final String? replyText;
  final String? replyToId;
  final VoidCallback? onTapReply;
  final String messageId;
  final bool highlighted;
  final String type;
  final String? anonymousAvatarKey;
  final Map<String, String>? reactions;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;
  final GlobalKey? bubbleKey;

  const ChatRow({
    super.key,
    required this.text,
    required this.isMe,
    required this.showAvatar,
    required this.smallMargin,
    required this.showTime,
    required this.time,
    this.replyToId,
    this.replyText,
    this.onTapReply,
    required this.messageId,
    required this.highlighted,
    required this.type,
    this.anonymousAvatarKey,
    this.reactions,
    this.onLongPress,
    this.onDoubleTap,
    this.bubbleKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bubbleColor =
        isMe ? theme.colorScheme.primary : Theme.of(context).brightness == Brightness.dark 
                                            ? theme.colorScheme.surface
                                            : Color.fromARGB(255, 244, 246, 248);
    final textColor = isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;
      
    // ================= EMOJI ONLY =================
    if (type == "emoji") {
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
                child: showAvatar ? AnonymousAvatar(avatarKey: anonymousAvatarKey, radius: 16,): const SizedBox(),
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


    // ================= TEXT MESSAGE=================

    return Padding(
      padding: EdgeInsets.only(top: smallMargin ? 2 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe)
            SizedBox(
              width: 36,
              child: showAvatar ? AnonymousAvatar(avatarKey: anonymousAvatarKey, radius: 16,) : const SizedBox(),
            ),
          const SizedBox(width: 6),
          Flexible(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * 0.65, // 👈 60%
                  ),
                  child: Column(
                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      
                      // ===== REPLY PREVIEW (TÁCH RIÊNG) =====
                      if (replyText != null && replyToId != null)
                        GestureDetector(
                          onTap: onTapReply,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark 
                                              ? theme.colorScheme.surface
                                              : Color.fromARGB(255, 244, 246, 248).withOpacity(0.8),
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

                      // ===== MESSAGE BUBBLE (CHÍNH) =====
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          GestureDetector(
                            onLongPress: onLongPress,
                            onDoubleTap: onDoubleTap,
                            child: Container(
                              key: bubbleKey,
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(
                                  begin: 0,
                                  end: highlighted ? 1 : 0,
                                ),
                                duration: const Duration(milliseconds: 420),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, child) {
                                  // 🔥 rung rất nhẹ ±2px
                                  final shake = highlighted
                                      ? (value < 0.5 ? value : (1 - value)) * 4
                                      : 0;

                                  return Transform.translate(
                                    offset: Offset(shake * (isMe ? -1 : 1), 0),
                                    child: AnimatedScale(
                                      scale: highlighted ? 1.04 : 1.0,
                                      duration: const Duration(milliseconds: 220),
                                      curve: Curves.easeOutBack,
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 320),
                                        curve: Curves.easeOutCubic,
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: bubbleColor, // ✅ KHÔNG đổi màu
                                          borderRadius: BorderRadius.only(
                                            topLeft: const Radius.circular(16),
                                            topRight: const Radius.circular(16),
                                            bottomLeft:
                                                isMe ? const Radius.circular(16) : const Radius.circular(4),
                                            bottomRight:
                                                isMe ? const Radius.circular(4) : const Radius.circular(16),
                                          ),
                                          boxShadow: highlighted
                                              ? [
                                                  BoxShadow(
                                                    color: Colors.black.withOpacity(0.14),
                                                    blurRadius: 18,
                                                    offset: const Offset(0, 6),
                                                  ),
                                                ]
                                              : [],
                                        ),
                                        child: child,
                                      ),
                                    ),
                                  );
                                },
                                child: Text(
                                  text,
                                  softWrap: true,
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


                      // ===== TIME =====
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
