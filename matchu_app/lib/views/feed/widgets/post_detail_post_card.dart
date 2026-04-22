import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/views/feed/widgets/feed_palette.dart';
import 'package:matchu_app/views/feed/widgets/post_media_gallery.dart';
import 'package:matchu_app/views/feed/widgets/post_ui_helpers.dart';
import 'package:matchu_app/widgets/verified_name_row.dart';

class PostDetailPostCard extends StatelessWidget {
  const PostDetailPostCard({
    super.key,
    required this.post,
    required this.onLikeTap,
    required this.onCommentTap,
    required this.onRepostTap,
    required this.onShareTap,
    required this.onMoreTap,
    this.onAuthorTap,
    this.onReferenceAuthorTap,
  });

  final PostModel post;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;
  final VoidCallback onRepostTap;
  final VoidCallback onShareTap;
  final VoidCallback onMoreTap;
  final ValueChanged<String>? onAuthorTap;
  final ValueChanged<String>? onReferenceAuthorTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = FeedPalette.of(context);
    final authorName = postAuthorName(post);
    final metaLabel = buildPostMetaLabel(post);
    final onPostAuthorTap = _resolveUserTapHandler(
      _postAuthorId(post),
      onAuthorTap,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (post.isRepostOnly) ...[
                Row(
                  children: [
                    Icon(Iconsax.repeat, size: 14, color: palette.textTertiary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$authorName đã đăng lại',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: palette.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AvatarTapTarget(
                    onTap: onPostAuthorTap,
                    child: FeedAvatar(
                      imageUrl: post.author.avatar,
                      fallbackLabel: authorName,
                      size: 46,
                      borderColor: palette.border,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onPostAuthorTap,
                          child: VerifiedNameRow(
                            isVerified: post.author.isVerified,
                            badgeSize: 16,
                            badgePadding: const EdgeInsets.only(left: 4),
                            child: Text(
                              authorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: palette.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        if (metaLabel.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            metaLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.transparent,
                    child: InkResponse(
                      radius: 20,
                      onTap: onMoreTap,
                      splashFactory: NoSplash.splashFactory,
                      overlayColor: const WidgetStatePropertyAll(
                        Colors.transparent,
                      ),
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      hoverColor: Colors.transparent,
                      focusColor: Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Iconsax.more,
                          size: 20,
                          color: palette.iconMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (post.hasContent) ...[
                const SizedBox(height: 14),
                Text(
                  post.content,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.55,
                    color: palette.textPrimary,
                  ),
                ),
              ],
              if (post.tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
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
                const SizedBox(height: 16),
                PostMediaGallery(
                  media: post.media,
                  multiImageLayout:
                      PostMediaGalleryMultiImageLayout.horizontalScroll,
                ),
              ],
              if (post.referencePost != null) ...[
                const SizedBox(height: 14),
                _ReferencePostCard(
                  reference: post.referencePost!,
                  onAuthorTap: _resolveUserTapHandler(
                    _referenceAuthorId(post.referencePost!),
                    onReferenceAuthorTap ?? onAuthorTap,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  formatAbsolutePostTime(post.createdAt),
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: palette.border),
              bottom: BorderSide(color: palette.border),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _PostDetailActionButton(
                  icon: post.isLiked ? Iconsax.heart5 : Iconsax.heart,
                  label: _countLabelOrNull(post.stats.likeCount),
                  color: post.isLiked ? palette.likeColor : palette.iconMuted,
                  isActive: post.isLiked,
                  onTap: onLikeTap,
                ),
              ),
              Expanded(
                child: _PostDetailActionButton(
                  icon: Iconsax.message_text,
                  label: _countLabelOrNull(post.stats.commentCount),
                  color: palette.iconMuted,
                  onTap: onCommentTap,
                ),
              ),
              Expanded(
                child: _PostDetailActionButton(
                  icon: Iconsax.repeat,
                  label: _countLabelOrNull(post.stats.shareCount),
                  color: (post.isReposted
                          ? palette.repostColor
                          : palette.iconMuted)
                      .withValues(alpha: post.isRepostPending ? 0.58 : 1),
                  isActive: post.isReposted,
                  onTap: onRepostTap,
                ),
              ),
              Expanded(
                child: _PostDetailActionButton(
                  icon: Iconsax.send_1,
                  color: palette.iconMuted,
                  onTap: onShareTap,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReferencePostCard extends StatelessWidget {
  const _ReferencePostCard({required this.reference, this.onAuthorTap});

  final PostReferenceModel reference;
  final VoidCallback? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = FeedPalette.of(context);
    final authorName = _referenceAuthorName(reference);
    final authorHandle = _referenceAuthorHandle(reference);

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
              _AvatarTapTarget(
                onTap: onAuthorTap,
                child: FeedAvatar(
                  imageUrl: reference.author.avatar,
                  fallbackLabel: authorName,
                  size: 32,
                  borderColor: palette.border,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onAuthorTap,
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
                      if (authorHandle.isNotEmpty)
                        Text(
                          '@$authorHandle',
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
              ),
            ],
          ),
          if (reference.isUnavailable) ...[
            const SizedBox(height: 10),
            Text(
              'Bài viết gốc không còn khả dụng.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ] else ...[
            if (reference.hasContent) ...[
              const SizedBox(height: 10),
              Text(
                reference.content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
            if (reference.hasMedia) ...[
              const SizedBox(height: 12),
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

class _AvatarTapTarget extends StatelessWidget {
  const _AvatarTapTarget({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;

    return Material(
      color: Colors.transparent,
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        customBorder: const CircleBorder(),
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        child: child,
      ),
    );
  }
}

class _PostDetailActionButton extends StatelessWidget {
  const _PostDetailActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.label,
    this.isActive = false,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = FeedPalette.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: color),
              if (label != null) ...[
                const SizedBox(width: 7),
                Text(
                  label!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isActive ? color : palette.textSecondary,
                    fontWeight: FontWeight.w700,
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
  final name = reference.author.name.trim();
  if (name.isNotEmpty) return name;

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

String _postAuthorId(PostModel post) {
  final primaryAuthorId = post.authorId.trim();
  if (primaryAuthorId.isNotEmpty) return primaryAuthorId;
  return post.author.id.trim();
}

String _referenceAuthorId(PostReferenceModel reference) {
  final primaryAuthorId = reference.authorId.trim();
  if (primaryAuthorId.isNotEmpty) return primaryAuthorId;
  return reference.author.id.trim();
}

VoidCallback? _resolveUserTapHandler(
  String userId,
  ValueChanged<String>? onTap,
) {
  final normalizedUserId = userId.trim();
  if (onTap == null || normalizedUserId.isEmpty) return null;
  return () => onTap(normalizedUserId);
}
