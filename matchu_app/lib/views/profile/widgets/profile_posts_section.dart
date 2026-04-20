import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/feed/post_creation_sync.dart';
import 'package:matchu_app/controllers/profile/profile_posts_controller.dart';
import 'package:matchu_app/models/feed/post_detail_route_args.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/routes/app_router.dart';
import 'package:matchu_app/views/feed/create_post_sheet.dart';
import 'package:matchu_app/views/feed/widgets/feed_palette.dart';
import 'package:matchu_app/views/feed/widgets/post_action_sheet.dart';
import 'package:matchu_app/views/feed/widgets/post_item.dart';
import 'package:matchu_app/views/feed/widgets/post_repost_sheet.dart';

class ProfilePostsSection extends StatefulWidget {
  const ProfilePostsSection({
    super.key,
    required this.controllerTag,
    required this.isOwnerView,
  });

  final String controllerTag;
  final bool isOwnerView;

  @override
  State<ProfilePostsSection> createState() => _ProfilePostsSectionState();
}

class _ProfilePostsSectionState extends State<ProfilePostsSection>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_handleTabChanged);
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
    final controller = Get.find<ProfilePostsController>(
      tag: widget.controllerTag,
    );
    final palette = FeedPalette.of(context);
    final theme = Theme.of(context);

    return Obx(() {
      final status = controller.status.value;
      final allPosts = controller.posts.toList(growable: false);
      final normalPosts = allPosts
          .where((post) => !post.isRepostOnly)
          .toList(growable: false);
      final repostPosts = allPosts
          .where((post) => post.isRepostOnly)
          .toList(growable: false);
      final isRepostTab = _tabController.index == 1;
      final visiblePosts = isRepostTab ? repostPosts : normalPosts;

      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProfilePostsTabBar(controller: _tabController),
            SizedBox(
              height: _buildTabHeight(
                controller: controller,
                status: status,
                visiblePosts: visiblePosts,
              ),
              child: TabBarView(
                controller: _tabController,
                children: [
                  SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: _buildPostsTab(
                      context: context,
                      controller: controller,
                      palette: palette,
                      theme: theme,
                      status: status,
                      posts: normalPosts,
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
                      controller: controller,
                      palette: palette,
                      theme: theme,
                      status: status,
                      posts: repostPosts,
                      emptyMessage:
                          widget.isOwnerView
                              ? 'Bạn chưa đăng lại bài viết nào.'
                              : 'Người dùng này chưa có bài đăng lại công khai.',
                    ),
                  ),
                ],
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
    required FeedPalette palette,
    required ThemeData theme,
    required ProfilePostsStatus status,
    required List<PostModel> posts,
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
          color: palette.surface,
          child: Column(
            children: [
              for (var index = 0; index < posts.length; index++) ...[
                if (index > 0)
                  Divider(height: 1, thickness: 1, color: palette.border),
                if (widget.isOwnerView && !posts[index].isPublic)
                  _PrivatePostBanner(palette: palette),
                PostItem(
                  key: ValueKey('profile_post_${posts[index].postId}'),
                  post: posts[index],
                  onTap: () => _openPostDetail(posts[index]),
                  onLikeTap: () => controller.toggleLike(posts[index].postId),
                  onCommentTap: () => _openPostDetail(posts[index]),
                  onRepostTap: () => _openRepostSheet(context, posts[index]),
                  onShareTap: controller.onShareTap,
                  onMoreTap: () => _openPostActionSheet(context, posts[index]),
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

  Future<void> _openPostDetail(PostModel post) async {
    await Get.toNamed(
      AppRouter.postDetail,
      arguments: PostDetailRouteArgs(
        post: post,
        profilePostsControllerTag: widget.controllerTag,
      ),
    );
  }

  Future<void> _openPostActionSheet(BuildContext context, PostModel post) {
    return PostActionSheet.show(context, post: post);
  }

  Future<void> _openRepostSheet(BuildContext context, PostModel post) {
    return PostRepostSheet.show(
      context,
      post: post,
      onRepostTap: () => _repostPost(post),
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

  Future<void> _repostPost(PostModel sourcePost) async {
    final controller = Get.find<ProfilePostsController>(
      tag: widget.controllerTag,
    );
    final createdPost = await controller.repostPost(sourcePost);
    _handlePostCreated(createdPost);
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
}

class _ProfilePostsTabBar extends StatelessWidget {
  const _ProfilePostsTabBar({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final palette = FeedPalette.of(context);
    final theme = Theme.of(context);

    return Container(
      color: palette.surface,
      child: TabBar(
        controller: controller,
        labelColor: theme.colorScheme.onSurface,
        unselectedLabelColor: theme.textTheme.bodySmall?.color,
        indicatorColor: theme.colorScheme.onSurface,
        dividerColor: Colors.transparent,
        tabs: const [Tab(text: 'Bài viết'), Tab(text: 'Bài đăng lại')],
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
