import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/feed/feed_controller.dart';
import 'package:matchu_app/controllers/feed/post_author_block_helper.dart';
import 'package:matchu_app/controllers/search/post_search_controller.dart';
import 'package:matchu_app/models/feed/post_detail_route_args.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/models/feed/post_search_result.dart';
import 'package:matchu_app/routes/app_router.dart';
import 'package:matchu_app/views/feed/widgets/feed_palette.dart';
import 'package:matchu_app/views/feed/widgets/post_action_sheet.dart';
import 'package:matchu_app/views/feed/widgets/post_item.dart';
import 'package:matchu_app/views/profile/other_profile_view.dart';

class PostSearchView extends StatefulWidget {
  const PostSearchView({super.key});

  @override
  State<PostSearchView> createState() => _PostSearchViewState();
}

class _PostSearchViewState extends State<PostSearchView> {
  static const double _loadMoreThreshold = 480;

  late final PostSearchController controller;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    controller = Get.find<PostSearchController>();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) controller.searchFocusNode.requestFocus();
    });
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
    if (Get.isRegistered<FeedController>()) {
      Get.find<FeedController>().onShareTap();
      return;
    }
    _openPostDetail(post);
  }

  @override
  Widget build(BuildContext context) {
    final palette = FeedPalette.of(context);
    return Scaffold(
      backgroundColor: palette.pageBackground,
      appBar: AppBar(
        backgroundColor: palette.headerBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: Text(
          'Tìm kiếm bài viết',
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          _SearchBar(controller: controller, palette: palette),
          Divider(height: 1, color: palette.border),
          Expanded(child: Obx(() => _buildBody(palette))),
        ],
      ),
    );
  }

  Widget _buildBody(FeedPalette palette) {
    return switch (controller.status.value) {
      PostSearchStatus.initial => _SearchMessage(
        icon: Iconsax.search_normal_1,
        title: 'Tìm bài viết bạn quan tâm',
        description:
            controller.errorMessage.value ??
            'Nhập từ khóa rồi nhấn Tìm. Kết quả chính xác sẽ được ưu tiên trước.',
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
                    '${controller.totalMatched.value} kết quả và đề xuất',
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

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.palette});

  final PostSearchController controller;
  final FeedPalette palette;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: palette.headerBackground,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller.searchTextController,
                focusNode: controller.searchFocusNode,
                textInputAction: TextInputAction.search,
                maxLength: 120,
                buildCounter:
                    (
                      _, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) => null,
                onSubmitted: (_) => controller.submitSearch(),
                decoration: InputDecoration(
                  hintText: 'Nhập nội dung hoặc #hashtag',
                  prefixIcon: const Icon(Iconsax.search_normal_1, size: 20),
                  filled: true,
                  fillColor: palette.inputSurface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: controller.submitSearch,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Tìm'),
            ),
          ],
        ),
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
