import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/feed/post_comments_controller.dart';
import 'package:matchu_app/views/feed/widgets/comment_thread_guides.dart';
import 'package:matchu_app/views/feed/widgets/feed_palette.dart';
import 'package:matchu_app/views/feed/widgets/post_ui_helpers.dart';
import 'package:matchu_app/widgets/verified_name_row.dart';

class PostDetailCommentItem extends StatelessWidget {
  const PostDetailCommentItem({
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
    final theme = Theme.of(context);
    final palette = FeedPalette.of(context);
    final comment = entry.comment;
    final author = comment.author;
    final isReply = entry.depth > 0;
    final displayName = author?.displayName ?? 'Người dùng';
    final depth = math.min(entry.depth, 4);
    final topPadding = isReply ? 10.0 : 14.0;
    const bottomPadding = 14.0;
    final lineInsets = <double>[
      35.0,
      for (var level = 1; level <= 4; level++) 45.0 + (level * 18.0),
    ];
    final leftInset = isReply ? lineInsets[depth - 1] + 11.0 : 16.0;
    final avatarSize = isReply ? 34.0 : 38.0;
    final horizontalLineEndX =
        isReply ? leftInset - 2.0 : leftInset + avatarSize + 6.0;
    final ancestorBranchContinues =
        entry.ancestorBranchContinues.take(math.max(depth - 1, 0)).toList();
    final canToggleReplies = comment.replyCount > 0 && !isReplyLoading;

    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: CommentThreadGuides(
        depth: depth,
        ancestorBranchContinues: ancestorBranchContinues,
        hasNextSibling: entry.hasNextSibling,
        hasChildren: entry.hasChildren && entry.isExpanded,
        contentLeft: leftInset,
        avatarCenterY: avatarSize / 2,
        lineInsets: lineInsets,
        horizontalLineEndX: horizontalLineEndX,
        topPadding: topPadding,
        bottomPadding: bottomPadding,
        color: palette.threadLine,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: avatarSize,
              child: FeedAvatar(
                imageUrl: author?.avatarUrl ?? '',
                fallbackLabel: displayName,
                size: avatarSize,
                borderColor: palette.border,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: canToggleReplies ? onToggleRepliesTap : null,
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _CommentMetaButton(
                              icon:
                                  comment.isLiked
                                      ? Iconsax.heart5
                                      : Iconsax.heart,
                              label:
                                  comment.likeCount > 0
                                      ? formatCompactCount(comment.likeCount)
                                      : null,
                              palette: palette,
                              iconColor:
                                  comment.isLiked
                                      ? palette.likeColor.withValues(
                                        alpha: comment.isLikePending ? 0.58 : 1,
                                      )
                                      : palette.iconMuted.withValues(
                                        alpha: comment.isLikePending ? 0.58 : 1,
                                      ),
                              labelColor:
                                  comment.isLiked
                                      ? palette.likeColor.withValues(
                                        alpha: comment.isLikePending ? 0.58 : 1,
                                      )
                                      : null,
                              onTap: onLikeTap,
                            ),
                            _CommentMetaButton(
                              icon: Iconsax.message_text,
                              label:
                                  comment.replyCount > 0
                                      ? formatCompactCount(comment.replyCount)
                                      : null,
                              palette: palette,
                              onTap: onReplyTap,
                            ),
                          ],
                        ),
                        if (comment.replyCount > 0) ...[
                          const SizedBox(height: 8),
                          _CommentMetaButton(
                            icon:
                                isReplyLoading
                                    ? null
                                    : entry.isExpanded
                                    ? Iconsax.arrow_up_1
                                    : Iconsax.arrow_down_1,
                            label:
                                isReplyLoading
                                    ? 'Đang tải phản hồi...'
                                    : entry.isExpanded
                                    ? 'Ẩn ${comment.replyCount} phản hồi'
                                    : '${comment.replyCount} phản hồi',
                            palette: palette,
                            isLoading: isReplyLoading,
                            onTap: canToggleReplies ? onToggleRepliesTap : null,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentMetaButton extends StatelessWidget {
  const _CommentMetaButton({
    required this.palette,
    this.icon,
    this.iconColor,
    this.labelColor,
    this.label,
    this.onTap,
    this.isLoading = false,
  });

  final IconData? icon;
  final FeedPalette palette;
  final Color? iconColor;
  final Color? labelColor;
  final String? label;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              color: palette.iconPrimary,
            ),
          )
        else if (icon != null)
          Icon(icon, size: 18, color: iconColor ?? palette.iconMuted),
        if (label != null) ...[
          if (icon != null || isLoading) const SizedBox(width: 5),
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
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: content,
        ),
      ),
    );
  }
}
