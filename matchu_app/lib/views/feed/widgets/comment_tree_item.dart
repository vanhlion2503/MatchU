import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/feed/post_comments_controller.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/feed/widgets/comment_thread_guides.dart';
import 'package:matchu_app/views/feed/widgets/post_ui_helpers.dart';

class CommentTreeItem extends StatelessWidget {
  const CommentTreeItem({
    super.key,
    required this.entry,
    required this.onLikeTap,
    required this.onReplyTap,
    required this.onToggleRepliesTap,
    this.isReplyLoading = false,
  });

  final CommentThreadEntry entry;
  final VoidCallback onLikeTap;
  final VoidCallback onReplyTap;
  final VoidCallback onToggleRepliesTap;
  final bool isReplyLoading;

  @override
  Widget build(BuildContext context) {
    final comment = entry.comment;
    final author = comment.author;
    final theme = Theme.of(context);
    final depth = math.min(entry.depth, 4);
    final ancestorBranchContinues =
        entry.ancestorBranchContinues.take(math.max(depth - 1, 0)).toList();
    final avatarUrl = author?.avatarUrl ?? '';
    final displayName = author?.displayName ?? 'Người dùng';
    final nickname = author?.nickname ?? '';
    final lineInsets = <double>[
      18.0,
      for (var level = 1; level <= 4; level++) 28.0 + (level * 18.0),
    ];
    final indent = depth == 0 ? 0.0 : lineInsets[depth - 1] + 10.0;
    final horizontalLineEndX = depth == 0 ? indent + 42.0 : indent - 2.0;
    final likeColor =
        comment.isLiked
            ? theme.colorScheme.primary.withValues(
              alpha: comment.isLikePending ? 0.58 : 1,
            )
            : null;
    final isSending = comment.isSending;
    final canToggleReplies =
        comment.replyCount > 0 && !isReplyLoading && !isSending;
    final timeLabel =
        isSending
            ? 'Đang gửi...'
            : formatRelativeTime(comment.createdAt, withSuffix: true);
    final subtitleLabel =
        nickname.isNotEmpty ? '@$nickname - $timeLabel' : timeLabel;

    return CommentThreadGuides(
      depth: depth,
      ancestorBranchContinues: ancestorBranchContinues,
      hasNextSibling: entry.hasNextSibling,
      hasChildren: entry.hasChildren && entry.isExpanded,
      contentLeft: indent,
      avatarCenterY: 18,
      lineInsets: lineInsets,
      horizontalLineEndX: horizontalLineEndX,
      color:
          theme.brightness == Brightness.dark
              ? AppTheme.darkBorder
              : AppTheme.lightBorder,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage:
                avatarUrl.isNotEmpty
                    ? CachedNetworkImageProvider(avatarUrl)
                    : null,
            child:
                avatarUrl.isEmpty
                    ? Text(
                      initialOf(displayName),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    )
                    : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: canToggleReplies ? onToggleRepliesTap : null,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color:
                        theme.brightness == Brightness.dark
                            ? AppTheme.darkBorder
                            : AppTheme.lightBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitleLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            isSending
                                ? theme.colorScheme.primary.withValues(
                                  alpha: 0.9,
                                )
                                : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      comment.content,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 14,
                          runSpacing: 6,
                          children: [
                            _CommentActionChip(
                              icon:
                                  comment.isLiked
                                      ? Iconsax.heart5
                                      : Iconsax.heart,
                              label:
                                  comment.likeCount > 0
                                      ? formatCompactCount(comment.likeCount)
                                      : null,
                              color: likeColor,
                              onTap: isSending ? null : onLikeTap,
                            ),
                            _CommentActionChip(
                              icon: Iconsax.message_text,
                              label:
                                  comment.replyCount > 0
                                      ? formatCompactCount(comment.replyCount)
                                      : 'Trả lời',
                              color: theme.colorScheme.primary,
                              onTap: isSending ? null : onReplyTap,
                            ),
                          ],
                        ),
                        if (comment.replyCount > 0) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: canToggleReplies ? onToggleRepliesTap : null,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isReplyLoading)
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.8,
                                      color: theme.colorScheme.primary,
                                    ),
                                  )
                                else
                                  Icon(
                                    entry.isExpanded
                                        ? Iconsax.arrow_up_1
                                        : Iconsax.arrow_down_1,
                                    size: 14,
                                    color: theme.textTheme.bodySmall?.color,
                                  ),
                                const SizedBox(width: 4),
                                Text(
                                  isReplyLoading
                                      ? 'Đang tải phản hồi...'
                                      : entry.isExpanded
                                      ? 'Ẩn ${comment.replyCount} phản hồi'
                                      : '${comment.replyCount} phản hồi',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentActionChip extends StatelessWidget {
  const _CommentActionChip({
    required this.icon,
    this.label,
    this.color,
    this.onTap,
  });

  final IconData icon;
  final String? label;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foregroundColor = color ?? theme.textTheme.bodySmall?.color;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: foregroundColor),
        if (label != null) ...[
          const SizedBox(width: 5),
          Text(
            label!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );

    if (onTap == null) return content;

    return GestureDetector(onTap: onTap, child: content);
  }
}
