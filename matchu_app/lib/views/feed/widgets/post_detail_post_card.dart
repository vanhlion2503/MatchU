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
    final authorName = postAuthorName(post);
    final metaLabel = buildPostMetaLabel(post);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FeedAvatar(
                    imageUrl: post.author.avatar,
                    fallbackLabel: authorName,
                    size: 46,
                    borderColor: palette.border,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        VerifiedNameRow(
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
                  color: palette.iconMuted,
                  onTap: onShareTap,
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

String? _countLabelOrNull(int value) {
  if (value <= 0) return null;
  return formatCompactCount(value);
}
