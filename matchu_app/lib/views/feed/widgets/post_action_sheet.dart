import 'package:cached_network_image/cached_network_image.dart';
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
    final authorName = _authorName(post);
    final authorHandle = _authorHandle(post);
    final avatarUrl = post.author.avatar.trim();

    return SafeArea(
      top: false,
      child: Container(
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: palette.border),
                    ),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: palette.surfaceMuted,
                      backgroundImage:
                          avatarUrl.isNotEmpty
                              ? CachedNetworkImageProvider(avatarUrl)
                              : null,
                      child:
                          avatarUrl.isEmpty
                              ? Text(
                                _initialOf(authorName),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: palette.textPrimary,
                                ),
                              )
                              : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          authorHandle.isNotEmpty
                              ? '@$authorHandle'
                              : 'Bài viết trong bảng tin của bạn',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: palette.surfaceMuted,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  'Các thao tác bên dưới hiện mới là phần giao diện để bạn duyệt trước.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.45,
                    color: palette.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 18),
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
                subtitle: 'Chuẩn bị giao diện cho thao tác chia sẻ liên kết.',
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
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Đóng'),
                ),
              ),
            ],
          ),
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

String _initialOf(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '?';
  return String.fromCharCode(trimmed.runes.first).toUpperCase();
}
