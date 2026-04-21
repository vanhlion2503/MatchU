import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/views/feed/widgets/feed_palette.dart';

class PostRepostSheet extends StatelessWidget {
  const PostRepostSheet({
    super.key,
    required this.post,
    this.onRepostTap,
    this.onUndoRepostTap,
    this.onQuoteTap,
  });

  final PostModel post;
  final Future<void> Function()? onRepostTap;
  final Future<void> Function()? onUndoRepostTap;
  final Future<void> Function()? onQuoteTap;

  static Future<void> show(
    BuildContext context, {
    required PostModel post,
    Future<void> Function()? onRepostTap,
    Future<void> Function()? onUndoRepostTap,
    Future<void> Function()? onQuoteTap,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (_) => PostRepostSheet(
            post: post,
            onRepostTap: onRepostTap,
            onUndoRepostTap: onUndoRepostTap,
            onQuoteTap: onQuoteTap,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = FeedPalette.of(context);
    final theme = Theme.of(context);
    final isReposted = post.isReposted;

    final repostTitle = isReposted ? 'Hủy đăng lại' : 'Đăng lại';
    final repostSubtitle =
        isReposted
            ? 'Xóa bài đăng lại này khỏi hồ sơ của bạn.'
            : 'Đăng lại bài viết này trên hồ sơ của bạn.';

    final repostIconColor =
        isReposted ? theme.colorScheme.error : palette.repostColor;
    final repostTitleColor =
        isReposted ? theme.colorScheme.error : palette.textPrimary;

    return SafeArea(
      top: false,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: palette.shadowColor,
              blurRadius: 20,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),
              _RepostActionTile(
                icon: Iconsax.repeat,
                title: repostTitle,
                subtitle: repostSubtitle,
                palette: palette,
                iconColor: repostIconColor,
                titleColor: repostTitleColor,
                onTap:
                    () => _handleAsyncAction(
                      context,
                      isReposted ? onUndoRepostTap : onRepostTap,
                    ),
              ),
              const SizedBox(height: 10),
              _RepostActionTile(
                icon: Iconsax.quote_up,
                title: 'Trích dẫn',
                subtitle: 'Viết bài của bạn kèm bài viết gốc.',
                palette: palette,
                onTap: () => _handleAsyncAction(context, onQuoteTap),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleAsyncAction(
    BuildContext context,
    Future<void> Function()? action,
  ) {
    Navigator.of(context).pop();
    if (action == null) return;
    Future<void>.delayed(const Duration(milliseconds: 120), action);
  }
}

class _RepostActionTile extends StatelessWidget {
  const _RepostActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.palette,
    required this.onTap,
    this.iconColor,
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final FeedPalette palette;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.surfaceMuted,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: iconColor ?? palette.iconPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: titleColor ?? palette.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textSecondary,
                        height: 1.35,
                      ),
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
