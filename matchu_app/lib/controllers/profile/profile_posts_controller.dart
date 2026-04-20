import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/services/feed/post_service.dart';
import 'package:matchu_app/translates/firebase_error_translator.dart';

enum ProfilePostsStatus { initial, loading, success, empty, error }

class ProfilePostsController extends GetxController {
  ProfilePostsController({
    required this.userId,
    required this.includePrivate,
    PostService? postService,
  }) : _service = postService ?? PostService();

  static const int _pageSize = 10;

  static String ownerProfileTag(String userId) => 'profile_posts_self_$userId';

  static String otherProfileTag(
    String userId, {
    required bool includePrivate,
  }) => 'other_profile_posts_${userId}_${includePrivate ? 'self' : 'public'}';

  static List<String> selfProfileTags(String userId) => <String>[
    ownerProfileTag(userId),
    otherProfileTag(userId, includePrivate: true),
  ];

  final String userId;
  final bool includePrivate;
  final PostService _service;

  final RxList<PostModel> posts = <PostModel>[].obs;
  final Rx<ProfilePostsStatus> status = ProfilePostsStatus.initial.obs;
  final RxBool isRefreshing = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = true.obs;
  final RxnString errorMessage = RxnString();

  final Map<String, bool> _likeCache = <String, bool>{};
  final Map<String, bool> _confirmedLikeStates = <String, bool>{};
  final Map<String, bool> _queuedLikeStates = <String, bool>{};
  final Set<String> _likeSyncingPosts = <String>{};
  final Map<String, PostModel> _locallyPrependedPosts = <String, PostModel>{};
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;

  @override
  void onInit() {
    super.onInit();
    loadInitialPosts();
  }

  Future<void> loadInitialPosts() async {
    await _loadPosts(reset: true);
  }

  Future<void> refreshPosts() async {
    await _loadPosts(reset: true, isManualRefresh: true);
  }

  Future<void> loadMore() async {
    if (isLoadingMore.value ||
        !hasMore.value ||
        status.value == ProfilePostsStatus.loading) {
      return;
    }

    await _loadPosts(reset: false);
  }

  void prependPost(PostModel post) {
    if (post.authorId != userId) return;
    if (!includePrivate && !post.isPublic) return;

    _locallyPrependedPosts[post.postId] = post;
    _likeCache[post.postId] = post.isLiked;
    _confirmedLikeStates[post.postId] = post.isLiked;
    posts.assignAll(_mergePosts(posts, [post]));
    errorMessage.value = null;
    status.value = ProfilePostsStatus.success;
  }

  PostModel? findPostById(String postId) {
    for (final post in posts) {
      if (post.postId == postId) return post;
    }
    return null;
  }

  void adjustCommentCount(String postId, {int delta = 1}) {
    final currentPost = findPostById(postId);
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

  void adjustShareCount(String postId, {int delta = 1}) {
    final currentPost = findPostById(postId);
    if (currentPost == null) return;

    final nextCount = currentPost.stats.shareCount + delta;
    _replacePost(
      currentPost.copyWith(
        stats: currentPost.stats.copyWith(
          shareCount: nextCount < 0 ? 0 : nextCount,
        ),
      ),
    );
  }

  Future<void> toggleLike(String postId) async {
    final currentPost = findPostById(postId);
    if (currentPost == null) return;

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
    _queuedLikeStates[postId] = shouldLike;
    unawaited(_syncLikeState(postId));
  }

  Future<PostModel?> repostPost(PostModel sourcePost) async {
    try {
      final created = await _service.createRepost(sourcePost: sourcePost);
      Get.snackbar(
        'Thông báo',
        'Đã đăng lại bài viết thành công.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
      return created;
    } catch (error) {
      _showError(_mapError(error));
      return null;
    }
  }

  void onShareTap() {
    Get.snackbar(
      'Thông báo',
      'Tính năng chia sẻ sẽ được triển khai ở bước tiếp theo.',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
    );
  }

  Future<void> _loadPosts({
    required bool reset,
    bool isManualRefresh = false,
  }) async {
    final hadPostsBeforeRequest = posts.isNotEmpty;

    if (reset) {
      if (isRefreshing.value) return;
      isRefreshing.value = isManualRefresh;
      if (!isManualRefresh) {
        status.value = ProfilePostsStatus.loading;
      }
      errorMessage.value = null;
    } else {
      if (isLoadingMore.value || !hasMore.value) return;
      isLoadingMore.value = true;
    }

    try {
      final page = await _service.fetchPostsByAuthor(
        authorId: userId,
        startAfter: reset ? null : _lastDocument,
        limit: _pageSize,
        publicOnly: !includePrivate,
      );

      final hydratedPosts = await _attachLikeStates(page.posts, reset: reset);

      if (reset) {
        posts.assignAll(_mergeWithLocallyPrependedPosts(hydratedPosts));
      } else {
        posts.assignAll(_mergePosts(posts, hydratedPosts));
      }

      _lastDocument = page.lastDocument;
      hasMore.value = page.hasMore;

      if (posts.isEmpty) {
        status.value = ProfilePostsStatus.empty;
      } else {
        status.value = ProfilePostsStatus.success;
      }
    } catch (error) {
      final message = _mapError(error);
      if (hadPostsBeforeRequest) {
        status.value = ProfilePostsStatus.success;
        _showError(message);
      } else {
        errorMessage.value = message;
        status.value = ProfilePostsStatus.error;
      }
    } finally {
      if (reset) {
        isRefreshing.value = false;
      } else {
        isLoadingMore.value = false;
      }
    }
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
      _confirmedLikeStates.addAll(latestStates);

      for (final entry in latestStates.entries) {
        if (_isLikeSyncPending(entry.key)) continue;
        _likeCache[entry.key] = entry.value;
      }
    }

    return incoming
        .map((post) {
          final currentPost = findPostById(post.postId);
          final hasPendingSync = _isLikeSyncPending(post.postId);

          return post.copyWith(
            isLiked:
                _likeCache[post.postId] ??
                _confirmedLikeStates[post.postId] ??
                false,
            isLikePending: hasPendingSync,
            stats:
                hasPendingSync && currentPost != null
                    ? post.stats.copyWith(
                      likeCount: currentPost.stats.likeCount,
                    )
                    : post.stats,
          );
        })
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

  List<PostModel> _mergeWithLocallyPrependedPosts(List<PostModel> incoming) {
    if (_locallyPrependedPosts.isEmpty) return incoming;

    final localPosts = _locallyPrependedPosts.values
        .where((post) => post.authorId == userId)
        .where((post) => includePrivate || post.isPublic)
        .toList(growable: false);

    if (localPosts.isEmpty) return incoming;
    return _mergePosts(incoming, localPosts);
  }

  bool _isLikeSyncPending(String postId) {
    return _queuedLikeStates.containsKey(postId) ||
        _likeSyncingPosts.contains(postId);
  }

  Future<void> _syncLikeState(String postId) async {
    if (_likeSyncingPosts.contains(postId)) return;

    _likeSyncingPosts.add(postId);
    _updateLikePendingState(postId);

    try {
      while (true) {
        final targetState = _queuedLikeStates[postId];
        if (targetState == null) break;

        final confirmedState = _confirmedLikeStates[postId] ?? false;
        if (targetState == confirmedState) {
          _queuedLikeStates.remove(postId);
          _updateLikePendingState(postId);
          continue;
        }

        try {
          if (targetState) {
            await _service.likePost(postId);
          } else {
            await _service.unlikePost(postId);
          }

          _confirmedLikeStates[postId] = targetState;
          if (_queuedLikeStates[postId] == targetState) {
            _queuedLikeStates.remove(postId);
          }
        } catch (error) {
          _queuedLikeStates.remove(postId);
          _revertLikeState(postId);
          _showError(_mapError(error));
          break;
        }
      }
    } finally {
      _likeSyncingPosts.remove(postId);
      _updateLikePendingState(postId);
      if (_queuedLikeStates.containsKey(postId)) {
        unawaited(_syncLikeState(postId));
      }
    }
  }

  void _updateLikePendingState(String postId) {
    final currentPost = findPostById(postId);
    if (currentPost == null) return;

    final shouldBePending = _isLikeSyncPending(postId);
    if (currentPost.isLikePending == shouldBePending) return;

    _replacePost(currentPost.copyWith(isLikePending: shouldBePending));
  }

  void _revertLikeState(String postId) {
    final currentPost = findPostById(postId);
    if (currentPost == null) return;

    final confirmedState = _confirmedLikeStates[postId] ?? false;
    _likeCache[postId] = confirmedState;

    final resolvedLikeCount =
        currentPost.isLiked == confirmedState
            ? currentPost.stats.likeCount
            : _nextLikeCount(currentPost.stats.likeCount, confirmedState);

    _replacePost(
      currentPost.copyWith(
        isLiked: confirmedState,
        isLikePending: false,
        stats: currentPost.stats.copyWith(likeCount: resolvedLikeCount),
      ),
    );
  }

  void _replacePost(PostModel updatedPost) {
    final index = posts.indexWhere((post) => post.postId == updatedPost.postId);
    if (index == -1) return;
    if (_locallyPrependedPosts.containsKey(updatedPost.postId)) {
      _locallyPrependedPosts[updatedPost.postId] = updatedPost;
    }
    posts[index] = updatedPost;
    posts.refresh();
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

    return 'Không thể tải danh sách bài viết lúc này. Vui lòng thử lại.';
  }

  void _showError(String message) {
    Get.snackbar(
      'Lỗi',
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
    );
  }
}
