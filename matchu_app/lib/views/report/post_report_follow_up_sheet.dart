import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/theme/app_theme.dart';

class PostReportFollowUpSheet extends StatefulWidget {
  const PostReportFollowUpSheet({
    super.key,
    required this.post,
    this.canHidePost = false,
    this.onHidePostTap,
    this.canHideAuthorPosts = false,
    this.onHideAuthorPostsTap,
    this.onBlockAuthorTap,
  });

  static const Duration _sheetExitDelay = Duration(milliseconds: 220);

  final PostModel post;
  final bool canHidePost;
  final Future<void> Function()? onHidePostTap;
  final bool canHideAuthorPosts;
  final Future<void> Function()? onHideAuthorPostsTap;
  final Future<void> Function()? onBlockAuthorTap;

  static Future<void> show({
    required PostModel post,
    bool canHidePost = false,
    Future<void> Function()? onHidePostTap,
    bool canHideAuthorPosts = false,
    Future<void> Function()? onHideAuthorPostsTap,
    Future<void> Function()? onBlockAuthorTap,
  }) {
    return Get.bottomSheet<void>(
      PostReportFollowUpSheet(
        post: post,
        canHidePost: canHidePost,
        onHidePostTap: onHidePostTap,
        canHideAuthorPosts: canHideAuthorPosts,
        onHideAuthorPostsTap: onHideAuthorPostsTap,
        onBlockAuthorTap: onBlockAuthorTap,
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  State<PostReportFollowUpSheet> createState() =>
      _PostReportFollowUpSheetState();
}

class _PostReportFollowUpSheetState extends State<PostReportFollowUpSheet> {
  _PostReportFollowUpAction? _selectedAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authorName = _authorDisplayName(widget.post);
    final shouldShowBlockAction = widget.onBlockAuthorTap != null;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.viewPaddingOf(context).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outline.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Iconsax.tick_circle,
                      color: colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đã gửi báo cáo',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Chọn một hành động tiếp theo với $authorName rồi bấm xác nhận.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (widget.canHidePost && widget.onHidePostTap != null) ...[
                _FollowUpActionTile(
                  icon: Iconsax.eye_slash,
                  title: 'Ẩn bài viết này',
                  subtitle: 'Ẩn bài viết này khỏi feed của bạn.',
                  selected:
                      _selectedAction == _PostReportFollowUpAction.hidePost,
                  onTap:
                      () => _selectAction(_PostReportFollowUpAction.hidePost),
                ),
                const SizedBox(height: 12),
              ],
              if (widget.canHideAuthorPosts &&
                  widget.onHideAuthorPostsTap != null) ...[
                _FollowUpActionTile(
                  icon: Iconsax.user_remove,
                  title: 'Ẩn toàn bộ bài viết của họ',
                  subtitle: 'Ẩn tất cả bài viết từ người dùng này trong feed.',
                  selected:
                      _selectedAction ==
                      _PostReportFollowUpAction.hideAuthorPosts,
                  onTap:
                      () => _selectAction(
                        _PostReportFollowUpAction.hideAuthorPosts,
                      ),
                ),
                const SizedBox(height: 12),
              ],
              if (shouldShowBlockAction) ...[
                _FollowUpActionTile(
                  icon: Iconsax.profile_delete,
                  title: 'Chặn người dùng',
                  subtitle:
                      'Bạn sẽ không còn thấy hồ sơ, bài viết và tin nhắn từ tài khoản này.',
                  selected:
                      _selectedAction == _PostReportFollowUpAction.blockAuthor,
                  iconColor: colorScheme.error,
                  textColor: colorScheme.error,
                  onTap:
                      () =>
                          _selectAction(_PostReportFollowUpAction.blockAuthor),
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _selectedAction == null ? null : _confirmSelection,
                  child: const Text('Xác nhận'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Bỏ qua'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectAction(_PostReportFollowUpAction action) {
    setState(() {
      _selectedAction = action;
    });
  }

  Future<void> _confirmSelection() async {
    final action = _selectedAction;
    if (action == null) return;

    Future<void> Function()? callback;
    switch (action) {
      case _PostReportFollowUpAction.hidePost:
        callback = widget.onHidePostTap;
        break;
      case _PostReportFollowUpAction.hideAuthorPosts:
        callback = widget.onHideAuthorPostsTap;
        break;
      case _PostReportFollowUpAction.blockAuthor:
        callback = widget.onBlockAuthorTap;
        break;
    }

    Navigator.of(context).pop();
    if (callback == null) return;

    await Future<void>.delayed(PostReportFollowUpSheet._sheetExitDelay);
    await callback();
  }
}

enum _PostReportFollowUpAction { hidePost, hideAuthorPosts, blockAuthor }

class _FollowUpActionTile extends StatelessWidget {
  const _FollowUpActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.iconColor,
    this.textColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final resolvedTextColor = textColor ?? colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:
                selected
                    ? AppTheme.errorColor.withValues(alpha: 0.07)
                    : colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  selected
                      ? AppTheme.errorColor.withValues(alpha: 0.5)
                      : theme.brightness == Brightness.dark
                      ? AppTheme.darkBorder
                      : AppTheme.lightBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.45,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: iconColor ?? resolvedTextColor,
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
                        color: resolvedTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.4,
                        color:
                            textColor?.withValues(alpha: 0.8) ??
                            colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppTheme.errorColor : colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _authorDisplayName(PostModel post) {
  final name = post.author.name.trim();
  if (name.isNotEmpty) return name;

  final nickname = post.author.nickname.trim();
  if (nickname.isNotEmpty) return '@$nickname';

  return 'người dùng này';
}
