import 'package:matchu_app/translations/localized_material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/translations/post_translations.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/services/feed/post_service.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/feed/widgets/feed_palette.dart';

class EditPostPrivacySheet extends StatefulWidget {
  const EditPostPrivacySheet({super.key, required this.post});

  final PostModel post;

  static Future<PostModel?> show(
    BuildContext context, {
    required PostModel post,
  }) {
    return showModalBottomSheet<PostModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditPostPrivacySheet(post: post),
    );
  }

  @override
  State<EditPostPrivacySheet> createState() => _EditPostPrivacySheetState();
}

class _EditPostPrivacySheetState extends State<EditPostPrivacySheet> {
  final PostService _service = PostService();
  late PostVisibility _selectedVisibility = widget.post.visibility;
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_selectedVisibility == widget.post.visibility) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final updatedPost = await _service.updatePostVisibility(
        post: widget.post,
        visibility: _selectedVisibility,
      );
      if (!mounted) return;
      Navigator.of(context).pop<PostModel>(updatedPost);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showError(_humanizeError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = FeedPalette.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
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
            Text(
              'Ch\u1EC9nh s\u1EEDa quy\u1EC1n ri\u00EAng t\u01B0',
              style: theme.textTheme.titleMedium?.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            for (final visibility in PostVisibility.values) ...[
              _PrivacyOptionTile(
                visibility: visibility,
                selected: visibility == _selectedVisibility,
                enabled: !_isSubmitting,
                palette: palette,
                onTap: () => setState(() => _selectedVisibility = visibility),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  disabledBackgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.52,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child:
                    _isSubmitting
                        ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                        : const Text('L\u01B0u thay \u0111\u1ED5i'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _humanizeError(Object error) {
    if (error is StateError) {
      return error.message.toString();
    }
    return error.toString();
  }

  void _showError(String message) {
    Get.snackbar(
      PostTranslationKeys.error.tr,
      postTr(message),
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
    );
  }
}

class _PrivacyOptionTile extends StatelessWidget {
  const _PrivacyOptionTile({
    required this.visibility,
    required this.selected,
    required this.enabled,
    required this.palette,
    required this.onTap,
  });

  final PostVisibility visibility;
  final bool selected;
  final bool enabled;
  final FeedPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: enabled ? onTap : null,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:
                selected
                    ? accent.withValues(alpha: 0.10)
                    : palette.surfaceMuted,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? accent : palette.border,
              width: selected ? 1.2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _privacyIcon(visibility),
                size: 22,
                color: selected ? accent : palette.iconPrimary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _privacyTitle(visibility),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _privacySubtitle(visibility),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                selected ? Iconsax.tick_circle : Icons.circle_outlined,
                size: 20,
                color: selected ? accent : palette.iconMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _privacyIcon(PostVisibility visibility) {
  switch (visibility) {
    case PostVisibility.public:
      return Iconsax.global;
    case PostVisibility.followers:
      return Iconsax.profile_2user;
    case PostVisibility.private:
      return Iconsax.lock;
  }
}

String _privacyTitle(PostVisibility visibility) {
  switch (visibility) {
    case PostVisibility.public:
      return 'C\u00F4ng khai';
    case PostVisibility.followers:
      return 'Ng\u01B0\u1EDDi theo d\u00F5i';
    case PostVisibility.private:
      return 'Ri\u00EAng t\u01B0';
  }
}

String _privacySubtitle(PostVisibility visibility) {
  switch (visibility) {
    case PostVisibility.public:
      return 'Hi\u1EC3n th\u1ECB trong b\u1EA3ng tin c\u00F4ng khai.';
    case PostVisibility.followers:
      return 'Ch\u1EC9 ng\u01B0\u1EDDi theo d\u00F5i b\u1EA1n m\u1EDBi xem.';
    case PostVisibility.private:
      return 'Ch\u1EC9 b\u1EA1n xem \u0111\u01B0\u1EE3c b\u00E0i vi\u1EBFt n\u00E0y.';
  }
}
