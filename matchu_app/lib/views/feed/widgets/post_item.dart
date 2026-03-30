import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/views/feed/widgets/feed_palette.dart';
import 'package:matchu_app/views/feed/widgets/post_media_gallery.dart';

class PostItem extends StatelessWidget {
  const PostItem({
    super.key,
    required this.post,
    required this.onLikeTap,
    required this.onCommentTap,
    required this.onShareTap,
    required this.onMoreTap,
  });

  final PostModel post;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;
  final VoidCallback onShareTap;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = FeedPalette.of(context);
    final authorName = _authorName(post);
    final authorHandle = _authorHandle(post);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onCommentTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PostRail(post: post),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PostHeader(post: post, onMoreTap: onMoreTap),
                    if (authorHandle.isNotEmpty &&
                        authorHandle.toLowerCase() !=
                            authorName.toLowerCase()) ...[
                      Text(
                        '@$authorHandle',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (post.hasContent) ...[
                      const SizedBox(height: 8),
                      Text(
                        post.content,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          height: 1.55,
                          color: palette.textPrimary,
                        ),
                      ),
                    ],
                    if (post.tags.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        children: post.tags
                            .map(
                              (tag) => Text(
                                '#$tag',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                    if (post.hasMedia) ...[
                      const SizedBox(height: 12),
                      PostMediaGallery(media: post.media),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ActionStatButton(
                          icon:
                              post.isLikePending
                                  ? null
                                  : (post.isLiked
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded),
                          color:
                              post.isLiked
                                  ? palette.likeColor
                                  : palette.iconMuted,
                          onTap: onLikeTap,
                          isLoading: post.isLikePending,
                          countLabel: _countLabelOrNull(post.stats.likeCount),
                          isActive: post.isLiked,
                        ),
                        _ActionStatButton(
                          icon: Icons.chat_bubble_outline_rounded,
                          color: palette.iconMuted,
                          onTap: onCommentTap,
                          countLabel: _countLabelOrNull(
                            post.stats.commentCount,
                          ),
                        ),
                        _ActionStatButton(
                          icon: Icons.repeat_rounded,
                          color: palette.iconMuted,
                          onTap: onShareTap,
                          countLabel: _countLabelOrNull(post.stats.shareCount),
                        ),
                        _ActionStatButton(
                          icon: Icons.send_rounded,
                          color: palette.iconMuted,
                          onTap: onShareTap,
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

class _PostRail extends StatelessWidget {
  const _PostRail({required this.post});

  final PostModel post;

  @override
  Widget build(BuildContext context) {
    final palette = FeedPalette.of(context);
    final avatarUrl = post.author.avatar.trim();
    final authorName = _authorName(post);
    final showReplyCluster = post.stats.commentCount > 0;

    return SizedBox(
      width: 40,
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: palette.border),
            ),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: palette.surfaceMuted,
              backgroundImage:
                  avatarUrl.isNotEmpty
                      ? CachedNetworkImageProvider(avatarUrl)
                      : null,
              child:
                  avatarUrl.isEmpty
                      ? Text(
                        _initialOf(authorName),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      )
                      : null,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 1.4,
            height: _threadHeight(post),
            decoration: BoxDecoration(
              color: palette.threadLine,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          if (showReplyCluster) ...[
            const SizedBox(height: 8),
            _ReplyCluster(count: post.stats.commentCount),
          ],
        ],
      ),
    );
  }

  double _threadHeight(PostModel post) {
    if (post.hasMedia) return 34;
    if (post.tags.isNotEmpty) return 28;
    if (post.hasContent) return 24;
    return 18;
  }
}

class _ReplyCluster extends StatelessWidget {
  const _ReplyCluster({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = FeedPalette.of(context);
    final clampedCount = count.clamp(1, 99);

    return SizedBox(
      width: 30,
      height: 18,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            child: _MiniReplyDot(color: palette.textTertiary),
          ),
          Positioned(left: 8, child: _MiniReplyDot(color: palette.iconMuted)),
          Positioned(
            left: 16,
            child: Container(
              width: 12,
              height: 12,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.surface,
                shape: BoxShape.circle,
                border: Border.all(color: palette.border),
              ),
              child: Text(
                clampedCount > 9 ? '9+' : '$clampedCount',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: palette.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniReplyDot extends StatelessWidget {
  const _MiniReplyDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = FeedPalette.of(context);

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.72),
        shape: BoxShape.circle,
        border: Border.all(color: palette.surface, width: 1.5),
      ),
    );
  }
}

class _PostHeader extends StatelessWidget {
  const _PostHeader({required this.post, required this.onMoreTap});

  final PostModel post;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = FeedPalette.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            _authorName(post),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _formatRelativeTime(post.createdAt),
          style: theme.textTheme.bodySmall?.copyWith(
            color: palette.textTertiary,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 4),
        Material(
          color: Colors.transparent,
          child: InkResponse(
            radius: 18,
            onTap: onMoreTap,
            child: SizedBox(
              width: 28,
              height: 28,
              child: Icon(
                Icons.more_horiz_rounded,
                size: 18,
                color: palette.iconMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionStatButton extends StatelessWidget {
  const _ActionStatButton({
    required this.onTap,
    required this.color,
    this.icon,
    this.isLoading = false,
    this.countLabel,
    this.isActive = false,
  });

  final VoidCallback onTap;
  final Color color;
  final IconData? icon;
  final bool isLoading;
  final String? countLabel;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = FeedPalette.of(context);
    final hasCount = countLabel != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(0, 8, 24, 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              else
                Icon(icon, size: 22, color: color),
              if (hasCount) ...[
                const SizedBox(width: 6),
                Text(
                  countLabel!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isActive ? color : palette.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String? _countLabelOrNull(int value) {
  if (value <= 0) return null;
  return _formatCount(value);
}

String _authorName(PostModel post) {
  final trimmedName = post.author.name.trim();
  if (trimmedName.isNotEmpty) return trimmedName;

  final handle = _authorHandle(post);
  if (handle.isNotEmpty) return handle;

  return 'Người dùng';
}

String _authorHandle(PostModel post) {
  final nickname = post.author.nickname.trim();
  if (nickname.isNotEmpty) return nickname;

  final displayName = post.author.name.trim();
  if (displayName.isNotEmpty) return displayName;

  return '';
}

String _formatRelativeTime(DateTime? dateTime) {
  if (dateTime == null) return 'Vừa xong';

  final now = DateTime.now();
  final diff = now.difference(dateTime);

  if (diff.inSeconds < 60) return 'Vừa xong';
  if (diff.inMinutes < 60) return '${diff.inMinutes} phút';
  if (diff.inHours < 24) return '${diff.inHours} giờ';
  if (diff.inDays < 7) return '${diff.inDays} ngày';

  final day = dateTime.day.toString().padLeft(2, '0');
  final month = dateTime.month.toString().padLeft(2, '0');
  return '$day/$month';
}

String _formatCount(int value) {
  if (value < 1000) return '$value';
  if (value < 1000000) {
    final compact = value / 1000;
    return compact % 1 == 0
        ? '${compact.toStringAsFixed(0)}K'
        : '${compact.toStringAsFixed(1)}K';
  }

  final compact = value / 1000000;
  return compact % 1 == 0
      ? '${compact.toStringAsFixed(0)}M'
      : '${compact.toStringAsFixed(1)}M';
}

String _initialOf(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '?';
  return String.fromCharCode(trimmed.runes.first).toUpperCase();
}
