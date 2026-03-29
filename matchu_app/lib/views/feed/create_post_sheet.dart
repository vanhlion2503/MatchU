import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/feed/post_composer_controller.dart';
import 'package:matchu_app/controllers/user/user_controller.dart';
import 'package:matchu_app/models/feed/post_media_draft.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/services/feed/post_service.dart';
import 'package:matchu_app/theme/app_theme.dart';

class CreatePostSheet extends StatefulWidget {
  const CreatePostSheet({super.key});

  static Future<PostModel?> show(BuildContext context) {
    return showModalBottomSheet<PostModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreatePostSheet(),
    );
  }

  @override
  State<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<CreatePostSheet> {
  late final String _tag;
  late final PostComposerController _controller;
  final FocusNode _contentFocusNode = FocusNode();
  final FocusNode _tagFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _tag = 'post_composer_${DateTime.now().microsecondsSinceEpoch}';
    _controller = Get.put(PostComposerController(), tag: _tag);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 180), () {
        if (!mounted) return;
        _contentFocusNode.requestFocus();
      });
    });
  }

  @override
  void dispose() {
    _contentFocusNode.dispose();
    _tagFocusNode.dispose();

    if (Get.isRegistered<PostComposerController>(tag: _tag)) {
      Get.delete<PostComposerController>(tag: _tag, force: true);
    }
    super.dispose();
  }

  Future<void> _submitPost() async {
    final created = await _controller.submit();
    if (!mounted || created == null) return;
    Get.back<PostModel?>(result: created);
  }

  void _focusTagInput() {
    _contentFocusNode.unfocus();
    _tagFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final palette = _CreatePostPalette.of(context);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: mediaQuery.size.height * 0.94,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: palette.sheetBackground,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: palette.shadowColor,
                  blurRadius: 24,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: Column(
              children: [
                _SheetHeader(
                  controller: _controller,
                  palette: palette,
                  onCancel: () => Navigator.of(context).pop(),
                  onSubmit: _submitPost,
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => FocusScope.of(context).unfocus(),
                    behavior: HitTestBehavior.translucent,
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: _ComposerBody(
                        controller: _controller,
                        palette: palette,
                        contentFocusNode: _contentFocusNode,
                        tagFocusNode: _tagFocusNode,
                      ),
                    ),
                  ),
                ),
                _BottomToolbar(
                  controller: _controller,
                  palette: palette,
                  safeBottom: mediaQuery.padding.bottom,
                  onFocusTag: _focusTagInput,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.controller,
    required this.palette,
    required this.onCancel,
    required this.onSubmit,
  });

  final PostComposerController controller;
  final _CreatePostPalette palette;
  final VoidCallback onCancel;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: palette.headerBackground,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Obx(
        () => Row(
          children: [
            TextButton(
              onPressed: controller.isSubmitting.value ? null : onCancel,
              style: TextButton.styleFrom(
                foregroundColor: palette.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                textStyle: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Huy'),
            ),
            Expanded(
              child: Center(
                child: Text(
                  'Tao bai viet',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
            FilledButton(
              onPressed: controller.canSubmit ? onSubmit : null,
              style: FilledButton.styleFrom(
                backgroundColor: palette.publishButton,
                disabledBackgroundColor: palette.publishButtonDisabled,
                foregroundColor: palette.publishButtonForeground,
                disabledForegroundColor: palette.publishButtonForeground
                    .withValues(alpha: 0.72),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                textStyle: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              child:
                  controller.isSubmitting.value
                      ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: palette.publishButtonForeground,
                        ),
                      )
                      : const Text('Dang'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerBody extends StatelessWidget {
  const _ComposerBody({
    required this.controller,
    required this.palette,
    required this.contentFocusNode,
    required this.tagFocusNode,
  });

  final PostComposerController controller;
  final _CreatePostPalette palette;
  final FocusNode contentFocusNode;
  final FocusNode tagFocusNode;

  @override
  Widget build(BuildContext context) {
    final userController =
        Get.isRegistered<UserController>() ? Get.find<UserController>() : null;

    if (userController == null) {
      return _ComposerLayout(
        controller: controller,
        palette: palette,
        avatarUrl: '',
        handle: 'nguoi.dung',
        contentFocusNode: contentFocusNode,
        tagFocusNode: tagFocusNode,
      );
    }

    return Obx(
      () => _ComposerLayout(
        controller: controller,
        palette: palette,
        avatarUrl: userController.avatarUrl,
        handle: _composerHandleOf(userController),
        contentFocusNode: contentFocusNode,
        tagFocusNode: tagFocusNode,
      ),
    );
  }
}

class _ComposerLayout extends StatelessWidget {
  const _ComposerLayout({
    required this.controller,
    required this.palette,
    required this.avatarUrl,
    required this.handle,
    required this.contentFocusNode,
    required this.tagFocusNode,
  });

  final PostComposerController controller;
  final _CreatePostPalette palette;
  final String avatarUrl;
  final String handle;
  final FocusNode contentFocusNode;
  final FocusNode tagFocusNode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ComposerAvatar(
          avatarUrl: avatarUrl,
          fallbackLabel: handle,
          palette: palette,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  handle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller.contentController,
                focusNode: contentFocusNode,
                minLines: 5,
                maxLines: null,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 16,
                  height: 1.55,
                  color: palette.textPrimary,
                ),
                cursorColor: theme.colorScheme.primary,
                decoration: InputDecoration.collapsed(
                  hintText: 'Co gi moi?',
                  hintStyle: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: 16,
                    color: palette.placeholder,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Obx(
                () => Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${controller.remainingCharacters}/${PostService.maxContentLength}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color:
                          controller.remainingCharacters < 0
                              ? theme.colorScheme.error
                              : palette.textTertiary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _TagEditor(
                controller: controller,
                palette: palette,
                tagFocusNode: tagFocusNode,
              ),
              Obx(() {
                if (controller.mediaDrafts.isEmpty) {
                  return const SizedBox(height: 8);
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    height: 208,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: controller.mediaDrafts.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, index) {
                        final draft = controller.mediaDrafts[index];
                        return _DraftMediaPreviewCard(
                          draft: draft,
                          palette: palette,
                          onRemove: () => controller.removeMedia(draft),
                        );
                      },
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

class _ComposerAvatar extends StatelessWidget {
  const _ComposerAvatar({
    required this.avatarUrl,
    required this.fallbackLabel,
    required this.palette,
  });

  final String avatarUrl;
  final String fallbackLabel;
  final _CreatePostPalette palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: palette.border),
      ),
      child: CircleAvatar(
        radius: 20,
        backgroundColor: palette.surfaceMuted,
        backgroundImage:
            avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
        child:
            avatarUrl.isEmpty
                ? Text(
                  _initialOf(fallbackLabel),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                )
                : null,
      ),
    );
  }
}

class _TagEditor extends StatelessWidget {
  const _TagEditor({
    required this.controller,
    required this.palette,
    required this.tagFocusNode,
  });

  final PostComposerController controller;
  final _CreatePostPalette palette;
  final FocusNode tagFocusNode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(
      () => Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...controller.tags.map(
            (tag) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: palette.surfaceMuted,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '#$tag',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => controller.removeTag(tag),
                    child: Icon(
                      Icons.close_rounded,
                      size: 15,
                      color: palette.iconMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Focus(
            onFocusChange: (hasFocus) {
              if (!hasFocus) {
                controller.commitPendingTag();
              }
            },
            child: SizedBox(
              width: 120,
              child: TextField(
                controller: controller.tagInputController,
                focusNode: tagFocusNode,
                onSubmitted: (_) => controller.commitPendingTag(),
                textInputAction: TextInputAction.done,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 14,
                  color: palette.textSecondary,
                ),
                cursorColor: theme.colorScheme.primary,
                decoration: InputDecoration.collapsed(
                  hintText: 'Them tags...',
                  hintStyle: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 14,
                    color: palette.placeholder,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomToolbar extends StatelessWidget {
  const _BottomToolbar({
    required this.controller,
    required this.palette,
    required this.safeBottom,
    required this.onFocusTag,
  });

  final PostComposerController controller;
  final _CreatePostPalette palette;
  final double safeBottom;
  final VoidCallback onFocusTag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        safeBottom > 0 ? safeBottom : 12,
      ),
      decoration: BoxDecoration(
        color: palette.sheetBackground,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: Obx(
        () => Row(
          children: [
            _ToolbarIconButton(
              icon: Icons.add_photo_alternate_outlined,
              onTap:
                  controller.isPickingMedia.value
                      ? null
                      : controller.pickImages,
              palette: palette,
            ),
            const SizedBox(width: 14),
            _ToolbarIconButton(
              icon: Icons.video_collection_outlined,
              onTap:
                  controller.isPickingMedia.value ? null : controller.pickVideo,
              palette: palette,
            ),
            const SizedBox(width: 14),
            _ToolbarIconButton(
              icon: Icons.tag_rounded,
              onTap: onFocusTag,
              palette: palette,
            ),
            const Spacer(),
            _PrivacySelector(controller: controller, palette: palette),
          ],
        ),
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    required this.icon,
    required this.onTap,
    required this.palette,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final _CreatePostPalette palette;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkResponse(
        radius: 20,
        onTap: onTap,
        child: Icon(icon, size: 24, color: palette.iconMuted),
      ),
    );
  }
}

class _PrivacySelector extends StatelessWidget {
  const _PrivacySelector({required this.controller, required this.palette});

  final PostComposerController controller;
  final _CreatePostPalette palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(
      () => PopupMenuButton<bool>(
        padding: EdgeInsets.zero,
        offset: const Offset(0, -140),
        color: palette.sheetBackground,
        surfaceTintColor: Colors.transparent,
        onSelected: (value) => controller.isPublic.value = value,
        itemBuilder:
            (context) => [
              PopupMenuItem<bool>(
                value: true,
                child: _PrivacyMenuItem(
                  title: 'Cong khai',
                  subtitle: 'Hien thi trong feed cong khai',
                  icon: Icons.public_rounded,
                  selected: controller.isPublic.value,
                ),
              ),
              PopupMenuItem<bool>(
                value: false,
                child: _PrivacyMenuItem(
                  title: 'Rieng tu',
                  subtitle: 'Chi luu cho ban, khong len feed cong khai',
                  icon: Icons.lock_outline_rounded,
                  selected: !controller.isPublic.value,
                ),
              ),
            ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: palette.surfaceMuted,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                controller.isPublic.value
                    ? Icons.public_rounded
                    : Icons.lock_outline_rounded,
                size: 18,
                color: palette.iconMuted,
              ),
              const SizedBox(width: 6),
              Text(
                controller.isPublic.value ? 'Cong khai' : 'Rieng tu',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: palette.iconMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyMenuItem extends StatelessWidget {
  const _PrivacyMenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            icon,
            size: 18,
            color:
                selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DraftMediaPreviewCard extends StatelessWidget {
  const _DraftMediaPreviewCard({
    required this.draft,
    required this.palette,
    required this.onRemove,
  });

  final PostMediaDraft draft;
  final _CreatePostPalette palette;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 160,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AspectRatio(
            aspectRatio: 4 / 5,
            child: Container(
              decoration: BoxDecoration(
                color: palette.surfaceMuted,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: palette.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child:
                    draft.isImage
                        ? Image.file(draft.file, fit: BoxFit.cover)
                        : DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF0F172A),
                                palette.surfaceMuted,
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.play_circle_fill_rounded,
                                  color: Colors.white,
                                  size: 34,
                                ),
                                const Spacer(),
                                Text(
                                  'Video',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  draft.fileName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onRemove,
                borderRadius: BorderRadius.circular(999),
                child: Ink(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.52),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatePostPalette {
  const _CreatePostPalette({
    required this.sheetBackground,
    required this.headerBackground,
    required this.surfaceMuted,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.placeholder,
    required this.iconMuted,
    required this.publishButton,
    required this.publishButtonDisabled,
    required this.publishButtonForeground,
    required this.shadowColor,
  });

  final Color sheetBackground;
  final Color headerBackground;
  final Color surfaceMuted;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color placeholder;
  final Color iconMuted;
  final Color publishButton;
  final Color publishButtonDisabled;
  final Color publishButtonForeground;
  final Color shadowColor;

  factory _CreatePostPalette.of(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return _CreatePostPalette(
      sheetBackground:
          isDark ? const Color(0xFF10151F) : theme.scaffoldBackgroundColor,
      headerBackground:
          isDark ? const Color(0xF2111721) : const Color(0xF8FFFFFF),
      surfaceMuted: isDark ? const Color(0xFF171D28) : const Color(0xFFF7F7F8),
      border: isDark ? AppTheme.darkBorder : const Color(0xFFE9ECEF),
      textPrimary: theme.colorScheme.onSurface,
      textSecondary:
          isDark ? AppTheme.darkTextSecondary : const Color(0xFF404040),
      textTertiary: isDark ? const Color(0xFF98A2B3) : const Color(0xFF737373),
      placeholder: isDark ? const Color(0xFF7C8593) : const Color(0xFFA3A3A3),
      iconMuted: isDark ? const Color(0xFFB8C1CC) : const Color(0xFF737373),
      publishButton: isDark ? const Color(0xFFF4F4F5) : const Color(0xFF171717),
      publishButtonDisabled:
          isDark ? const Color(0xFF3A4350) : const Color(0xFFD4D4D8),
      publishButtonForeground: isDark ? const Color(0xFF111827) : Colors.white,
      shadowColor:
          isDark
              ? Colors.black.withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.08),
    );
  }
}

String _composerHandleOf(UserController? controller) {
  final nickname = controller?.nickname.trim() ?? '';
  if (nickname.isNotEmpty) return nickname;

  final fullname = controller?.fullname.trim() ?? '';
  if (fullname.isNotEmpty) {
    return fullname.replaceAll(RegExp(r'\s+'), '.').toLowerCase();
  }

  return 'nguoi.dung';
}

String _initialOf(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '?';
  return String.fromCharCode(trimmed.runes.first).toUpperCase();
}
