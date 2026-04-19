import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/views/feed/widgets/feed_palette.dart';

class PostActionSheet extends StatelessWidget {
  const PostActionSheet({super.key, required this.post});

  final PostModel post;

  static Future<void> show(BuildContext context, {required PostModel post}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PostActionSheet(post: post),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = FeedPalette.of(context);
    final authorHandle = _authorHandle(post);
    final sheetHeight = MediaQuery.of(context).size.height * 0.75;

    return SafeArea(
      top: false,
      child: Container(
        height: sheetHeight,
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: palette.shadowColor,
              blurRadius: 24,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => Navigator.of(context).pop(),
                        child: Ink(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: palette.surfaceMuted,
                            shape: BoxShape.circle,
                            border: Border.all(color: palette.border),
                          ),
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: palette.iconPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PostActionTile(
                      icon: Iconsax.eye_slash,
                      title: 'Ẩn bài viết',
                      subtitle: 'Ẩn bài viết này khỏi bảng tin của bạn.',
                      palette: palette,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 12),
                    _PostActionTile(
                      icon: Iconsax.bookmark,
                      title: 'Lưu bài viết',
                      subtitle: 'Đánh dấu để xem lại sau.',
                      palette: palette,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 12),
                    _PostActionTile(
                      icon: Iconsax.link_2,
                      title: 'Sao chép liên kết',
                      subtitle:
                          'Chuẩn bị giao diện cho thao tác chia sẻ liên kết.',
                      palette: palette,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 12),
                    _PostActionTile(
                      icon: Iconsax.user_remove,
                      title:
                          authorHandle.isNotEmpty
                              ? 'Ẩn bài viết từ @$authorHandle'
                              : 'Ẩn bài viết từ tác giả này',
                      subtitle:
                          'Giảm bớt nội dung tương tự xuất hiện trong bảng tin.',
                      palette: palette,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 12),
                    _PostActionTile(
                      icon: Iconsax.flag,
                      title: 'Báo cáo bài viết',
                      subtitle: 'Gửi báo cáo nếu nội dung này không phù hợp.',
                      palette: palette,
                      iconColor: theme.colorScheme.error,
                      textColor: theme.colorScheme.error,
                      onTap: () => Navigator.of(context).pop(),
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

class _PostActionTile extends StatelessWidget {
  const _PostActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.palette,
    required this.onTap,
    this.iconColor,
    this.textColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final FeedPalette palette;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.surfaceMuted,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: iconColor ?? palette.iconPrimary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: textColor ?? palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.4,
                        color: textColor ?? palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Iconsax.arrow_right_3, color: palette.iconMuted),
            ],
          ),
        ),
      ),
    );
  }
}

String _authorHandle(PostModel post) {
  final nickname = post.author.nickname.trim();
  if (nickname.isNotEmpty) return nickname;

  final displayName = post.author.name.trim();
  if (displayName.isNotEmpty) return displayName;

  return '';
}
