import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/feed/post_comments_controller.dart';
import 'package:matchu_app/views/feed/widgets/feed_palette.dart';
import 'package:matchu_app/views/feed/widgets/post_ui_helpers.dart';
import 'package:matchu_app/widgets/verified_name_row.dart';

class PostDetailCommentItem extends StatelessWidget {
  const PostDetailCommentItem({
    super.key,
    required this.entry,
    required this.onReplyTap,
  });

  final CommentThreadEntry entry;
  final VoidCallback onReplyTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = FeedPalette.of(context);
    final comment = entry.comment;
    final author = comment.author;
    final isReply = entry.depth > 0;
    final displayName = author?.displayName ?? 'Nguoi dung';
    final depth = math.min(entry.depth, 4);
    final leftInset = isReply ? 28.0 + (depth * 18.0) : 16.0;
    final avatarSize = isReply ? 34.0 : 38.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(leftInset, isReply ? 10 : 14, 16, 14),
      child: DecoratedBox(
        decoration:
            isReply
                ? BoxDecoration(
                  border: Border(
                    left: BorderSide(color: palette.threadLine, width: 1.1),
                  ),
                )
                : const BoxDecoration(),
        child: Padding(
          padding: EdgeInsets.only(left: isReply ? 12 : 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: avatarSize,
                child: Column(
                  children: [
                    FeedAvatar(
                      imageUrl: author?.avatarUrl ?? '',
                      fallbackLabel: displayName,
                      size: avatarSize,
                      borderColor: palette.border,
                    ),
                    if (!isReply && comment.replyCount > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: 1.1,
                        height: 30,
                        color: palette.threadLine,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: VerifiedNameRow(
                                  isVerified: author?.isVerified == true,
                                  badgeSize: 14,
                                  badgePadding: const EdgeInsets.only(left: 4),
                                  child: Text(
                                    displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: palette.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  formatRelativeTime(
                                    comment.createdAt,
                                    compact: true,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: palette.textTertiary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Icon(
                            Iconsax.more,
                            size: 18,
                            color: palette.iconMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      comment.content,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        height: 1.55,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _CommentMetaButton(
                          icon: Iconsax.heart,
                          label:
                              comment.likeCount > 0
                                  ? formatCompactCount(comment.likeCount)
                                  : null,
                          palette: palette,
                        ),
                        _CommentMetaButton(
                          icon: Iconsax.message_text,
                          label: isReply ? null : 'Tra loi',
                          palette: palette,
                          onTap: onReplyTap,
                          iconColor: theme.colorScheme.primary,
                          labelColor: theme.colorScheme.primary,
                        ),
                        if (comment.replyCount > 0 && !isReply)
                          Text(
                            '${comment.replyCount} phan hoi',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentMetaButton extends StatelessWidget {
  const _CommentMetaButton({
    required this.icon,
    required this.palette,
    this.label,
    this.onTap,
    this.iconColor,
    this.labelColor,
  });

  final IconData icon;
  final FeedPalette palette;
  final String? label;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: iconColor ?? palette.iconMuted),
        if (label != null) ...[
          const SizedBox(width: 5),
          Text(
            label!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: labelColor ?? palette.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: content,
        ),
      ),
    );
  }
}
