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
    required this.onRepostTap,
    required this.onShareTap,
    required this.onMoreTap,
    this.onReferenceTap,
  });

  final PostModel post;
  final VoidCallback onTap;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;
  final VoidCallback onRepostTap;
  final VoidCallback onShareTap;
  final VoidCallback onMoreTap;
  final VoidCallback? onReferenceTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = FeedPalette.of(context);
    final metaLabel = buildFeedPostMetaLabel(post);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  left: _PostRailLayout.contentLeft,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (post.isRepostOnly) ...[
                      _RepostBadge(post: post),
                      const SizedBox(height: 8),
                    ],
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
                    if (post.referencePost != null) ...[
                      const SizedBox(height: 12),
                      if (onReferenceTap == null)
                        _ReferencePostCard(reference: post.referencePost!)
                      else
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onReferenceTap,
                          child: _ReferencePostCard(
                            reference: post.referencePost!,
                          ),
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
                          color: (post.isReposted
                                  ? palette.repostColor
                                  : palette.iconMuted)
                              .withValues(
                                alpha: post.isRepostPending ? 0.58 : 1,
                              ),
                          onTap: onRepostTap,
                          countLabel: _countLabelOrNull(post.stats.shareCount),
                          isActive: post.isReposted,
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
              _PostRail(post: post),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostRailLayout {
  static const double width = 40;
  static const double gap = 12;
  static const double avatarSize = 40;
  static const double lineWidth = 1.4;
  static const double lineTopOffset = avatarSize + 8;
  static const double lineBottomOffset = 12;
  static const double replyClusterWidth = 30;
  static const double replyClusterBottomOffset = 6;
  static const double contentLeft = width + gap;
  static const double lineLeft = (width - lineWidth) / 2;
  static const double replyClusterLeft = (width - replyClusterWidth) / 2;
}

class _PostRail extends StatelessWidget {
  const _PostRail({required this.post});

  final PostModel post;

  @override
  Widget build(BuildContext context) {
    final palette = FeedPalette.of(context);
    final showReplyCluster = post.stats.commentCount > 0;

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              child: FeedAvatar(
                imageUrl: post.author.avatar,
                fallbackLabel: postAuthorName(post),
                size: _PostRailLayout.avatarSize,
                borderColor: palette.border,
              ),
            ),
            Positioned(
              left: _PostRailLayout.lineLeft,
              top: _PostRailLayout.lineTopOffset,
              bottom: _PostRailLayout.lineBottomOffset,
              child: Container(
                width: _PostRailLayout.lineWidth,
                decoration: BoxDecoration(
                  color: palette.threadLine,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            if (showReplyCluster)
              Positioned(
                left: _PostRailLayout.replyClusterLeft,
                bottom: _PostRailLayout.replyClusterBottomOffset,
                child: _ReplyCluster(count: post.stats.commentCount),
              ),
          ],
        ),
      ),
    );
  }
}

class _RepostBadge extends StatelessWidget {
  const _RepostBadge({required this.post});

  final PostModel post;

  @override
  Widget build(BuildContext context) {
    final palette = FeedPalette.of(context);
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(Iconsax.repeat, size: 14, color: palette.textTertiary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '${postAuthorName(post)} đã đăng lại',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReferencePostCard extends StatelessWidget {
  const _ReferencePostCard({required this.reference});

  final PostReferenceModel reference;

  @override
  Widget build(BuildContext context) {
    final palette = FeedPalette.of(context);
    final theme = Theme.of(context);
    final authorName = _referenceAuthorName(reference);
    final handle = _referenceAuthorHandle(reference);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FeedAvatar(
                imageUrl: reference.author.avatar,
                fallbackLabel: authorName,
                size: 28,
                borderColor: palette.border,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                    if (handle.isNotEmpty)
                      Text(
                        '@$handle',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: palette.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (reference.isUnavailable) ...[
            const SizedBox(height: 8),
            Text(
              'Bài viết gốc không còn khả dụng.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ] else ...[
            if (reference.hasContent) ...[
              const SizedBox(height: 8),
              Text(
                reference.content,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
            if (reference.hasMedia) ...[
              const SizedBox(height: 10),
              PostMediaGallery(
                media: reference.media,
                multiImageLayout:
                    PostMediaGalleryMultiImageLayout.horizontalScroll,
              ),
            ],
          ],
        ],
      ),
    );
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

String _referenceAuthorName(PostReferenceModel reference) {
  final trimmedName = reference.author.name.trim();
  if (trimmedName.isNotEmpty) return trimmedName;

  final handle = _referenceAuthorHandle(reference);
  if (handle.isNotEmpty) return handle;

  return 'Người dùng';
}

String _referenceAuthorHandle(PostReferenceModel reference) {
  final nickname = reference.author.nickname.trim();
  if (nickname.isNotEmpty) return nickname;

  final displayName = reference.author.name.trim();
  if (displayName.isNotEmpty) {
    return displayName.replaceAll(RegExp(r'\s+'), '.').toLowerCase();
  }

  return '';
}

String? _countLabelOrNull(int value) {
  if (value <= 0) return null;
  return formatCompactCount(value);
}
