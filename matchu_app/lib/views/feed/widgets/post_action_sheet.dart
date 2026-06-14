import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/feed/widgets/feed_palette.dart';

class PostActionSheet extends StatelessWidget {
  const PostActionSheet({
    super.key,
    required this.post,
    this.isSaved = false,
    this.onSaveTap,
    this.canHidePost = false,
    this.onHidePostTap,
    this.canHideAuthorPosts = false,
    this.onHideAuthorPostsTap,
    this.canEditPost = false,
    this.onEditPostTap,
    this.canEditPrivacy = false,
    this.onEditPrivacyTap,
    this.canDeletePost = false,
    this.onDeleteTap,
  });

  final PostModel post;
  final bool isSaved;
  final Future<void> Function()? onSaveTap;
  final bool canHidePost;
  final Future<void> Function()? onHidePostTap;
  final bool canHideAuthorPosts;
  final Future<void> Function()? onHideAuthorPostsTap;
  final bool canEditPost;
  final Future<void> Function()? onEditPostTap;
  final bool canEditPrivacy;
  final Future<void> Function()? onEditPrivacyTap;
  final bool canDeletePost;
  final Future<void> Function()? onDeleteTap;
  static const Duration _sheetExitDelay = Duration(milliseconds: 220);

  static Future<void> show(
    BuildContext context, {
    required PostModel post,
    bool isSaved = false,
    Future<void> Function()? onSaveTap,
    bool canHidePost = false,
    Future<void> Function()? onHidePostTap,
    bool canHideAuthorPosts = false,
    Future<void> Function()? onHideAuthorPostsTap,
    bool canEditPost = false,
    Future<void> Function()? onEditPostTap,
    bool canEditPrivacy = false,
    Future<void> Function()? onEditPrivacyTap,
    bool canDeletePost = false,
    Future<void> Function()? onDeleteTap,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => PostActionSheet(
            post: post,
            isSaved: isSaved,
            onSaveTap: onSaveTap,
            canHidePost: canHidePost,
            onHidePostTap: onHidePostTap,
            canHideAuthorPosts: canHideAuthorPosts,
            onHideAuthorPostsTap: onHideAuthorPostsTap,
            canEditPost: canEditPost,
            onEditPostTap: onEditPostTap,
            canEditPrivacy: canEditPrivacy,
            onEditPrivacyTap: onEditPrivacyTap,
            canDeletePost: canDeletePost,
            onDeleteTap: onDeleteTap,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = FeedPalette.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authorHandle = _authorHandle(post);
    final sheetHeight = MediaQuery.of(context).size.height * 0.75;
    const savedHighlightColor = Color(0xFFF59E0B);

    return SafeArea(
      top: false,
      child: Container(
        height: sheetHeight,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : theme.scaffoldBackgroundColor,
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
                    if (canEditPost) ...[
                      _PostActionTile(
                        icon: Iconsax.edit_2,
                        title: 'Ch\u1EC9nh s\u1EEDa b\u00E0i vi\u1EBFt',
                        subtitle:
                            'C\u1EADp nh\u1EADt n\u1ED9i dung, th\u1EBB v\u00E0 t\u1EC7p \u0111\u00EDnh k\u00E8m.',
                        palette: palette,
                        onTap: () => _onEditPostTap(context),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (canEditPrivacy) ...[
                      _PostActionTile(
                        icon: Iconsax.lock,
                        title:
                            'Ch\u1EC9nh s\u1EEDa quy\u1EC1n ri\u00EAng t\u01B0',
                        subtitle:
                            'Thay \u0111\u1ED5i ai c\u00F3 th\u1EC3 xem b\u00E0i vi\u1EBFt n\u00E0y.',
                        palette: palette,
                        onTap: () => _onEditPrivacyTap(context),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (canHidePost) ...[
                      _PostActionTile(
                        icon: Iconsax.eye_slash,
                        title: '\u1EA8n b\u00E0i vi\u1EBFt',
                        subtitle:
                            '\u1EA8n b\u00E0i vi\u1EBFt n\u00E0y kh\u1ECFi trang tin.',
                        palette: palette,
                        onTap: () => _onHidePostTap(context),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _PostActionTile(
                      icon: Iconsax.bookmark,
                      title: isSaved ? 'Đã lưu bài viết' : 'Lưu bài viết',
                      subtitle:
                          isSaved
                              ? 'Nhấn lần nữa để bỏ lưu bài viết.'
                              : 'Đánh dấu để xem lại sau.',
                      palette: palette,
                      iconColor:
                          isSaved ? savedHighlightColor : palette.iconPrimary,
                      textColor: isSaved ? savedHighlightColor : null,
                      onTap: () => _onSavePostTap(context),
                    ),
                    const SizedBox(height: 12),
                    _PostActionTile(
                      icon: Iconsax.link_2,
                      title: 'Sao chép liên kết',
                      subtitle: 'Chia sẻ liên kết bài viết.',
                      palette: palette,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    if (canHideAuthorPosts) ...[
                      const SizedBox(height: 12),
                      _PostActionTile(
                        icon: Iconsax.user_remove,
                        title:
                            authorHandle.isNotEmpty
                                ? '\u1EA8n b\u00E0i vi\u1EBFt t\u1EEB @$authorHandle'
                                : '\u1EA8n b\u00E0i vi\u1EBFt t\u1EEB t\u00E1c gi\u1EA3 n\u00E0y',
                        subtitle:
                            '\u1EA8n to\u00E0n b\u1ED9 b\u00E0i vi\u1EBFt t\u1EEB ng\u01B0\u1EDDi n\u00E0y trong feed.',
                        palette: palette,
                        onTap: () => _onHideAuthorPostsTap(context),
                      ),
                    ],
                    if (canDeletePost) ...[
                      const SizedBox(height: 12),
                      _PostActionTile(
                        icon: Iconsax.trash,
                        title: 'Xóa bài viết',
                        subtitle:
                            'Xóa vĩnh viễn bài viết này khỏi tài khoản của bạn.',
                        palette: palette,
                        iconColor: theme.colorScheme.error,
                        textColor: theme.colorScheme.error,
                        onTap: () => _onDeletePostTap(context),
                      ),
                    ],
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

  Future<void> _onHidePostTap(BuildContext context) async {
    Navigator.of(context).pop();
    if (onHidePostTap == null) return;

    await Future<void>.delayed(_sheetExitDelay);
    await onHidePostTap!();
  }

  Future<void> _onHideAuthorPostsTap(BuildContext context) async {
    final shouldHide = await _confirmHideAuthorPosts(context);
    if (!shouldHide) return;
    if (!context.mounted) return;

    Navigator.of(context).pop();
    if (onHideAuthorPostsTap == null) return;

    await Future<void>.delayed(_sheetExitDelay);
    await onHideAuthorPostsTap!();
  }

  Future<void> _onEditPostTap(BuildContext context) async {
    Navigator.of(context).pop();
    if (onEditPostTap == null) return;

    await Future<void>.delayed(_sheetExitDelay);
    await onEditPostTap!();
  }

  Future<void> _onEditPrivacyTap(BuildContext context) async {
    Navigator.of(context).pop();
    if (onEditPrivacyTap == null) return;

    await Future<void>.delayed(_sheetExitDelay);
    await onEditPrivacyTap!();
  }

  Future<void> _onSavePostTap(BuildContext context) async {
    Navigator.of(context).pop();
    if (onSaveTap == null) return;

    await Future<void>.delayed(_sheetExitDelay);
    await onSaveTap!();
  }

  Future<void> _onDeletePostTap(BuildContext context) async {
    final shouldDelete = await _confirmDeletePost(context);
    if (!shouldDelete) return;
    if (!context.mounted) return;

    Navigator.of(context).pop();
    if (onDeleteTap == null) return;

    await Future<void>.delayed(_sheetExitDelay);
    await onDeleteTap!();
  }

  Future<bool> _confirmDeletePost(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final palette = FeedPalette.of(dialogContext);
        final isDark = theme.brightness == Brightness.dark;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : palette.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: palette.border),
              boxShadow: [
                BoxShadow(
                  color: palette.shadowColor,
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xóa bài viết',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bạn có muốn xóa bài viết này vĩnh viễn?',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _DeleteDialogButton(
                        label: 'Không',
                        onTap: () => Navigator.of(dialogContext).pop(false),
                        backgroundColor: palette.surfaceMuted,
                        borderColor: palette.border,
                        textColor: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DeleteDialogButton(
                        label: 'Có',
                        onTap: () => Navigator.of(dialogContext).pop(true),
                        backgroundColor: theme.colorScheme.error,
                        borderColor: theme.colorScheme.error,
                        textColor: theme.colorScheme.onError,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    return result ?? false;
  }

  Future<bool> _confirmHideAuthorPosts(BuildContext context) async {
    final authorName = _authorDisplayName(post);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final palette = FeedPalette.of(dialogContext);
        final isDark = theme.brightness == Brightness.dark;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : palette.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: palette.border),
              boxShadow: [
                BoxShadow(
                  color: palette.shadowColor,
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\u1EA8n b\u00E0i vi\u1EBFt t\u1EEB $authorName?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'T\u1EA5t c\u1EA3 b\u00E0i vi\u1EBFt c\u1EE7a ng\u01B0\u1EDDi n\u00E0y s\u1EBD b\u1ECB \u1EA9n kh\u1ECFi feed. B\u1EA1n c\u00F3 th\u1EC3 b\u1ECF \u1EA9n trong Danh s\u00E1ch h\u1EA1n ch\u1EBF.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _DeleteDialogButton(
                        label: 'Kh\u00F4ng',
                        onTap: () => Navigator.of(dialogContext).pop(false),
                        backgroundColor: palette.surfaceMuted,
                        borderColor: palette.border,
                        textColor: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DeleteDialogButton(
                        label: 'C\u00F3',
                        onTap: () => Navigator.of(dialogContext).pop(true),
                        backgroundColor: theme.colorScheme.error,
                        borderColor: theme.colorScheme.error,
                        textColor: theme.colorScheme.onError,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    return result ?? false;
  }
}

class _DeleteDialogButton extends StatelessWidget {
  const _DeleteDialogButton({
    required this.label,
    required this.onTap,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
  });

  final String label;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          height: 44,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
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

String _authorDisplayName(PostModel post) {
  final name = post.author.name.trim();
  if (name.isNotEmpty) return name;

  final handle = _authorHandle(post);
  if (handle.isNotEmpty) return '@$handle';

  return 'ng\u01B0\u1EDDi n\u00E0y';
}
