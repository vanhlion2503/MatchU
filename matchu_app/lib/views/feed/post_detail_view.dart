import 'package:flutter/material.dart';
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
              onCommentTap:
                  () =>
                      controller.commentsController.inputFocusNode
                          .requestFocus(),
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
                child: const Text('Thu lai'),
              ),
            ],
          ),
        );
      }

      if (commentsController.threadEntries.isEmpty) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
          child: Text(
            'Chua co binh luan nao. Hay mo dau cuoc tro chuyen.',
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: palette.border,
                  ),
                ),
              PostDetailCommentItem(
                entry: entry,
                onReplyTap: () => commentsController.startReply(entry.comment),
              ),
            ],
          );
        },
      );
    });
  }
}

class _PostDetailComposer extends StatelessWidget {
  const _PostDetailComposer({required this.controller});

  final PostDetailController controller;

  @override
  Widget build(BuildContext context) {
    final palette = FeedPalette.of(context);
    final theme = Theme.of(context);
    final commentsController = controller.commentsController;
    final userController =
        Get.isRegistered<UserController>() ? Get.find<UserController>() : null;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surface.withValues(alpha: 0.98),
          border: Border(top: BorderSide(color: palette.border)),
        ),
        child: SafeArea(
          top: false,
          child: Obx(() {
            final replyingTo = commentsController.replyingTo.value;
            final canSubmit =
                commentsController.hasInputText.value &&
                !commentsController.isSubmitting.value;
            final hintText =
                replyingTo != null
                    ? 'Tra loi ${replyingTo.author?.displayName ?? 'nguoi dung'}...'
                    : 'Tra loi ${postAuthorName(controller.post.value)}...';

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (replyingTo != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Dang tra loi ${replyingTo.author?.displayName ?? 'nguoi dung'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: commentsController.cancelReply,
                          visualDensity: VisualDensity.compact,
                          style: const ButtonStyle(
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (userController != null)
                        Obx(
                          () => FeedAvatar(
                            imageUrl:
                                userController.userRx.value?.avatarUrl ?? '',
                            fallbackLabel: _currentUserFallbackLabel(
                              userController,
                            ),
                            size: 34,
                            borderColor: palette.border,
                          ),
                        )
                      else
                        FeedAvatar(
                          imageUrl: '',
                          fallbackLabel: 'You',
                          size: 34,
                          borderColor: palette.border,
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: palette.inputSurface,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: palette.border),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller:
                                      commentsController.inputController,
                                  focusNode: commentsController.inputFocusNode,
                                  minLines: 1,
                                  maxLines: 4,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  decoration: InputDecoration(
                                    hintText: hintText,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    filled: false,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.fromLTRB(
                                      16,
                                      12,
                                      8,
                                      12,
                                    ),
                                    hintStyle: theme.textTheme.bodySmall
                                        ?.copyWith(color: palette.textTertiary),
                                  ),
                                  onSubmitted: (_) {
                                    if (!canSubmit) return;
                                    commentsController.submitComment();
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(0, 6, 6, 6),
                                child: TextButton(
                                  onPressed:
                                      canSubmit
                                          ? commentsController.submitComment
                                          : null,
                                  style: TextButton.styleFrom(
                                    foregroundColor: theme.colorScheme.primary,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    textStyle: theme.textTheme.bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  child:
                                      commentsController.isSubmitting.value
                                          ? SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              color: theme.colorScheme.primary,
                                            ),
                                          )
                                          : const Text('Post'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
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

  return 'You';
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
                  'Post',
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
