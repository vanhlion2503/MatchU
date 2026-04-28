import 'dart:async';

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
import 'package:matchu_app/views/profile/other_profile_view.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen>
    with SingleTickerProviderStateMixin {
  static const double _loadMoreThreshold = 640;

  late final FeedController controller;
  late final TabController _tabController;
  final ScrollController _latestScrollController = ScrollController();
  final ScrollController _featuredScrollController = ScrollController();
  final ScrollController _followingScrollController = ScrollController();
  int _lastSyncedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    controller = Get.find<FeedController>();
    final initialIndex = switch (controller.activeTimeline.value) {
      FeedTimeline.featured => 0,
      FeedTimeline.latest => 1,
      FeedTimeline.following => 2,
    };
    _lastSyncedTabIndex = initialIndex;
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabController.addListener(_handleTabControllerChanged);
    _latestScrollController.addListener(_handleLatestScroll);
    _featuredScrollController.addListener(_handleFeaturedScroll);
    _followingScrollController.addListener(_handleFollowingScroll);
  }

  @override
  void dispose() {
    _latestScrollController.removeListener(_handleLatestScroll);
    _featuredScrollController.removeListener(_handleFeaturedScroll);
    _followingScrollController.removeListener(_handleFollowingScroll);
    _tabController.removeListener(_handleTabControllerChanged);
    _latestScrollController.dispose();
    _featuredScrollController.dispose();
    _followingScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabControllerChanged() {
    if (_tabController.indexIsChanging) return;
    final tabIndex = _tabController.index;
    if (tabIndex == _lastSyncedTabIndex) return;
    _lastSyncedTabIndex = tabIndex;
    unawaited(_syncTimelineWithTab(tabIndex));
  }

  void _handleLatestScroll() {
    if (!_latestScrollController.hasClients) return;
    if (_latestScrollController.position.extentAfter <= _loadMoreThreshold) {
      unawaited(controller.loadMore());
    }
  }

  void _handleFeaturedScroll() {
    if (!_featuredScrollController.hasClients) return;
    if (_featuredScrollController.position.extentAfter <= _loadMoreThreshold) {
      unawaited(controller.loadMoreFeaturedFeed());
    }
  }

  void _handleFollowingScroll() {
    if (!_followingScrollController.hasClients) return;
    if (_followingScrollController.position.extentAfter <= _loadMoreThreshold) {
      unawaited(controller.loadMoreFollowingFeed());
    }
  }

  Future<void> _syncTimelineWithTab(int index) {
    final timeline = switch (index) {
      0 => FeedTimeline.featured,
      1 => FeedTimeline.latest,
      _ => FeedTimeline.following,
    };
    return controller.selectTimeline(timeline);
  }

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
      'Thong bao',
      'Bai viet o che do rieng tu se khong hien thi trong bang tin cong khai.',
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

  void _openAuthorProfile(String rawUserId) {
    final userId = rawUserId.trim();
    if (userId.isEmpty) return;
    Get.to(() => OtherProfileView(userId: userId));
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
    final canHidePost = controller.canHidePostFromFeed(post);

    return PostActionSheet.show(
      context,
      post: post,
      isSaved: post.isSaved,
      onSaveTap: () => controller.toggleSave(post.postId),
      canHidePost: canHidePost,
      onHidePostTap:
          canHidePost ? () => controller.hidePostFromFeed(post) : null,
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
        preferredSize: const Size.fromHeight(kToolbarHeight + 46 + 6),
        child: Obx(
          () => FeedAppBar(
            isRefreshing: controller.visibleIsRefreshing,
            onRefresh: controller.refreshActiveFeed,
            tabController: _tabController,
            onTabTap: (index) {
              _lastSyncedTabIndex = index;
              unawaited(_syncTimelineWithTab(index));
            },
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: bottomInset + 80),
        child: FloatingActionButton(
          heroTag: 'feed_create_post_fab',
          tooltip: 'Tao bai viet',
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          onPressed: () => _openCreatePostSheet(context),
          child: const Icon(Iconsax.edit_2),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const BouncingScrollPhysics(),
        children: [
          Obx(
            () => _FeedTimelineBody(
              controller: controller,
              posts: controller.featuredPosts.toList(growable: false),
              status: controller.featuredStatus.value,
              isLoadingMore: controller.featuredIsLoadingMore.value,
              hasMore: controller.featuredHasMore.value,
              errorMessage: controller.featuredErrorMessage.value,
              scrollController: _featuredScrollController,
              storageKey: const PageStorageKey<String>('feed_featured_posts'),
              onRefresh: controller.refreshFeaturedFeed,
              onLoadMore: controller.loadMoreFeaturedFeed,
              onRetry: controller.loadInitialFeaturedFeed,
              onPostTap: _openPostDetail,
              onLikeTap: (postId) => controller.toggleLike(postId),
              onCommentTap: _openPostDetail,
              onRepostTap: (post) => _openRepostSheet(context, post),
              onShareTap: controller.onShareTap,
              onMoreTap: (post) => _openPostActionSheet(context, post),
              onAuthorTap: _openAuthorProfile,
              onReferenceAuthorTap: _openAuthorProfile,
              onReferenceTap: (post) {
                if (post.referencePost == null) return;
                _openReferencePostDetail(post);
              },
            ),
          ),
          Obx(
            () => _FeedTimelineBody(
              controller: controller,
              posts: controller.posts.toList(growable: false),
              status: controller.status.value,
              isLoadingMore: controller.isLoadingMore.value,
              hasMore: controller.hasMore.value,
              errorMessage: controller.errorMessage.value,
              scrollController: _latestScrollController,
              storageKey: const PageStorageKey<String>('feed_latest_posts'),
              onRefresh: controller.refreshFeed,
              onLoadMore: controller.loadMore,
              onRetry: controller.loadInitialFeed,
              onPostTap: _openPostDetail,
              onLikeTap: (postId) => controller.toggleLike(postId),
              onCommentTap: _openPostDetail,
              onRepostTap: (post) => _openRepostSheet(context, post),
              onShareTap: controller.onShareTap,
              onMoreTap: (post) => _openPostActionSheet(context, post),
              onAuthorTap: _openAuthorProfile,
              onReferenceAuthorTap: _openAuthorProfile,
              onReferenceTap: (post) {
                if (post.referencePost == null) return;
                _openReferencePostDetail(post);
              },
            ),
          ),
          Obx(
            () => _FeedTimelineBody(
              controller: controller,
              posts: controller.followingPosts.toList(growable: false),
              status: controller.followingStatus.value,
              isLoadingMore: controller.followingIsLoadingMore.value,
              hasMore: controller.followingHasMore.value,
              errorMessage: controller.followingErrorMessage.value,
              scrollController: _followingScrollController,
              storageKey: const PageStorageKey<String>('feed_following_posts'),
              onRefresh: controller.refreshFollowingFeed,
              onLoadMore: controller.loadMoreFollowingFeed,
              onRetry: controller.loadInitialFollowingFeed,
              emptyTitle: 'Chua co bai viet tu nguoi ban theo doi.',
              emptyDescription:
                  'Hay theo doi them nguoi dung hoac keo xuong de lam moi bang tin.',
              onPostTap: _openPostDetail,
              onLikeTap: (postId) => controller.toggleLike(postId),
              onCommentTap: _openPostDetail,
              onRepostTap: (post) => _openRepostSheet(context, post),
              onShareTap: controller.onShareTap,
              onMoreTap: (post) => _openPostActionSheet(context, post),
              onAuthorTap: _openAuthorProfile,
              onReferenceAuthorTap: _openAuthorProfile,
              onReferenceTap: (post) {
                if (post.referencePost == null) return;
                _openReferencePostDetail(post);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedTimelineBody extends StatefulWidget {
  const _FeedTimelineBody({
    required this.controller,
    required this.posts,
    required this.status,
    required this.isLoadingMore,
    required this.hasMore,
    required this.errorMessage,
    required this.scrollController,
    required this.storageKey,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onRetry,
    required this.onPostTap,
    required this.onLikeTap,
    required this.onCommentTap,
    required this.onRepostTap,
    required this.onShareTap,
    required this.onMoreTap,
    this.emptyTitle,
    this.emptyDescription,
    this.onAuthorTap,
    this.onReferenceAuthorTap,
    this.onReferenceTap,
  });

  final FeedController controller;
  final List<PostModel> posts;
  final FeedStatus status;
  final bool isLoadingMore;
  final bool hasMore;
  final String? errorMessage;
  final ScrollController scrollController;
  final PageStorageKey<String> storageKey;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;
  final Future<void> Function() onRetry;
  final ValueChanged<PostModel> onPostTap;
  final ValueChanged<String> onLikeTap;
  final ValueChanged<PostModel> onCommentTap;
  final ValueChanged<PostModel> onRepostTap;
  final VoidCallback onShareTap;
  final ValueChanged<PostModel> onMoreTap;
  final String? emptyTitle;
  final String? emptyDescription;
  final ValueChanged<String>? onAuthorTap;
  final ValueChanged<String>? onReferenceAuthorTap;
  final ValueChanged<PostModel>? onReferenceTap;

  @override
  State<_FeedTimelineBody> createState() => _FeedTimelineBodyState();
}

class _FeedTimelineBodyState extends State<_FeedTimelineBody> {
  static const double _loadMoreThreshold = 640;

  @override
  void initState() {
    super.initState();
    _scheduleViewportLoadMoreCheck();
  }

  @override
  void didUpdateWidget(covariant _FeedTimelineBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.posts.length != widget.posts.length ||
        oldWidget.status != widget.status ||
        (oldWidget.isLoadingMore && !widget.isLoadingMore) ||
        oldWidget.hasMore != widget.hasMore) {
      _scheduleViewportLoadMoreCheck();
    }
  }

  void _scheduleViewportLoadMoreCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeLoadMore();
    });
  }

  void _maybeLoadMore({ScrollMetrics? metrics}) {
    if (!mounted ||
        !widget.hasMore ||
        widget.isLoadingMore ||
        widget.status != FeedStatus.success) {
      return;
    }

    final extentAfter =
        metrics?.extentAfter ??
        (widget.scrollController.hasClients
            ? widget.scrollController.position.extentAfter
            : null);
    if (extentAfter == null || extentAfter > _loadMoreThreshold) {
      return;
    }

    unawaited(widget.onLoadMore());
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }

    _maybeLoadMore(metrics: notification.metrics);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if ((widget.status == FeedStatus.initial ||
            widget.status == FeedStatus.loading) &&
        widget.posts.isEmpty) {
      return const FeedShimmer();
    }

    if (widget.status == FeedStatus.error && widget.posts.isEmpty) {
      return _FeedStateScrollView(
        onRefresh: widget.onRefresh,
        children: [
          const SizedBox(height: 72),
          FeedErrorState(
            message: widget.errorMessage ?? 'Da xay ra loi khi tai bang tin.',
            onRetry: widget.onRetry,
          ),
        ],
      );
    }

    if (widget.status == FeedStatus.empty) {
      return _FeedStateScrollView(
        onRefresh: widget.onRefresh,
        children: [
          const SizedBox(height: 72),
          FeedEmptyState(
            onRefresh: widget.onRefresh,
            title: widget.emptyTitle,
            description: widget.emptyDescription,
          ),
        ],
      );
    }

    final palette = FeedPalette.of(context);
    final theme = Theme.of(context);
    final itemCount = widget.posts.length + (widget.isLoadingMore ? 1 : 0);

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: RefreshIndicator(
        onRefresh: widget.onRefresh,
        color: theme.colorScheme.primary,
        backgroundColor: palette.surface,
        child: ListView.builder(
          key: widget.storageKey,
          controller: widget.scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 120),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            if (index >= widget.posts.length) {
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

            final post = widget.posts[index];

            return _FeedRemovalAnimatedPostItem(
              key: ValueKey('feed_post_${post.postId}'),
              controller: widget.controller,
              post: post,
              showDivider: index > 0,
              onTap: () => widget.onPostTap(post),
              onLikeTap: () => widget.onLikeTap(post.postId),
              onCommentTap: () => widget.onCommentTap(post),
              onRepostTap: () => widget.onRepostTap(post),
              onShareTap: widget.onShareTap,
              onMoreTap: () => widget.onMoreTap(post),
              onAuthorTap: widget.onAuthorTap,
              onReferenceAuthorTap: widget.onReferenceAuthorTap,
              onReferenceTap:
                  widget.onReferenceTap == null
                      ? null
                      : () => widget.onReferenceTap!(post),
            );
          },
        ),
      ),
    );
  }
}

class _FeedRemovalAnimatedPostItem extends StatelessWidget {
  const _FeedRemovalAnimatedPostItem({
    super.key,
    required this.controller,
    required this.post,
    required this.showDivider,
    required this.onTap,
    required this.onLikeTap,
    required this.onCommentTap,
    required this.onRepostTap,
    required this.onShareTap,
    required this.onMoreTap,
    this.onAuthorTap,
    this.onReferenceAuthorTap,
    this.onReferenceTap,
  });

  final FeedController controller;
  final PostModel post;
  final bool showDivider;
  final VoidCallback onTap;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;
  final VoidCallback onRepostTap;
  final VoidCallback onShareTap;
  final VoidCallback onMoreTap;
  final ValueChanged<String>? onAuthorTap;
  final ValueChanged<String>? onReferenceAuthorTap;
  final VoidCallback? onReferenceTap;

  @override
  Widget build(BuildContext context) {
    final palette = FeedPalette.of(context);

    return Obx(() {
      final isRemoving = controller.isPostRemoving(post.postId);

      return AnimatedSwitcher(
        duration: controller.postRemovalAnimationDuration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return SizeTransition(
            sizeFactor: animation,
            axisAlignment: -1,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child:
            isRemoving
                ? SizedBox(key: ValueKey('feed_post_removing_${post.postId}'))
                : Column(
                  key: ValueKey('feed_post_visible_${post.postId}'),
                  children: [
                    if (showDivider)
                      Divider(height: 1, thickness: 1, color: palette.border),
                    PostItem(
                      key: ValueKey(post.postId),
                      post: post,
                      onTap: onTap,
                      onLikeTap: onLikeTap,
                      onCommentTap: onCommentTap,
                      onRepostTap: onRepostTap,
                      onShareTap: onShareTap,
                      onMoreTap: onMoreTap,
                      onAuthorTap: onAuthorTap,
                      onReferenceAuthorTap: onReferenceAuthorTap,
                      onReferenceTap: onReferenceTap,
                    ),
                  ],
                ),
      );
    });
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
