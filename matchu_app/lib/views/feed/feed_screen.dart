import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/feed/feed_controller.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/views/feed/create_post_sheet.dart';
import 'package:matchu_app/views/feed/post_comments_sheet.dart';
import 'package:matchu_app/views/feed/widgets/feed_create_entry_card.dart';
import 'package:matchu_app/views/feed/widgets/feed_empty_state.dart';
import 'package:matchu_app/views/feed/widgets/feed_error_state.dart';
import 'package:matchu_app/views/feed/widgets/feed_header.dart';
import 'package:matchu_app/views/feed/widgets/feed_shimmer.dart';
import 'package:matchu_app/views/feed/widgets/post_item.dart';

class FeedScreen extends GetView<FeedController> {
  const FeedScreen({super.key});

  Future<void> _openCreatePostSheet(BuildContext context) async {
    final createdPost = await CreatePostSheet.show(context);
    if (createdPost == null) return;

    if (createdPost.isPublic) {
      controller.prependPost(createdPost);
    } else {
      Get.snackbar(
        'Thong bao',
        'Bai viet da duoc tao o che do rieng tu nen se khong hien trong feed cong khai.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    }
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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Obx(
              () => FeedHeader(
                isRefreshing: controller.isRefreshing.value,
                onRefresh: controller.refreshFeed,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: FeedCreateEntryCard(
                onTap: () => _openCreatePostSheet(context),
              ),
            ),
            Expanded(
              child: Obx(() {
                final status = controller.status.value;

                if (status == FeedStatus.loading && controller.posts.isEmpty) {
                  return const FeedShimmer();
                }

                if (status == FeedStatus.error && controller.posts.isEmpty) {
                  return FeedErrorState(
                    message:
                        controller.errorMessage.value ??
                        'Da xay ra loi khi tai bang tin.',
                    onRetry: controller.loadInitialFeed,
                  );
                }

                if (status == FeedStatus.empty) {
                  return FeedEmptyState(onRefresh: controller.refreshFeed);
                }

                return RefreshIndicator(
                  onRefresh: controller.refreshFeed,
                  child: ListView.separated(
                    controller: controller.scrollController,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    itemCount:
                        controller.posts.length +
                        (controller.isLoadingMore.value ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      if (index >= controller.posts.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          ),
                        );
                      }

                      final post = controller.posts[index];

                      return PostItem(
                        key: ValueKey(post.postId),
                        post: post,
                        onLikeTap: () => controller.toggleLike(post.postId),
                        onCommentTap: () => _openCommentsSheet(context, post),
                        onShareTap: controller.onShareTap,
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
