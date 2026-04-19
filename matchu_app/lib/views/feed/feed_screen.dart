import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/feed/feed_controller.dart';
import 'package:matchu_app/controllers/feed/post_creation_sync.dart';
import 'package:matchu_app/models/feed/post_detail_route_args.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/routes/app_router.dart';
import 'package:matchu_app/views/feed/create_post_sheet.dart';
import 'package:matchu_app/views/feed/widgets/feed_empty_state.dart';
import 'package:matchu_app/views/feed/widgets/feed_error_state.dart';
import 'package:matchu_app/views/feed/widgets/feed_header.dart';
import 'package:matchu_app/views/feed/widgets/feed_palette.dart';
import 'package:matchu_app/views/feed/widgets/feed_shimmer.dart';
import 'package:matchu_app/views/feed/widgets/post_action_sheet.dart';
import 'package:matchu_app/views/feed/widgets/post_item.dart';

class FeedScreen extends GetView<FeedController> {
  const FeedScreen({super.key});

  Future<void> _openCreatePostSheet(BuildContext context) async {
    final createdPost = await CreatePostSheet.show(context);
    if (createdPost == null) return;

    PostCreationSync.sync(createdPost);
    if (createdPost.isPublic) return;

    Get.snackbar(
      'Thông báo',
      'Bài viết được tạo ở chế độ riêng tư nên sẽ không hiển thị trong bảng tin công khai.',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
    );
  }

  void _openPostDetail(PostModel post) {
    Get.toNamed(
      AppRouter.postDetail,
      arguments: PostDetailRouteArgs(post: post),
    );
  }

  Future<void> _openPostActionSheet(BuildContext context, PostModel post) {
    return PostActionSheet.show(context, post: post);
  }

  @override
  Widget build(BuildContext context) {
    final palette = FeedPalette.of(context);
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: palette.pageBackground,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 6),
        child: Obx(
          () => FeedAppBar(
            isRefreshing: controller.isRefreshing.value,
            onRefresh: controller.refreshFeed,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: bottomInset + 80),
        child: FloatingActionButton(
          heroTag: 'feed_create_post_fab',
          tooltip: 'Tạo bài viết',
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          onPressed: () => _openCreatePostSheet(context),
          child: const Icon(Iconsax.edit_2),
        ),
      ),
      body: Obx(() {
        final status = controller.status.value;

        if ((status == FeedStatus.initial || status == FeedStatus.loading) &&
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
                    'Đã xảy ra lỗi khi tải bảng tin.',
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
            controller.posts.length + (controller.isLoadingMore.value ? 1 : 0);

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
                      child: CircularProgressIndicator(strokeWidth: 2.3),
                    ),
                  ),
                );
              }

              final post = controller.posts[postIndex];

              return Column(
                children: [
                  if (postIndex > 0)
                    Divider(height: 1, thickness: 1, color: palette.border),
                  PostItem(
                    key: ValueKey(post.postId),
                    post: post,
                    onTap: () => _openPostDetail(post),
                    onLikeTap: () => controller.toggleLike(post.postId),
                    onCommentTap: () => _openPostDetail(post),
                    onShareTap: controller.onShareTap,
                    onMoreTap: () => _openPostActionSheet(context, post),
                  ),
                ],
              );
            },
          ),
        );
      }),
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
