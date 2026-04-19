import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/feed/post_detail_controller.dart';
import 'package:matchu_app/controllers/user/user_controller.dart';
import 'package:matchu_app/views/feed/widgets/comment_section_shimmer.dart';
import 'package:matchu_app/views/feed/widgets/comment_sort_dropdown.dart';
import 'package:matchu_app/views/feed/widgets/feed_palette.dart';
import 'package:matchu_app/views/feed/widgets/post_action_sheet.dart';
import 'package:matchu_app/views/feed/widgets/post_detail_comment_item.dart';
import 'package:matchu_app/views/feed/widgets/post_detail_post_card.dart';
import 'package:matchu_app/views/feed/widgets/post_ui_helpers.dart';

const double _kComposerFloatingGap = 10;
const double _kComposerListBottomPadding = 104;
const double _kComposerListBottomPaddingWithReply = 176;
const double _kPostDetailCommentsAutoLoadTriggerExtent = 360;

class PostDetailView extends StatefulWidget {
  const PostDetailView({super.key});

  @override
  State<PostDetailView> createState() => _PostDetailViewState();
}

class _PostDetailViewState extends State<PostDetailView> {
  late final PostDetailController controller;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    controller = Get.find<PostDetailController>();
    _scrollController = ScrollController()..addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;

    final commentsController = controller.commentsController;
    if (commentsController.isLoading.value ||
        commentsController.isLoadingMoreComments.value ||
        !commentsController.hasMoreComments.value) {
      return;
    }
    if (_scrollController.position.extentAfter >
        _kPostDetailCommentsAutoLoadTriggerExtent) {
      return;
    }

    commentsController.loadMoreComments();
  }

  @override
  Widget build(BuildContext context) {
    final palette = FeedPalette.of(context);

    return Scaffold(
      backgroundColor: palette.pageBackground,
      appBar: const _PostDetailAppBar(),
      body: Obx(() {
        final post = controller.post.value;
        final hasReplyTarget =
            controller.commentsController.replyingTo.value != null;
        final listBottomPadding =
            MediaQuery.paddingOf(context).bottom +
            (hasReplyTarget
                ? _kComposerListBottomPaddingWithReply
                : _kComposerListBottomPadding);

        return Stack(
          children: [
            Positioned.fill(
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                cacheExtent: 960,
                slivers: [
                  SliverToBoxAdapter(
                    child: PostDetailPostCard(
                      post: post,
                      onLikeTap: controller.toggleLike,
                      onCommentTap: controller.dismissCommentComposer,
                      onShareTap: controller.sharePost,
                      onMoreTap:
                          () => PostActionSheet.show(context, post: post),
                    ),
                  ),
                  _CommentsSliverSection(controller: controller),
                  SliverToBoxAdapter(
                    child: SizedBox(height: listBottomPadding),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _PostDetailComposer(controller: controller),
            ),
          ],
        );
      }),
    );
  }
}

class _CommentsSliverSection extends StatelessWidget {
  const _CommentsSliverSection({required this.controller});

  final PostDetailController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = FeedPalette.of(context);
    final commentsController = controller.commentsController;

    return Obx(() {
      if (commentsController.isLoading.value) {
        return const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: CommentSectionShimmer(
              variant: CommentShimmerVariant.detail,
              itemCount: 4,
            ),
          ),
        );
      }

      if (commentsController.errorMessage.value != null &&
          commentsController.comments.isEmpty) {
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              children: [
                Icon(
                  Iconsax.warning_2,
                  size: 30,
                  color: theme.colorScheme.error,
                ),
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
          ),
        );
      }

      if (commentsController.threadEntries.isEmpty) {
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
            child: Text(
              'Chưa có bình luận nào. Hãy mở đầu cuộc trò chuyện.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        );
      }

      final entries = commentsController.threadEntries.toList(growable: false);
      final showLoadMoreShimmer =
          commentsController.isLoadingMoreComments.value;

      return SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: CommentSortDropdown(
                  value: commentsController.sortMode.value,
                  onChanged: (value) {
                    if (value == null) return;
                    commentsController.updateSortMode(value);
                  },
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final entry = entries[index];
              final shouldShowDivider = index > 0 && entry.depth == 0;

              return Column(
                children: [
                  if (shouldShowDivider)
                    Divider(height: 1, thickness: 1, color: palette.border),
                  PostDetailCommentItem(
                    key: ValueKey(entry.comment.commentId),
                    entry: entry,
                    isReplyLoading: commentsController.isReplyLoading(
                      entry.comment.commentId,
                    ),
                    onLikeTap:
                        () => commentsController.toggleLike(entry.comment),
                    onReplyTap:
                        () => commentsController.startReply(entry.comment),
                    onToggleRepliesTap:
                        () => commentsController.toggleReplies(entry.comment),
                  ),
                ],
              );
            }, childCount: entries.length),
          ),
          if (showLoadMoreShimmer)
            const SliverToBoxAdapter(
              child: CommentLoadMoreShimmer(
                variant: CommentShimmerVariant.detail,
              ),
            ),
        ],
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
  static const double _kPillHeight = 50;
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
    final composerSurfaceColor = palette.pageBackground;
    final replySurface =
        Color.lerp(palette.surfaceMuted, palette.pageBackground, 0.28) ??
        palette.surfaceMuted;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomSafeInset = MediaQuery.paddingOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: keyboardInset + bottomSafeInset + _kComposerFloatingGap,
      ),
      child: Obx(() {
        final replyingTo = commentsController.replyingTo.value;
        final isSubmitting = commentsController.isSubmitting.value;
        final hasInputText = commentsController.hasInputText.value;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (replyingTo != null)
              _ComposerSurface(
                borderRadius: BorderRadius.circular(18),
                backgroundColor: replySurface.withValues(
                  alpha: isDark ? 0.92 : 0.96,
                ),
                borderColor: palette.border.withValues(alpha: 0.8),
                shadowColor: palette.shadowColor.withValues(
                  alpha: isDark ? 0.18 : 0.08,
                ),
                blurSigma: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 3,
                        height: replyingTo.content.trim().isEmpty ? 18 : 34,
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
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: palette.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (replyingTo.content.trim().isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                replyingTo.content.trim(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
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
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
            if (replyingTo != null) const SizedBox(height: 8),
            TextFieldTapRegion(
              child: _ComposerSurface(
                borderRadius: BorderRadius.circular(999),
                backgroundColor: composerSurfaceColor,
                borderColor: palette.border.withValues(
                  alpha: isDark ? 0.84 : 0.68,
                ),
                shadowColor: palette.shadowColor.withValues(
                  alpha: isDark ? 0.2 : 0.08,
                ),
                blurSigma: 0,
                child: SizedBox(
                  height: _kPillHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    child: Row(
                      children: [
                        if (userController != null)
                          Obx(
                            () => _ComposerAvatar(
                              imageUrl:
                                  userController.userRx.value?.avatarUrl ?? '',
                              fallbackLabel: _currentUserFallbackLabel(
                                userController,
                              ),
                              size: 30,
                              borderColor: palette.border,
                              backgroundColor: palette.surfaceMuted,
                              textColor: palette.textPrimary,
                            ),
                          )
                        else
                          _ComposerAvatar(
                            imageUrl: '',
                            fallbackLabel: 'Bạn',
                            size: 30,
                            borderColor: palette.border,
                            backgroundColor: palette.surfaceMuted,
                            textColor: palette.textPrimary,
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: commentsController.inputController,
                            focusNode: commentsController.inputFocusNode,
                            minLines: 1,
                            maxLines: 1,
                            textInputAction: TextInputAction.send,
                            textCapitalization: TextCapitalization.sentences,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: palette.textPrimary,
                              height: 1.15,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Bình luận...',
                              filled: false,
                              fillColor: Colors.transparent,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isCollapsed: true,
                              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                                color: palette.textTertiary,
                              ),
                            ),
                            onTapOutside:
                                (_) =>
                                    widget.controller.dismissCommentComposer(),
                            onSubmitted:
                                (_) => commentsController.submitComment(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.centerRight,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) {
                              final slideAnimation = Tween<Offset>(
                                begin: const Offset(0.18, 0),
                                end: Offset.zero,
                              ).animate(animation);
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: slideAnimation,
                                  child: child,
                                ),
                              );
                            },
                            child:
                                hasInputText
                                    ? _ComposerSubmitButton(
                                      key: const ValueKey(
                                        'composer_submit_button',
                                      ),
                                      isSubmitting: isSubmitting,
                                      onPressed:
                                          commentsController.submitComment,
                                      backgroundColor:
                                          theme.colorScheme.primary,
                                      foregroundColor:
                                          theme.colorScheme.onPrimary,
                                    )
                                    : Row(
                                      key: const ValueKey(
                                        'composer_media_actions',
                                      ),
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _ComposerActionButton(
                                          icon: Iconsax.gallery,
                                          color: palette.iconMuted,
                                          onPressed:
                                              isSubmitting
                                                  ? null
                                                  : _showImageCommentNotice,
                                        ),
                                        const SizedBox(width: 2),
                                        _ComposerActionButton(
                                          icon: Iconsax.emoji_happy,
                                          color: palette.iconMuted,
                                          onPressed:
                                              () => _openEmojiPicker(context),
                                        ),
                                      ],
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
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
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
      splashRadius: 17,
      icon: Icon(
        icon,
        size: 18,
        color: onPressed == null ? color.withValues(alpha: 0.38) : color,
      ),
    );
  }
}

class _ComposerSubmitButton extends StatelessWidget {
  const _ComposerSubmitButton({
    super.key,
    required this.isSubmitting,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final bool isSubmitting;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: FilledButton(
        onPressed: isSubmitting ? null : onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size(82, 34),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          elevation: 0,
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: backgroundColor.withValues(alpha: 0.62),
          disabledForegroundColor: foregroundColor.withValues(alpha: 0.92),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child:
              isSubmitting
                  ? SizedBox(
                    key: const ValueKey('composer_submit_loading'),
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foregroundColor,
                    ),
                  )
                  : const Row(
                    key: ValueKey('composer_submit_label'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Iconsax.send_1, size: 22),
                    ],
                  ),
        ),
      ),
    );
  }
}

class _ComposerSurface extends StatelessWidget {
  const _ComposerSurface({
    required this.borderRadius,
    required this.backgroundColor,
    required this.borderColor,
    required this.shadowColor,
    required this.child,
    this.blurSigma = 14,
  });

  final BorderRadius borderRadius;
  final Color backgroundColor;
  final Color borderColor;
  final Color shadowColor;
  final Widget child;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      borderRadius: borderRadius,
      boxShadow: [
        BoxShadow(
          color: shadowColor,
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor),
      ),
      child: child,
    );

    return DecoratedBox(
      decoration: decoration,
      child: ClipRRect(
        borderRadius: borderRadius,
        child:
            blurSigma <= 0
                ? content
                : BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: blurSigma,
                    sigmaY: blurSigma,
                  ),
                  child: content,
                ),
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
        color: palette.pageBackground,
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
