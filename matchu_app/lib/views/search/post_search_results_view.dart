import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/feed/post_share_controller.dart';
import 'package:matchu_app/controllers/feed/post_author_block_helper.dart';
import 'package:matchu_app/controllers/search/post_search_controller.dart';
import 'package:matchu_app/models/feed/post_detail_route_args.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/models/feed/post_search_result.dart';
import 'package:matchu_app/routes/app_router.dart';
import 'package:matchu_app/views/feed/widgets/feed_palette.dart';
import 'package:matchu_app/views/feed/widgets/post_action_sheet.dart';
import 'package:matchu_app/views/feed/widgets/post_item.dart';
import 'package:matchu_app/views/feed/widgets/post_share_sheet.dart';
import 'package:matchu_app/views/feed/widgets/post_chat_share_sheet.dart';
import 'package:matchu_app/views/profile/other_profile_view.dart';

class PostSearchResultsView extends StatefulWidget {
  const PostSearchResultsView({super.key});

  @override
  State<PostSearchResultsView> createState() => _PostSearchResultsViewState();
}

class _PostSearchResultsViewState extends State<PostSearchResultsView> {
  static const double _loadMoreThreshold = 480;

  late final PostSearchController controller;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    controller = Get.find<PostSearchController>();
    _scrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter <= _loadMoreThreshold) {
      unawaited(controller.loadMore());
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _openPostDetail(PostModel post) {
    Get.toNamed(
      AppRouter.postDetail,
      arguments: PostDetailRouteArgs(post: post),
    );
  }

  void _openAuthor(String rawUserId) {
    final userId = rawUserId.trim();
    if (userId.isEmpty) return;
    Get.to(() => OtherProfileView(userId: userId));
  }

  Future<void> _openActions(PostModel post) {
    final canReport =
        controller.currentUserId.isNotEmpty &&
        controller.currentUserId != post.authorId.trim();
    return PostActionSheet.show(
      context,
      post: post,
      isSaved: post.isSaved,
      onSaveTap: () => controller.toggleSave(post.postId),
      onCopyLinkTap: () => Get.find<PostShareController>().copyPostLink(post),
      canReportPost: canReport,
      onBlockAuthorTap:
          canReport
              ? () async {
                await PostAuthorBlockHelper.blockAuthor(post);
                controller.removeAuthor(post.authorId);
              }
              : null,
    );
  }

  void _sharePost(PostModel post) {
    final shareController = Get.find<PostShareController>();
    if (!shareController.canShare(post)) return;
    PostShareSheet.show(
      context,
      post: post,
      onMatchuTap: () => PostChatShareSheet.show(context, post: post),
      onShareTap:
          (origin) =>
              shareController.sharePost(post, sharePositionOrigin: origin),
      onCopyTap: () => shareController.copyPostLink(post),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = FeedPalette.of(context);
    return Scaffold(
      backgroundColor: palette.pageBackground,
      appBar: AppBar(
        toolbarHeight: 58,
        backgroundColor: palette.headerBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        // Thu gọn vùng leading để tiêu đề nằm gần mũi tên hơn.
        leadingWidth: 48,
        leading: Semantics(
          button: true,
          label: 'Quay lại',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: Get.back,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.arrow_back_ios_new, size: 20),
            ),
          ),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Kết quả tìm kiếm',
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            Obx(
              () => Text(
                controller.displayQuery,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Obx(() => _buildBody(palette)),
    );
  }

  Widget _buildBody(FeedPalette palette) {
    return switch (controller.status.value) {
      PostSearchStatus.initial => _SearchMessage(
        icon: Iconsax.search_normal_1,
        title: 'Chưa có từ khóa tìm kiếm',
        description:
            controller.errorMessage.value ??
            'Quay lại và nhập nội dung bạn muốn tìm.',
        palette: palette,
      ),
      PostSearchStatus.loading => const Center(
        child: CircularProgressIndicator(),
      ),
      PostSearchStatus.empty => _SearchMessage(
        icon: Iconsax.document_text,
        title: 'Không tìm thấy bài viết phù hợp',
        description:
            'Hãy thử từ khóa ngắn hơn, bỏ bớt từ hoặc tìm theo hashtag.',
        palette: palette,
      ),
      PostSearchStatus.error => _SearchError(
        message:
            controller.errorMessage.value ??
            'Không thể tìm kiếm bài viết lúc này.',
        onRetry: controller.submitSearch,
        palette: palette,
      ),
      PostSearchStatus.success => _buildResults(palette),
    };
  }

  Widget _buildResults(FeedPalette palette) {
    final results = controller.results.toList(growable: false);
    return RefreshIndicator(
      onRefresh: controller.submitSearch,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: 32),
        itemCount: results.length + 1,
        itemBuilder: (context, index) {
          if (index == results.length) {
            return Obx(
              () =>
                  controller.isLoadingMore.value
                      ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                      : const SizedBox(height: 16),
            );
          }

          final item = results[index];
          return Column(
            key: ValueKey<String>('post_search_${item.post.postId}'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (index == 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Text(
                    '${controller.totalMatched.value} kết quả',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              _MatchScoreLabel(item: item, palette: palette),
              PostItem(
                post: item.post,
                onTap: () => _openPostDetail(item.post),
                onLikeTap: () => controller.toggleLike(item.post.postId),
                onCommentTap: () => _openPostDetail(item.post),
                onRepostTap: () => _openPostDetail(item.post),
                onShareTap: () => _sharePost(item.post),
                onMoreTap: () => _openActions(item.post),
                onAuthorTap: _openAuthor,
                onReferenceAuthorTap: _openAuthor,
                onReferenceTap: () => _openPostDetail(item.post),
              ),
              Divider(height: 1, color: palette.border),
            ],
          );
        },
      ),
    );
  }
}

class _MatchScoreLabel extends StatelessWidget {
  const _MatchScoreLabel({required this.item, required this.palette});

  final PostSearchItem item;
  final FeedPalette palette;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${item.matchType.label} • ${item.scorePercent}%',
            style: TextStyle(
              color: primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchMessage extends StatelessWidget {
  const _SearchMessage({
    required this.icon,
    required this.title,
    required this.description,
    required this.palette,
  });

  final IconData icon;
  final String title;
  final String description;
  final FeedPalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: palette.textTertiary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textSecondary, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchError extends StatelessWidget {
  const _SearchError({
    required this.message,
    required this.onRetry,
    required this.palette,
  });

  final String message;
  final Future<void> Function() onRetry;
  final FeedPalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.warning_2, size: 42, color: palette.textTertiary),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
