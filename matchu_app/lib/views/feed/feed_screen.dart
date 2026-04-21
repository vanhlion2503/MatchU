import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/feed/feed_controller.dart';
import 'package:matchu_app/controllers/feed/post_creation_sync.dart';
import 'package:matchu_app/models/feed/post_detail_route_args.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/models/feed/stats_model.dart';
import 'package:matchu_app/routes/app_router.dart';
import 'package:matchu_app/views/feed/create_post_sheet.dart';
import 'package:matchu_app/views/feed/widgets/feed_empty_state.dart';
import 'package:matchu_app/views/feed/widgets/feed_error_state.dart';
import 'package:matchu_app/views/feed/widgets/feed_header.dart';
import 'package:matchu_app/views/feed/widgets/feed_palette.dart';
import 'package:matchu_app/views/feed/widgets/feed_shimmer.dart';
import 'package:matchu_app/views/feed/widgets/post_action_sheet.dart';
import 'package:matchu_app/views/feed/widgets/post_item.dart';
import 'package:matchu_app/views/feed/widgets/post_repost_sheet.dart';

class FeedScreen extends GetView<FeedController> {
  const FeedScreen({super.key});

  Future<void> _openCreatePostSheet(BuildContext context) async {
    final createdPost = await CreatePostSheet.show(context);
    _handlePostCreated(createdPost);
  }

  Future<void> _quotePost(BuildContext context, PostModel sourcePost) async {
    final createdPost = await CreatePostSheet.show(
      context,
      quotedPost: sourcePost,
    );
    _handlePostCreated(createdPost);
  }

  Future<void> _repostPost(PostModel sourcePost) async {
    final createdPost = await controller.repostPost(sourcePost);
    _handlePostCreated(createdPost);
  }

  Future<void> _undoRepostPost(PostModel sourcePost) async {
    final removedPost = await controller.undoRepost(sourcePost);
    _handlePostRemoved(removedPost);
  }

  Future<void> _deletePost(PostModel post) async {
    final deletedPost = await controller.deletePost(post);
    _handlePostDeleted(deletedPost);
  }

  void _handlePostCreated(PostModel? createdPost) {
    if (createdPost == null) return;

    PostCreationSync.sync(createdPost);
    if (createdPost.isPublic) return;

    Get.snackbar(
      'Thông báo',
      'Bài viết ở chế độ riêng tư sẽ không hiển thị trong bảng tin công khai.',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
    );
  }

  void _handlePostRemoved(PostModel? removedPost) {
    if (removedPost == null) return;
    PostCreationSync.syncRepostRemoved(removedPost);
  }

  void _handlePostDeleted(PostModel? deletedPost) {
    if (deletedPost == null) return;
    PostCreationSync.syncPostDeleted(deletedPost);
  }

  Future<void> _openPostDetail(PostModel post) async {
    Get.toNamed(
      AppRouter.postDetail,
      arguments: PostDetailRouteArgs(post: post),
    );
  }

  Future<void> _openReferencePostDetail(PostModel sourcePost) async {
    final resolvedPost = await _resolvePostDetailPost(sourcePost);
    await Get.toNamed(
      AppRouter.postDetail,
      arguments: PostDetailRouteArgs(post: resolvedPost),
    );
  }

  Future<PostModel> _resolvePostDetailPost(PostModel tappedPost) async {
    if (!tappedPost.postType.requiresReference ||
        tappedPost.referencePost == null) {
      return tappedPost;
    }

    final reference = tappedPost.referencePost;
    final referencePostId =
        (tappedPost.referencePostId ?? reference?.postId ?? '').trim();

    if (referencePostId.isEmpty || reference?.isUnavailable == true) {
      return tappedPost;
    }

    final localOriginal = controller.findPostById(referencePostId);
    if (localOriginal != null) {
      return localOriginal;
    }

    final fetchedOriginal = await controller.fetchPostById(referencePostId);
    if (fetchedOriginal != null) {
      return fetchedOriginal;
    }

    return _fallbackOriginalPostFromReference(reference) ?? tappedPost;
  }

  PostModel? _fallbackOriginalPostFromReference(PostReferenceModel? reference) {
    if (reference == null) return null;

    final postId = reference.postId.trim();
    if (postId.isEmpty) return null;

    return PostModel(
      postId: postId,
      authorId: reference.authorId,
      postType: reference.postType,
      content: reference.content,
      media: reference.media,
      tags: reference.tags,
      isPublic: reference.isPublic,
      stats: const StatsModel(),
      trendScore: 0,
      trendBucket: 0,
      author: reference.author,
      createdAt: reference.createdAt,
      updatedAt: reference.createdAt,
      deletedAt: reference.deletedAt,
    );
  }

  Future<void> _openPostActionSheet(BuildContext context, PostModel post) {
    final currentUserId = controller.currentUserId.trim();
    final canDeletePost =
        currentUserId.isNotEmpty && post.authorId.trim() == currentUserId;

    return PostActionSheet.show(
      context,
      post: post,
      canDeletePost: canDeletePost,
      onDeleteTap: canDeletePost ? () => _deletePost(post) : null,
    );
  }

  Future<void> _openRepostSheet(BuildContext context, PostModel post) {
    return PostRepostSheet.show(
      context,
      post: post,
      onRepostTap: () => _repostPost(post),
      onUndoRepostTap: () => _undoRepostPost(post),
      onQuoteTap: () => _quotePost(context, post),
    );
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
                    onRepostTap: () => _openRepostSheet(context, post),
                    onShareTap: controller.onShareTap,
                    onMoreTap: () => _openPostActionSheet(context, post),
                    onReferenceTap:
                        post.referencePost != null
                            ? () => _openReferencePostDetail(post)
                            : null,
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
