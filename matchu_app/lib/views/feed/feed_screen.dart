import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/feed/feed_controller.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/views/feed/create_post_sheet.dart';
import 'package:matchu_app/views/feed/post_comments_sheet.dart';
import 'package:matchu_app/views/feed/widgets/feed_empty_state.dart';
import 'package:matchu_app/views/feed/widgets/feed_error_state.dart';
import 'package:matchu_app/views/feed/widgets/feed_header.dart';
import 'package:matchu_app/views/feed/widgets/feed_palette.dart';
import 'package:matchu_app/views/feed/widgets/feed_shimmer.dart';
import 'package:matchu_app/views/feed/widgets/post_item.dart';

class FeedScreen extends GetView<FeedController> {
  const FeedScreen({super.key});

  Future<void> _openCreatePostSheet(BuildContext context) async {
    final createdPost = await CreatePostSheet.show(context);
    if (createdPost == null) return;

    if (createdPost.isPublic) {
      controller.prependPost(createdPost);
      return;
    }

    Get.snackbar(
      'Thong bao',
      'Bai viet duoc tao o che do rieng tu nen se khong hien trong feed cong khai.',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
    );
  }

  Future<void> _openCommentsSheet(BuildContext context, PostModel post) {
    return PostCommentsSheet.show(
      context,
      post: post,
      onCommentCountChanged:
          (delta) => controller.adjustCommentCount(post.postId, delta: delta),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = FeedPalette.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: palette.pageBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Obx(
              () => FeedHeader(
                isRefreshing: controller.isRefreshing.value,
                onRefresh: controller.refreshFeed,
                onCreatePost: () => _openCreatePostSheet(context),
              ),
            ),
            Expanded(
              child: Obx(() {
                final status = controller.status.value;

                if ((status == FeedStatus.initial ||
                        status == FeedStatus.loading) &&
                    controller.posts.isEmpty) {
                  return const FeedShimmer();
                }

                if (status == FeedStatus.error && controller.posts.isEmpty) {
                  return _FeedStateScrollView(
                    onRefresh: controller.refreshFeed,
                    children: [
                      const SizedBox(height: 72),
                      FeedErrorState(
                        message:
                            controller.errorMessage.value ??
                            'Da xay ra loi khi tai bang tin.',
                        onRetry: controller.loadInitialFeed,
                      ),
                    ],
                  );
                }

                if (status == FeedStatus.empty) {
                  return _FeedStateScrollView(
                    onRefresh: controller.refreshFeed,
                    children: [
                      const SizedBox(height: 72),
                      FeedEmptyState(onRefresh: controller.refreshFeed),
                    ],
                  );
                }

                final itemCount =
                    controller.posts.length +
                    (controller.isLoadingMore.value ? 1 : 0);

                return RefreshIndicator(
                  onRefresh: controller.refreshFeed,
                  color: theme.colorScheme.primary,
                  backgroundColor: palette.surface,
                  child: ListView.builder(
                    controller: controller.scrollController,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(0, 12, 0, 120),
                    itemCount: itemCount,
                    itemBuilder: (context, index) {
                      final postIndex = index;
                      if (postIndex >= controller.posts.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.3,
                              ),
                            ),
                          ),
                        );
                      }

                      final post = controller.posts[postIndex];

                      return Column(
                        children: [
                          if (postIndex > 0)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 68,
                                right: 16,
                              ),
                              child: Divider(
                                height: 1,
                                thickness: 1,
                                color: palette.border,
                              ),
                            ),
                          PostItem(
                            key: ValueKey(post.postId),
                            post: post,
                            onLikeTap: () => controller.toggleLike(post.postId),
                            onCommentTap:
                                () => _openCommentsSheet(context, post),
                            onShareTap: controller.onShareTap,
                          ),
                        ],
                      );
                    },
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedStateScrollView extends StatelessWidget {
  const _FeedStateScrollView({required this.onRefresh, required this.children});

  final Future<void> Function() onRefresh;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 120),
        children: children,
      ),
    );
  }
}
