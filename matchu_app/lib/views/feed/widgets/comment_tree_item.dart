import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:matchu_app/controllers/feed/post_comments_controller.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/feed/widgets/comment_thread_guides.dart';

class CommentTreeItem extends StatelessWidget {
  const CommentTreeItem({
    super.key,
    required this.entry,
    required this.onReplyTap,
  });

  final CommentThreadEntry entry;
  final VoidCallback onReplyTap;

  @override
  Widget build(BuildContext context) {
    final comment = entry.comment;
    final author = comment.author;
    final theme = Theme.of(context);
    final depth = math.min(entry.depth, 4);
    final indent = depth * 18.0;
    final ancestorBranchContinues =
        entry.ancestorBranchContinues.take(math.max(depth - 1, 0)).toList();
    final avatarUrl = author?.avatarUrl ?? '';
    final displayName = author?.displayName ?? 'Người dùng';
    final nickname = author?.nickname ?? '';

    return CommentThreadGuides(
      depth: depth,
      ancestorBranchContinues: ancestorBranchContinues,
      hasNextSibling: entry.hasNextSibling,
      hasChildren: entry.hasChildren,
      contentLeft: indent,
      avatarCenterY: 18,
      rootLineInset: 18,
      branchSpacing: 18,
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
                      _initialOf(displayName),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    )
                    : null,
          ),
          const SizedBox(width: 10),
          Expanded(
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
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
                            nickname.isNotEmpty
                                ? '@$nickname • ${_formatRelativeTime(comment.createdAt)}'
                                : _formatRelativeTime(comment.createdAt),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    comment.content,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      GestureDetector(
                        onTap: onReplyTap,
                        child: Text(
                          'Trả lời',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (comment.replyCount > 0)
                        Text(
                          '${comment.replyCount} phản hồi',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatRelativeTime(DateTime? dateTime) {
  if (dateTime == null) return 'Vừa xong';

  final now = DateTime.now();
  final diff = now.difference(dateTime);

  if (diff.inSeconds < 60) return 'Vừa xong';
  if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
  if (diff.inHours < 24) return '${diff.inHours} giờ trước';
  if (diff.inDays < 7) return '${diff.inDays} ngày trước';

  final day = dateTime.day.toString().padLeft(2, '0');
  final month = dateTime.month.toString().padLeft(2, '0');
  return '$day/$month/${dateTime.year}';
}

String _initialOf(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '?';
  return String.fromCharCode(trimmed.runes.first).toUpperCase();
}
