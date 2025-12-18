import 'package:flutter/material.dart';
import 'package:matchu_app/views/chat/temp_chat/anonymous_avatar.dart';

class ChatRow extends StatelessWidget {
  final String text;
  final bool isMe;
  final bool showAvatar;
  final bool smallMargin;
  final bool showTime;
  final String time;

  const ChatRow({
    super.key,
    required this.text,
    required this.isMe,
    required this.showAvatar,
    required this.smallMargin,
    required this.showTime,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bubbleColor =
        isMe ? theme.colorScheme.primary : theme.colorScheme.surface;
    final textColor =
        isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;

    return Padding(
      padding: EdgeInsets.only(top: smallMargin ? 2 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe)
            SizedBox(
              width: 36,
              child:
                  showAvatar ? const AnonymousAvatar() : const SizedBox(),
            ),
            const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isMe
                          ? const Radius.circular(16)
                          : const Radius.circular(4),
                      bottomRight: isMe
                          ? const Radius.circular(4)
                          : const Radius.circular(16),
                    ),
                  ),
                  child: Text(
                    text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: textColor,
                    ),
                  ),
                ),

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
          ),
        ],
      ),
    );
  }
}
