import 'package:flutter/material.dart';
import 'package:matchu_app/views/chat/temp_chat/anonymous_avatar.dart';
import 'package:matchu_app/theme/app_theme.dart';

class ChatRow extends StatelessWidget {
  final String text;
  final bool isMe;
  final bool showAvatar;
  final bool smallMargin;
  final bool showTime;
  final String time;
  final String? replyText;

  const ChatRow({
    super.key,
    required this.text,
    required this.isMe,
    required this.showAvatar,
    required this.smallMargin,
    required this.showTime,
    required this.time,
    this.replyText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bubbleColor =
        isMe ? theme.colorScheme.primary : Theme.of(context).brightness == Brightness.dark 
                                            ? theme.colorScheme.surface
                                            : Color.fromARGB(255, 244, 246, 248);
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * 0.65, // 👈 60%
                  ),
                  child: Column(
                    crossAxisAlignment:
                        isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ===== REPLY PREVIEW (TÁCH RIÊNG) =====
                      if (replyText != null)
                        Container(
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

                      // ===== MESSAGE BUBBLE (CHÍNH) =====
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: bubbleColor,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft:
                                isMe ? const Radius.circular(16) : const Radius.circular(4),
                            bottomRight:
                                isMe ? const Radius.circular(4) : const Radius.circular(16),
                          ),
                        ),
                        child: Text(
                          text,
                          softWrap: true,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: textColor,
                          ),
                        ),
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
