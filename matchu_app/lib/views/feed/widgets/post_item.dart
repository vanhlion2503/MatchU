import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/views/feed/widgets/feed_palette.dart';
import 'package:matchu_app/views/feed/widgets/post_media_gallery.dart';
import 'package:matchu_app/views/feed/widgets/post_ui_helpers.dart';
import 'package:matchu_app/widgets/verified_name_row.dart';

class PostItem extends StatelessWidget {
  const PostItem({
    super.key,
    required this.post,
    required this.onTap,
    required this.onLikeTap,
    required this.onCommentTap,
    required this.onShareTap,
    required this.onMoreTap,
  });

  final PostModel post;
  final VoidCallback onTap;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;
  final VoidCallback onShareTap;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = FeedPalette.of(context);
    final metaLabel = buildPostMetaLabel(post);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
                    if (metaLabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        metaLabel,
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
                      PostMediaGallery(
                        media: post.media,
                        multiImageLayout:
                            PostMediaGalleryMultiImageLayout.horizontalScroll,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ActionStatButton(
                          icon: post.isLiked ? Iconsax.heart5 : Iconsax.heart,
                          color:
                              post.isLiked
                                  ? palette.likeColor
                                  : palette.iconMuted,
                          onTap: onLikeTap,
                          countLabel: _countLabelOrNull(post.stats.likeCount),
                          isActive: post.isLiked,
                        ),
                        _ActionStatButton(
                          icon: Iconsax.message_text,
                          color: palette.iconMuted,
                          onTap: onCommentTap,
                          countLabel: _countLabelOrNull(
                            post.stats.commentCount,
                          ),
                        ),
                        _ActionStatButton(
                          icon: Iconsax.repeat,
                          color: palette.iconMuted,
                          onTap: onShareTap,
                          countLabel: _countLabelOrNull(post.stats.shareCount),
                        ),
                        _ActionStatButton(
                          icon: Iconsax.send_1,
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
    final showReplyCluster = post.stats.commentCount > 0;

    return SizedBox(
      width: 40,
      child: Column(
        children: [
          FeedAvatar(
            imageUrl: post.author.avatar,
            fallbackLabel: postAuthorName(post),
            size: 40,
            borderColor: palette.border,
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
          child: VerifiedNameRow(
            isVerified: post.author.isVerified,
            badgeSize: 15,
            badgePadding: const EdgeInsets.only(left: 4),
            child: Text(
              postAuthorName(post),
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
        const SizedBox(width: 4),
        Material(
          color: Colors.transparent,
          child: InkResponse(
            radius: 18,
            onTap: onMoreTap,
            child: SizedBox(
              width: 28,
              height: 28,
              child: Icon(Iconsax.more, size: 18, color: palette.iconMuted),
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
    this.countLabel,
    this.isActive = false,
  });

  final VoidCallback onTap;
  final Color color;
  final IconData? icon;
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
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 24, 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
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
  return formatCompactCount(value);
}
