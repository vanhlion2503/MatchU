import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/feed/post_detail_controller.dart';
import 'package:matchu_app/controllers/user/user_controller.dart';
import 'package:matchu_app/views/feed/widgets/feed_palette.dart';
import 'package:matchu_app/views/feed/widgets/post_action_sheet.dart';
import 'package:matchu_app/views/feed/widgets/post_detail_comment_item.dart';
import 'package:matchu_app/views/feed/widgets/post_detail_post_card.dart';
import 'package:matchu_app/views/feed/widgets/post_ui_helpers.dart';

class PostDetailView extends GetView<PostDetailController> {
  const PostDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = FeedPalette.of(context);

    return Scaffold(
      backgroundColor: palette.surface,
      appBar: const _PostDetailAppBar(),
      body: Obx(() {
        final post = controller.post.value;

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            PostDetailPostCard(
              post: post,
              onLikeTap: controller.toggleLike,
              onCommentTap: controller.dismissCommentComposer,
              onShareTap: controller.sharePost,
              onMoreTap: () => PostActionSheet.show(context, post: post),
            ),
            _CommentsSection(controller: controller),
          ],
        );
      }),
      bottomNavigationBar: _PostDetailComposer(controller: controller),
    );
  }
}

class _CommentsSection extends StatelessWidget {
  const _CommentsSection({required this.controller});

  final PostDetailController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = FeedPalette.of(context);
    final commentsController = controller.commentsController;

    return Obx(() {
      if (commentsController.isLoading.value) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ),
        );
      }

      if (commentsController.errorMessage.value != null &&
          commentsController.comments.isEmpty) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(
            children: [
              Icon(Iconsax.warning_2, size: 30, color: theme.colorScheme.error),
              const SizedBox(height: 10),
              Text(
                commentsController.errorMessage.value!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: commentsController.loadComments,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        );
      }

      if (commentsController.threadEntries.isEmpty) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
          child: Text(
            'Chưa có bình luận nào. Hãy mở đầu cuộc trò chuyện.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textSecondary,
              height: 1.5,
            ),
          ),
        );
      }

      final entries = commentsController.threadEntries;

      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          final shouldShowDivider = index > 0 && entry.depth == 0;

          return Column(
            children: [
              if (shouldShowDivider)
                Divider(height: 1, thickness: 1, color: palette.border),
              PostDetailCommentItem(
                entry: entry,
                onReplyTap: () => commentsController.startReply(entry.comment),
                onToggleRepliesTap:
                    () => commentsController.toggleReplies(entry.comment),
              ),
            ],
          );
        },
      );
    });
  }
}

class _PostDetailComposer extends StatefulWidget {
  const _PostDetailComposer({required this.controller});

  final PostDetailController controller;

  @override
  State<_PostDetailComposer> createState() => _PostDetailComposerState();
}

class _PostDetailComposerState extends State<_PostDetailComposer> {
  static const double _kPillHeight = 52;
  static const double _kEmojiPickerHeight = 320;

  int _clampInt(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  void _insertEmoji(String emoji) {
    final inputController =
        widget.controller.commentsController.inputController;
    final text = inputController.text;
    final selection = inputController.selection;
    final textLength = text.length;
    final hasValidSelection = selection.start >= 0 && selection.end >= 0;

    final start =
        hasValidSelection
            ? _clampInt(selection.start, 0, textLength)
            : textLength;
    final end =
        hasValidSelection ? _clampInt(selection.end, start, textLength) : start;

    inputController.value = inputController.value.copyWith(
      text: text.replaceRange(start, end, emoji),
      selection: TextSelection.collapsed(offset: start + emoji.length),
      composing: TextRange.empty,
    );
  }

  Future<void> _openEmojiPicker(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surface,
      builder:
          (_) => SafeArea(
            top: false,
            child: SizedBox(
              height: _kEmojiPickerHeight,
              child: EmojiPicker(
                onEmojiSelected: (_, emoji) => _insertEmoji(emoji.emoji),
                config: Config(
                  height: _kEmojiPickerHeight,
                  emojiViewConfig: EmojiViewConfig(
                    columns: 8,
                    emojiSizeMax: 28,
                    backgroundColor: scheme.surface,
                  ),
                  categoryViewConfig: CategoryViewConfig(
                    backgroundColor: scheme.surface,
                    indicatorColor: scheme.primary,
                    iconColor: scheme.onSurface.withValues(alpha: 0.6),
                    iconColorSelected: scheme.primary,
                  ),
                  bottomActionBarConfig: BottomActionBarConfig(
                    backgroundColor: scheme.surface,
                    buttonColor: scheme.primary,
                  ),
                  searchViewConfig: SearchViewConfig(
                    backgroundColor: scheme.surface,
                  ),
                  skinToneConfig: const SkinToneConfig(enabled: true),
                ),
              ),
            ),
          ),
    );
  }

  void _showImageCommentNotice() {
    HapticFeedback.selectionClick();
    Get.snackbar(
      'Sắp hỗ trợ',
      'Bình luận kèm ảnh đang được hoàn thiện.',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = FeedPalette.of(context);
    final theme = Theme.of(context);
    final commentsController = widget.controller.commentsController;
    final userController =
        Get.isRegistered<UserController>() ? Get.find<UserController>() : null;
    final isDark = theme.brightness == Brightness.dark;
    final shellColor =
        Color.lerp(theme.scaffoldBackgroundColor, palette.surface, 0.55) ??
        palette.surface;
    final pillColor =
        Color.lerp(
          theme.scaffoldBackgroundColor,
          palette.inputSurface,
          isDark ? 0.78 : 0.92,
        ) ??
        palette.inputSurface;
    final replySurface =
        Color.lerp(palette.surfaceMuted, theme.scaffoldBackgroundColor, 0.28) ??
        palette.surfaceMuted;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: shellColor.withValues(alpha: isDark ? 0.96 : 0.94),
              border: Border(
                top: BorderSide(color: palette.border.withValues(alpha: 0.88)),
              ),
              boxShadow: [
                BoxShadow(
                  color: palette.shadowColor.withValues(
                    alpha: isDark ? 0.18 : 0.08,
                  ),
                  blurRadius: 18,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Obx(() {
                final replyingTo = commentsController.replyingTo.value;
                final isSubmitting = commentsController.isSubmitting.value;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (replyingTo != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                          decoration: BoxDecoration(
                            color: replySurface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: palette.border.withValues(alpha: 0.82),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 3,
                                height:
                                    replyingTo.content.trim().isEmpty ? 18 : 34,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.7,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Đang trả lời ${replyingTo.author?.displayName ?? 'người dùng'}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: palette.textSecondary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    if (replyingTo.content
                                        .trim()
                                        .isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        replyingTo.content.trim(),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: palette.textPrimary,
                                              height: 1.35,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: commentsController.cancelReply,
                                visualDensity: VisualDensity.compact,
                                style: const ButtonStyle(
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  overlayColor: WidgetStatePropertyAll(
                                    Colors.transparent,
                                  ),
                                  splashFactory: NoSplash.splashFactory,
                                ),
                                icon: Icon(
                                  Iconsax.close_circle,
                                  size: 18,
                                  color: palette.iconMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    TextFieldTapRegion(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: Container(
                          constraints: const BoxConstraints(
                            minHeight: _kPillHeight,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: pillColor,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: palette.border.withValues(
                                alpha: isDark ? 0.92 : 0.72,
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: palette.shadowColor.withValues(
                                  alpha: isDark ? 0.14 : 0.05,
                                ),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              if (userController != null)
                                Obx(
                                  () => _ComposerAvatar(
                                    imageUrl:
                                        userController
                                            .userRx
                                            .value
                                            ?.avatarUrl ??
                                        '',
                                    fallbackLabel: _currentUserFallbackLabel(
                                      userController,
                                    ),
                                    size: 32,
                                    borderColor: palette.border,
                                    backgroundColor: palette.surfaceMuted,
                                    textColor: palette.textPrimary,
                                  ),
                                )
                              else
                                _ComposerAvatar(
                                  imageUrl: '',
                                  fallbackLabel: 'Bạn',
                                  size: 32,
                                  borderColor: palette.border,
                                  backgroundColor: palette.surfaceMuted,
                                  textColor: palette.textPrimary,
                                ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller:
                                      commentsController.inputController,
                                  focusNode: commentsController.inputFocusNode,
                                  minLines: 1,
                                  maxLines: 1,
                                  textInputAction: TextInputAction.send,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: palette.textPrimary,
                                    height: 1.2,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Thêm câu trả lời...',
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    isCollapsed: true,
                                    hintStyle: theme.textTheme.bodyMedium
                                        ?.copyWith(color: palette.textTertiary),
                                  ),
                                  onTapOutside:
                                      (_) =>
                                          widget.controller
                                              .dismissCommentComposer(),
                                  onSubmitted:
                                      (_) => commentsController.submitComment(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              _ComposerActionButton(
                                icon: Iconsax.gallery,
                                color: palette.iconMuted,
                                onPressed:
                                    isSubmitting
                                        ? null
                                        : _showImageCommentNotice,
                              ),
                              const SizedBox(width: 4),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                switchInCurve: Curves.easeOut,
                                switchOutCurve: Curves.easeIn,
                                child:
                                    isSubmitting
                                        ? SizedBox(
                                          key: const ValueKey(
                                            'composer_loading',
                                          ),
                                          width: 36,
                                          height: 36,
                                          child: Center(
                                            child: SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.1,
                                                color:
                                                    theme.colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                        )
                                        : _ComposerActionButton(
                                          key: const ValueKey('emoji_button'),
                                          icon: Iconsax.emoji_happy,
                                          color: palette.iconMuted,
                                          onPressed:
                                              () => _openEmojiPicker(context),
                                        ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposerAvatar extends StatelessWidget {
  const _ComposerAvatar({
    required this.imageUrl,
    required this.fallbackLabel,
    required this.size,
    required this.borderColor,
    required this.backgroundColor,
    required this.textColor,
  });

  final String imageUrl;
  final String fallbackLabel;
  final double size;
  final Color borderColor;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = imageUrl.trim();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor),
      ),
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: backgroundColor,
        backgroundImage:
            trimmedUrl.isNotEmpty
                ? CachedNetworkImageProvider(trimmedUrl)
                : null,
        child:
            trimmedUrl.isEmpty
                ? Text(
                  initialOf(fallbackLabel),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                )
                : null,
      ),
    );
  }
}

class _ComposerActionButton extends StatelessWidget {
  const _ComposerActionButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      splashRadius: 18,
      icon: Icon(
        icon,
        size: 19,
        color: onPressed == null ? color.withValues(alpha: 0.38) : color,
      ),
    );
  }
}

String _currentUserFallbackLabel(UserController controller) {
  final fullName = controller.userRx.value?.fullname.trim() ?? '';
  if (fullName.isNotEmpty) return fullName;

  final nickname = controller.userRx.value?.nickname.trim() ?? '';
  if (nickname.isNotEmpty) return nickname;

  return 'Bạn';
}

class _PostDetailAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _PostDetailAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);

  @override
  Widget build(BuildContext context) {
    final palette = FeedPalette.of(context);
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: Row(
            children: [
              IconButton(
                onPressed: Get.back,
                style: const ButtonStyle(
                  overlayColor: WidgetStatePropertyAll(Colors.transparent),
                  splashFactory: NoSplash.splashFactory,
                ),
                icon: Icon(Iconsax.arrow_left_2, color: palette.iconPrimary),
              ),
              Expanded(
                child: Text(
                  'Bài viết',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }
}
