import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/services/feed/post_service.dart';
import 'package:matchu_app/translates/firebase_error_translator.dart';

enum FeedStatus { initial, loading, success, empty, error }

class FeedController extends GetxController {
  static const int _pageSize = 10;
  static const double _loadMoreThreshold = 640;

  final PostService _service = PostService();

  final RxList<PostModel> posts = <PostModel>[].obs;
  final Rx<FeedStatus> status = FeedStatus.initial.obs;
  final RxBool isRefreshing = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = true.obs;
  final RxnString errorMessage = RxnString();

  final ScrollController scrollController = ScrollController();

  final Map<String, bool> _likeCache = <String, bool>{};
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_handleScroll);
    loadInitialFeed();
  }

  Future<void> loadInitialFeed() async {
    await _loadFeed(reset: true);
  }

  Future<void> refreshFeed() async {
    await _loadFeed(reset: true, isManualRefresh: true);
  }

  Future<void> loadMore() async {
    if (isLoadingMore.value ||
        !hasMore.value ||
        status.value == FeedStatus.loading) {
      return;
    }
    await _loadFeed(reset: false);
  }

  void prependPost(PostModel post) {
    if (!post.isPublic) return;

    _likeCache[post.postId] = post.isLiked;
    posts.assignAll(_mergePosts([post, ...posts], const []));
    status.value = FeedStatus.success;
  }

  void adjustCommentCount(String postId, {int delta = 1}) {
    final currentPost = _findPost(postId);
    if (currentPost == null) return;

    final nextCount = currentPost.stats.commentCount + delta;
    _replacePost(
      currentPost.copyWith(
        stats: currentPost.stats.copyWith(
          commentCount: nextCount < 0 ? 0 : nextCount,
        ),
      ),
    );
  }

  Future<void> _loadFeed({
    required bool reset,
    bool isManualRefresh = false,
  }) async {
    final hadPostsBeforeRequest = posts.isNotEmpty;

    if (reset) {
      if (isRefreshing.value) return;
      isRefreshing.value = isManualRefresh;
      if (!isManualRefresh) {
        status.value = FeedStatus.loading;
      }
      errorMessage.value = null;
    } else {
      if (isLoadingMore.value || !hasMore.value) return;
      isLoadingMore.value = true;
    }

    try {
      final page = await _service.fetchLatestPosts(
        startAfter: reset ? null : _lastDocument,
        limit: _pageSize,
      );

      final hydratedPosts = await _attachLikeStates(page.posts, reset: reset);

      if (reset) {
        posts.assignAll(hydratedPosts);
      } else {
        posts.assignAll(_mergePosts(posts, hydratedPosts));
      }

      _lastDocument = page.lastDocument;
      hasMore.value = page.hasMore;

      if (posts.isEmpty) {
        status.value = FeedStatus.empty;
      } else {
        status.value = FeedStatus.success;
      }
    } catch (error) {
      final message = _mapError(error);
      if (hadPostsBeforeRequest) {
        status.value = FeedStatus.success;
        _showError(message);
      } else {
        errorMessage.value = message;
        status.value = FeedStatus.error;
      }
    } finally {
      if (reset) {
        isRefreshing.value = false;
      } else {
        isLoadingMore.value = false;
      }
    }
  }

  Future<void> toggleLike(String postId) async {
    final currentPost = _findPost(postId);
    if (currentPost == null || currentPost.isLikePending) {
      return;
    }

    final shouldLike = !currentPost.isLiked;
    final optimisticPost = currentPost.copyWith(
      isLiked: shouldLike,
      isLikePending: true,
      stats: currentPost.stats.copyWith(
        likeCount: _nextLikeCount(currentPost.stats.likeCount, shouldLike),
      ),
    );

    _replacePost(optimisticPost);
    _likeCache[postId] = shouldLike;

    try {
      if (shouldLike) {
        await _service.likePost(postId);
      } else {
        await _service.unlikePost(postId);
      }

      _replacePost(optimisticPost.copyWith(isLikePending: false));
    } catch (error) {
      _likeCache[postId] = currentPost.isLiked;
      _replacePost(currentPost);
      _showError(_mapError(error));
    }
  }

  void onShareTap() {
    Get.snackbar(
      'Thong bao',
      'Tinh nang chia se se duoc trien khai o buoc tiep theo.',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
    );
  }

  Future<List<PostModel>> _attachLikeStates(
    List<PostModel> incoming, {
    required bool reset,
  }) async {
    if (incoming.isEmpty) return incoming;

    final postIds = incoming.map((post) => post.postId).toList(growable: false);
    final idsToFetch =
        reset
            ? postIds
            : postIds
                .where((postId) => !_likeCache.containsKey(postId))
                .toList();

    if (idsToFetch.isNotEmpty) {
      final latestStates = await _service.getLikeStates(idsToFetch);
      _likeCache.addAll(latestStates);
    }

    return incoming
        .map(
          (post) => post.copyWith(
            isLiked: _likeCache[post.postId] ?? false,
            isLikePending: false,
          ),
        )
        .toList(growable: false);
  }

  List<PostModel> _mergePosts(
    List<PostModel> current,
    List<PostModel> incoming,
  ) {
    final merged = <String, PostModel>{
      for (final post in current) post.postId: post,
    };

    for (final post in incoming) {
      merged[post.postId] = post;
    }

    final items = merged.values.toList(growable: false);
    items.sort((a, b) {
      final aCreatedAt = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bCreatedAt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bCreatedAt.compareTo(aCreatedAt);
    });
    return items;
  }

  PostModel? _findPost(String postId) {
    for (final post in posts) {
      if (post.postId == postId) return post;
    }
    return null;
  }

  void _replacePost(PostModel updatedPost) {
    final index = posts.indexWhere((post) => post.postId == updatedPost.postId);
    if (index == -1) return;
    posts[index] = updatedPost;
    posts.refresh();
  }

  void _handleScroll() {
    if (!scrollController.hasClients || isLoadingMore.value || !hasMore.value) {
      return;
    }

    final remainingDistance =
        scrollController.position.maxScrollExtent -
        scrollController.position.pixels;

    if (remainingDistance <= _loadMoreThreshold) {
      loadMore();
    }
  }

  int _nextLikeCount(int currentCount, bool shouldLike) {
    if (shouldLike) return currentCount + 1;
    if (currentCount <= 0) return 0;
    return currentCount - 1;
  }

  String _mapError(Object error) {
    if (error is FirebaseException) {
      return firebaseErrorToVietnamese(error.code);
    }

    if (error is StateError) {
      return error.message.toString();
    }

    return 'Khong the tai bang tin luc nay. Vui long thu lai.';
  }

  void _showError(String message) {
    Get.snackbar(
      'Loi',
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
    );
  }

  @override
  void onClose() {
    scrollController.dispose();
    super.onClose();
  }
}
