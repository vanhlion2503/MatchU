import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/feed/widgets/feed_palette.dart';

class CommentActionSheet extends StatelessWidget {
  const CommentActionSheet({
    super.key,
    this.canEdit = false,
    this.onEditTap,
    this.canDelete = false,
    this.onDeleteTap,
    this.canHide = false,
    this.onHideTap,
  });

  final bool canEdit;
  final Future<void> Function()? onEditTap;
  final bool canDelete;
  final Future<void> Function()? onDeleteTap;
  final bool canHide;
  final Future<void> Function()? onHideTap;

  static const Duration _sheetExitDelay = Duration(milliseconds: 180);

  static Future<void> show(
    BuildContext context, {
    bool canEdit = false,
    Future<void> Function()? onEditTap,
    bool canDelete = false,
    Future<void> Function()? onDeleteTap,
    bool canHide = false,
    Future<void> Function()? onHideTap,
  }) {
    if (!canEdit && !canDelete && !canHide) {
      return Future<void>.value();
    }

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => CommentActionSheet(
            canEdit: canEdit,
            onEditTap: onEditTap,
            canDelete: canDelete,
            onDeleteTap: onDeleteTap,
            canHide: canHide,
            onHideTap: onHideTap,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = FeedPalette.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          boxShadow: [
            BoxShadow(
              color: palette.shadowColor,
              blurRadius: 22,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              if (canEdit) ...[
                _CommentActionTile(
                  icon: Iconsax.edit_2,
                  title: 'Chỉnh sửa bình luận',
                  subtitle: 'Cập nhật nội dung bình luận của bạn.',
                  palette: palette,
                  onTap: () => _onEditTap(context),
                ),
                const SizedBox(height: 10),
              ],
              if (canHide) ...[
                _CommentActionTile(
                  icon: Iconsax.eye_slash,
                  title: 'Ẩn bình luận',
                  subtitle: 'Chỉ ẩn bình luận này trên thiết bị của bạn.',
                  palette: palette,
                  onTap: () => _onHideTap(context),
                ),
                const SizedBox(height: 10),
              ],
              if (canDelete)
                _CommentActionTile(
                  icon: Iconsax.trash,
                  title: 'Xóa bình luận',
                  subtitle:
                      'Xóa nội dung bình luận, phản hồi con vẫn được giữ.',
                  palette: palette,
                  iconColor: theme.colorScheme.error,
                  textColor: theme.colorScheme.error,
                  onTap: () => _onDeleteTap(context),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onEditTap(BuildContext context) async {
    Navigator.of(context).pop();
    if (onEditTap == null) return;

    await Future<void>.delayed(_sheetExitDelay);
    await onEditTap!();
  }

  Future<void> _onHideTap(BuildContext context) async {
    Navigator.of(context).pop();
    if (onHideTap == null) return;

    await Future<void>.delayed(_sheetExitDelay);
    await onHideTap!();
  }

  Future<void> _onDeleteTap(BuildContext context) async {
    final shouldDelete = await _confirmDeleteComment(context);
    if (!shouldDelete) return;
    if (!context.mounted) return;

    Navigator.of(context).pop();
    if (onDeleteTap == null) return;

    await Future<void>.delayed(_sheetExitDelay);
    await onDeleteTap!();
  }

  Future<bool> _confirmDeleteComment(BuildContext context) async {
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
                  'Xóa bình luận',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bạn có muốn xóa bình luận này?',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _CommentDialogButton(
                        label: 'Không',
                        onTap: () => Navigator.of(dialogContext).pop(false),
                        backgroundColor: palette.surfaceMuted,
                        borderColor: palette.border,
                        textColor: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CommentDialogButton(
                        label: 'Xóa',
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

class _CommentActionTile extends StatelessWidget {
  const _CommentActionTile({
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
                width: 40,
                height: 40,
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

class _CommentDialogButton extends StatelessWidget {
  const _CommentDialogButton({
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
