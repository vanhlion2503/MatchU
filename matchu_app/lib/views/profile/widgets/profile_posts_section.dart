import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/feed/feed_controller.dart';
import 'package:matchu_app/controllers/feed/post_creation_sync.dart';
import 'package:matchu_app/controllers/profile/profile_posts_controller.dart';
import 'package:matchu_app/models/feed/post_detail_route_args.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/models/feed/stats_model.dart';
import 'package:matchu_app/routes/app_router.dart';
import 'package:matchu_app/views/feed/create_post_sheet.dart';
import 'package:matchu_app/views/feed/widgets/feed_palette.dart';
import 'package:matchu_app/views/feed/widgets/post_action_sheet.dart';
import 'package:matchu_app/views/feed/widgets/post_item.dart';
import 'package:matchu_app/views/feed/widgets/post_repost_sheet.dart';
import 'package:matchu_app/views/profile/other_profile_view.dart';

class ProfilePostsSection extends StatefulWidget {
  const ProfilePostsSection({
    super.key,
    required this.controllerTag,
    required this.isOwnerView,
    this.savedControllerTag,
  });

  final String controllerTag;
  final bool isOwnerView;
  final String? savedControllerTag;

  @override
  State<ProfilePostsSection> createState() => _ProfilePostsSectionState();
}

class _ProfilePostsSectionState extends State<ProfilePostsSection>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool get _showSavedTab =>
      widget.isOwnerView && (widget.savedControllerTag?.isNotEmpty ?? false);

  int get _tabCount => _showSavedTab ? 3 : 2;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this)
      ..addListener(_handleTabChanged);
  }

  @override
  void didUpdateWidget(covariant ProfilePostsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldShowSavedTab =
        oldWidget.isOwnerView &&
        (oldWidget.savedControllerTag?.isNotEmpty ?? false);
    final newShowSavedTab = _showSavedTab;
    if (oldShowSavedTab == newShowSavedTab) {
      return;
    }

    final nextLength = _tabCount;
    final nextIndex = _tabController.index.clamp(0, nextLength - 1).toInt();
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    _tabController = TabController(
      length: nextLength,
      vsync: this,
      initialIndex: nextIndex,
    )..addListener(_handleTabChanged);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final postsController = Get.find<ProfilePostsController>(
      tag: widget.controllerTag,
    );
    final savedControllerTag = widget.savedControllerTag;
    final savedController =
        _showSavedTab &&
                savedControllerTag != null &&
                Get.isRegistered<ProfilePostsController>(
                  tag: savedControllerTag,
                )
            ? Get.find<ProfilePostsController>(tag: savedControllerTag)
            : null;
    final canShowSavedTab = _showSavedTab && savedController != null;
    final palette = FeedPalette.of(context);
    final theme = Theme.of(context);

    return Obx(() {
      final authoredStatus = postsController.status.value;
      final allPosts = postsController.posts.toList(growable: false);
      final normalPosts = allPosts
          .where((post) => !post.isRepostOnly)
          .toList(growable: false);
      final repostPosts = allPosts
          .where((post) => post.isRepostOnly)
          .toList(growable: false);
      final savedStatus = savedController?.status.value;
      final savedPosts = savedController?.posts.toList(growable: false);
      final tabIndex = _tabController.index;
      final resolvedSavedController = savedController;
      final resolvedSavedControllerTag = savedControllerTag;

      final activeController =
          canShowSavedTab && tabIndex == 2
              ? (resolvedSavedController ?? postsController)
              : postsController;
      final activeStatus =
          canShowSavedTab && tabIndex == 2
              ? savedStatus ?? ProfilePostsStatus.initial
              : authoredStatus;
      final activePosts =
          canShowSavedTab && tabIndex == 2
              ? savedPosts ?? const <PostModel>[]
              : tabIndex == 1
              ? repostPosts
              : normalPosts;

      final tabChildren = <Widget>[
        SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: _buildPostsTab(
            context: context,
            controller: postsController,
            controllerTag: widget.controllerTag,
            palette: palette,
            theme: theme,
            status: authoredStatus,
            posts: normalPosts,
            isRepostTab: false,
            emptyMessage:
                widget.isOwnerView
                    ? 'Bạn chưa có bài viết nào.'
                    : 'Người dùng này chưa có bài viết công khai nào.',
          ),
        ),
        SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: _buildPostsTab(
            context: context,
            controller: postsController,
            controllerTag: widget.controllerTag,
            palette: palette,
            theme: theme,
            status: authoredStatus,
            posts: repostPosts,
            isRepostTab: true,
            emptyMessage:
                widget.isOwnerView
                    ? 'Bạn chưa đăng lại bài viết nào.'
                    : 'Người dùng này chưa có bài đăng lại công khai.',
          ),
        ),
      ];

      if (canShowSavedTab &&
          resolvedSavedController != null &&
          resolvedSavedControllerTag != null) {
        tabChildren.add(
          SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: _buildPostsTab(
              context: context,
              controller: resolvedSavedController,
              controllerTag: resolvedSavedControllerTag,
              palette: palette,
              theme: theme,
              status: savedStatus ?? ProfilePostsStatus.initial,
              posts: savedPosts ?? const <PostModel>[],
              isRepostTab: false,
              emptyMessage: 'Bạn chưa lưu bài viết nào.',
            ),
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProfilePostsTabBar(
              controller: _tabController,
              showSavedTab: canShowSavedTab,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: _buildTabHeight(
                  controller: activeController,
                  status: activeStatus,
                  visiblePosts: activePosts,
                ),
                child: TabBarView(
                  controller: _tabController,
                  children: tabChildren,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  double _buildTabHeight({
    required ProfilePostsController controller,
    required ProfilePostsStatus status,
    required List<PostModel> visiblePosts,
  }) {
    if ((status == ProfilePostsStatus.initial ||
            status == ProfilePostsStatus.loading) &&
        controller.posts.isEmpty) {
      return 120;
    }

    if (status == ProfilePostsStatus.error && controller.posts.isEmpty) {
      return 170;
    }

    if (status == ProfilePostsStatus.empty || visiblePosts.isEmpty) {
      return 120;
    }

    final privateCount =
        widget.isOwnerView
            ? visiblePosts.where((post) => !post.isPublic).length
            : 0;

    final postsHeight = visiblePosts.length * 355.0;
    final privateBannerHeight = privateCount * 28.0;
    final loadMoreHeight =
        controller.isLoadingMore.value || controller.hasMore.value ? 56.0 : 0.0;

    return postsHeight + privateBannerHeight + loadMoreHeight;
  }

  Widget _buildPostsTab({
    required BuildContext context,
    required ProfilePostsController controller,
    required String controllerTag,
    required FeedPalette palette,
    required ThemeData theme,
    required ProfilePostsStatus status,
    required List<PostModel> posts,
    required bool isRepostTab,
    required String emptyMessage,
  }) {
    if ((status == ProfilePostsStatus.initial ||
            status == ProfilePostsStatus.loading) &&
        controller.posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _SectionStateCard(
          palette: palette,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }

    if (status == ProfilePostsStatus.error && controller.posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _SectionStateCard(
          palette: palette,
          child: Column(
            children: [
              Text(
                controller.errorMessage.value ??
                    'Không thể tải bài viết lúc này.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.textPrimary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: controller.loadInitialPosts,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (status == ProfilePostsStatus.empty || posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _SectionStateCard(
          palette: palette,
          child: Text(
            emptyMessage,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.textSecondary,
              height: 1.5,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          color: theme.scaffoldBackgroundColor,
          child: Column(
            children: [
              for (var index = 0; index < posts.length; index++) ...[
                _buildPostItem(
                  context: context,
                  controller: controller,
                  controllerTag: controllerTag,
                  sourcePost: posts[index],
                  isRepostTab: isRepostTab,
                  showDivider: index > 0,
                  showPrivateBanner:
                      widget.isOwnerView && !posts[index].isPublic,
                ),
              ],
            ],
          ),
        ),
        if (controller.isLoadingMore.value)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (controller.hasMore.value)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton(
              onPressed: controller.loadMore,
              child: const Text('Xem thêm bài viết'),
            ),
          ),
      ],
    );
  }

  Widget _buildPostItem({
    required BuildContext context,
    required ProfilePostsController controller,
    required String controllerTag,
    required PostModel sourcePost,
    required bool isRepostTab,
    required bool showDivider,
    required bool showPrivateBanner,
  }) {
    final displayPost = _resolveDisplayPost(
      controller: controller,
      sourcePost: sourcePost,
      isRepostTab: isRepostTab,
    );

    return _ProfileRemovalAnimatedPostItem(
      key: ValueKey(
        'profile_post_${sourcePost.postId}_${isRepostTab ? 'repost' : 'normal'}',
      ),
      controller: controller,
      listPostId: sourcePost.postId,
      displayPost: displayPost,
      showDivider: showDivider,
      showPrivateBanner: showPrivateBanner,
      onTap: () => _openPostDetail(displayPost, controllerTag: controllerTag),
      onLikeTap: () => controller.toggleLike(displayPost.postId),
      onCommentTap:
          () => _openPostDetail(displayPost, controllerTag: controllerTag),
      onRepostTap:
          () => _openRepostSheet(
            context,
            displayPost,
            controllerTag: controllerTag,
          ),
      onShareTap: controller.onShareTap,
      onMoreTap:
          () => _openPostActionSheet(
            context,
            displayPost,
            controllerTag: controllerTag,
          ),
      onAuthorTap: _openAuthorProfile,
      onReferenceAuthorTap: _openAuthorProfile,
      onReferenceTap:
          displayPost.referencePost != null
              ? () => _openReferencePostDetail(
                displayPost,
                controllerTag: controllerTag,
              )
              : null,
    );
  }

  PostModel _resolveDisplayPost({
    required ProfilePostsController controller,
    required PostModel sourcePost,
    required bool isRepostTab,
  }) {
    if (!isRepostTab) return sourcePost;
    return controller.resolveDisplayPost(sourcePost);
  }

  Future<void> _openPostDetail(
    PostModel post, {
    required String controllerTag,
  }) async {
    await Get.toNamed(
      AppRouter.postDetail,
      arguments: PostDetailRouteArgs(
        post: post,
        profilePostsControllerTag: controllerTag,
      ),
    );
  }

  Future<void> _openReferencePostDetail(
    PostModel sourcePost, {
    required String controllerTag,
  }) async {
    final resolvedPost = await _resolvePostDetailPost(
      sourcePost,
      controllerTag: controllerTag,
    );
    await Get.toNamed(
      AppRouter.postDetail,
      arguments: PostDetailRouteArgs(
        post: resolvedPost,
        profilePostsControllerTag: controllerTag,
      ),
    );
  }

  Future<PostModel> _resolvePostDetailPost(
    PostModel tappedPost, {
    required String controllerTag,
  }) async {
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

    final controller = Get.find<ProfilePostsController>(tag: controllerTag);
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

  Future<void> _openPostActionSheet(
    BuildContext context,
    PostModel post, {
    required String controllerTag,
  }) {
    final controller = Get.find<ProfilePostsController>(tag: controllerTag);
    final currentUserId = controller.currentUserId.trim();
    final canDeletePost =
        currentUserId.isNotEmpty && post.authorId.trim() == currentUserId;
    final canHidePost =
        currentUserId.isNotEmpty && post.authorId.trim() != currentUserId;

    return PostActionSheet.show(
      context,
      post: post,
      isSaved: post.isSaved,
      onSaveTap: () => controller.toggleSave(post.postId),
      canHidePost: canHidePost,
      onHidePostTap: canHidePost ? () => _hidePostFromFeed(post) : null,
      canDeletePost: canDeletePost,
      onDeleteTap:
          canDeletePost
              ? () => _deletePost(post, controllerTag: controllerTag)
              : null,
    );
  }

  Future<void> _hidePostFromFeed(PostModel post) async {
    if (!Get.isRegistered<FeedController>()) {
      return;
    }

    await Get.find<FeedController>().hidePostFromFeed(post);
  }

  Future<void> _openRepostSheet(
    BuildContext context,
    PostModel post, {
    required String controllerTag,
  }) {
    return PostRepostSheet.show(
      context,
      post: post,
      onRepostTap: () => _repostPost(post, controllerTag: controllerTag),
      onUndoRepostTap:
          () => _undoRepostPost(post, controllerTag: controllerTag),
      onQuoteTap: () => _quotePost(context, post),
    );
  }

  Future<void> _quotePost(BuildContext context, PostModel sourcePost) async {
    final createdPost = await CreatePostSheet.show(
      context,
      quotedPost: sourcePost,
    );
    _handlePostCreated(createdPost);
  }

  Future<void> _repostPost(
    PostModel sourcePost, {
    required String controllerTag,
  }) async {
    final controller = Get.find<ProfilePostsController>(tag: controllerTag);
    final createdPost = await controller.repostPost(sourcePost);
    _handlePostCreated(createdPost);
  }

  Future<void> _undoRepostPost(
    PostModel sourcePost, {
    required String controllerTag,
  }) async {
    final controller = Get.find<ProfilePostsController>(tag: controllerTag);
    final removedPost = await controller.undoRepost(sourcePost);
    _handlePostRemoved(removedPost);
  }

  Future<void> _deletePost(
    PostModel post, {
    required String controllerTag,
  }) async {
    final controller = Get.find<ProfilePostsController>(tag: controllerTag);
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

  void _openAuthorProfile(String rawUserId) {
    final userId = rawUserId.trim();
    if (userId.isEmpty) return;

    Get.to(() => OtherProfileView(userId: userId));
  }
}

class _ProfileRemovalAnimatedPostItem extends StatelessWidget {
  const _ProfileRemovalAnimatedPostItem({
    super.key,
    required this.controller,
    required this.listPostId,
    required this.displayPost,
    required this.showDivider,
    required this.showPrivateBanner,
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

  final ProfilePostsController controller;
  final String listPostId;
  final PostModel displayPost;
  final bool showDivider;
  final bool showPrivateBanner;
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
      final isRemoving = controller.isPostRemoving(listPostId);

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
                ? SizedBox(key: ValueKey('profile_post_removing_$listPostId'))
                : Column(
                  key: ValueKey('profile_post_visible_$listPostId'),
                  children: [
                    if (showDivider)
                      Divider(height: 1, thickness: 1, color: palette.border),
                    if (showPrivateBanner) _PrivatePostBanner(palette: palette),
                    PostItem(
                      key: ValueKey('profile_post_item_$listPostId'),
                      post: displayPost,
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

class _ProfilePostsTabBar extends StatelessWidget {
  const _ProfilePostsTabBar({
    required this.controller,
    required this.showSavedTab,
  });

  final TabController controller;
  final bool showSavedTab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: TabBar(
        controller: controller,
        labelColor: theme.colorScheme.onSurface,
        unselectedLabelColor: theme.textTheme.bodySmall?.color,
        indicatorColor: theme.colorScheme.onSurface,
        dividerColor: Colors.transparent,
        tabs: [
          const Tab(text: 'Bài viết'),
          const Tab(text: 'Bài đăng lại'),
          if (showSavedTab) const Tab(text: 'Lưu trữ'),
        ],
      ),
    );
  }
}

class _PrivatePostBanner extends StatelessWidget {
  const _PrivatePostBanner({required this.palette});

  final FeedPalette palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded, size: 16, color: palette.iconMuted),
          const SizedBox(width: 6),
          Text(
            'Bài viết riêng tư',
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionStateCard extends StatelessWidget {
  const _SectionStateCard({required this.palette, required this.child});

  final FeedPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: child,
    );
  }
}
