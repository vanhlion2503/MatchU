import 'package:matchu_app/translations/localized_material.dart';
import 'package:get/get.dart';
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
    this.offerModerationAfterDelete = false,
    this.commentAuthorName = '',
    this.canReport = false,
    this.onReportTap,
    this.onReportCompleted,
    this.onBlockTap,
    this.canHide = false,
    this.onHideTap,
  });

  final bool canEdit;
  final Future<void> Function()? onEditTap;
  final bool canDelete;
  final Future<bool> Function()? onDeleteTap;
  final bool offerModerationAfterDelete;
  final String commentAuthorName;
  final bool canReport;
  final Future<bool> Function()? onReportTap;
  final Future<bool> Function()? onReportCompleted;
  final Future<void> Function()? onBlockTap;
  final bool canHide;
  final Future<void> Function()? onHideTap;

  static const Duration _sheetExitDelay = Duration(milliseconds: 180);

  static Future<void> show(
    BuildContext context, {
    bool canEdit = false,
    Future<void> Function()? onEditTap,
    bool canDelete = false,
    Future<bool> Function()? onDeleteTap,
    bool offerModerationAfterDelete = false,
    String commentAuthorName = '',
    bool canReport = false,
    Future<bool> Function()? onReportTap,
    Future<bool> Function()? onReportCompleted,
    Future<void> Function()? onBlockTap,
    bool canHide = false,
    Future<void> Function()? onHideTap,
  }) {
    if (!canEdit && !canDelete && !canReport && !canHide) {
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
            offerModerationAfterDelete: offerModerationAfterDelete,
            commentAuthorName: commentAuthorName,
            canReport: canReport,
            onReportTap: onReportTap,
            onReportCompleted: onReportCompleted,
            onBlockTap: onBlockTap,
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
              if (canReport) ...[
                _CommentActionTile(
                  icon: Iconsax.flag,
                  title: 'Báo cáo bình luận',
                  subtitle:
                      'Gửi bình luận này đến đội ngũ kiểm duyệt để xem xét.',
                  palette: palette,
                  iconColor: theme.colorScheme.error,
                  textColor: theme.colorScheme.error,
                  onTap: () => _onReportActionTap(context),
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

    final hostContext = Navigator.of(context).context;
    Navigator.of(context).pop();
    if (onDeleteTap == null) return;

    await Future<void>.delayed(_sheetExitDelay);
    final deleted = await onDeleteTap!();
    if (!deleted ||
        !offerModerationAfterDelete ||
        onReportTap == null ||
        !hostContext.mounted) {
      return;
    }

    final shouldReport = await _confirmFollowUp(
      hostContext,
      title: 'Báo cáo bình luận'.tr,
      message: 'Bạn có muốn báo cáo bình luận này không?'.tr,
      confirmLabel: 'Báo cáo',
    );
    if (!shouldReport) return;

    final reported = await onReportTap!();
    if (!reported || onBlockTap == null || !hostContext.mounted) return;

    await _askToBlock(hostContext);
  }

  Future<void> _onReportActionTap(BuildContext context) async {
    if (onReportTap == null) return;

    final hostContext = Navigator.of(context).context;
    Navigator.of(context).pop();
    await Future<void>.delayed(_sheetExitDelay);

    final reported = await onReportTap!();
    if (!reported) return;

    final dispositionSucceeded = await onReportCompleted?.call() ?? true;
    if (!dispositionSucceeded || onBlockTap == null || !hostContext.mounted) {
      return;
    }

    await _askToBlock(hostContext);
  }

  Future<void> _askToBlock(BuildContext context) async {
    final displayName = commentAuthorName.trim();
    final shouldBlock = await _confirmFollowUp(
      context,
      title: 'Chặn người dùng',
      message:
          displayName.isEmpty
              ? 'Bạn có muốn chặn người dùng này không?'
              : 'Bạn có muốn chặn $displayName không?',
      confirmLabel: 'Chặn',
    );
    if (shouldBlock) await onBlockTap?.call();
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

  Future<bool> _confirmFollowUp(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final palette = FeedPalette.of(dialogContext);
        final isDark = theme.brightness == Brightness.dark;

        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkSurface : palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Không'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmLabel),
            ),
          ],
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
