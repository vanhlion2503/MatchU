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
  final Map<String, bool> _repostCache = <String, bool>{};
  final Set<String> _repostPendingTargetIds = <String>{};
  final RxMap<String, PostModel> _resolvedRepostPostsByReferenceId =
      <String, PostModel>{}.obs;
  final Set<String> _repostReferenceLoadingIds = <String>{};
  final Set<String> _fetchedRepostReferenceIds = <String>{};
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

    final targetPostId = _repostTargetPostIdOf(post);
    if (targetPostId.isNotEmpty && !_repostCache.containsKey(targetPostId)) {
      _repostCache[targetPostId] = post.isReposted;
    }

    _locallyPrependedPosts[post.postId] = post;
    _likeCache[post.postId] = post.isLiked;
    _confirmedLikeStates[post.postId] = post.isLiked;
    posts.assignAll(_mergePosts(posts, [post]));
    _ensureRepostReferencesLoaded(<PostModel>[post]);
    errorMessage.value = null;
    status.value = ProfilePostsStatus.success;
  }

  PostModel resolveDisplayPost(PostModel post) {
    if (!post.isRepostOnly) return post;

    final referencePostId = _referencePostIdOf(post);
    if (referencePostId.isEmpty) {
      return _fallbackOriginalFromRepost(post) ?? post;
    }

    return _resolvedRepostPostsByReferenceId[referencePostId] ??
        _fallbackOriginalFromRepost(post) ??
        post;
  }

  PostModel? findPostById(String postId) {
    final normalizedPostId = postId.trim();
    if (normalizedPostId.isEmpty) return null;

    for (final post in posts) {
      if (post.postId == normalizedPostId) return post;
    }

    return _resolvedRepostPostsByReferenceId[normalizedPostId];
  }

  Future<PostModel?> fetchPostById(String postId) async {
    final normalizedPostId = postId.trim();
    if (normalizedPostId.isEmpty) return null;

    final post = await _service.fetchPostById(normalizedPostId);
    if (post == null) return null;

    final cachedLikeState =
        _likeCache[normalizedPostId] ?? _confirmedLikeStates[normalizedPostId];
    final isLiked =
        cachedLikeState ?? await _service.isPostLiked(normalizedPostId);

    if (cachedLikeState == null) {
      _likeCache[normalizedPostId] = isLiked;
      _confirmedLikeStates[normalizedPostId] = isLiked;
    }

    final repostTargetPostId = _repostTargetPostIdOf(post);
    var isReposted = false;

    if (repostTargetPostId.isNotEmpty) {
      final cachedRepostState = _repostCache[repostTargetPostId];
      if (cachedRepostState != null) {
        isReposted = cachedRepostState;
      } else {
        final repostStates = await _service.getRepostStates(<String>[
          repostTargetPostId,
        ]);
        isReposted = repostStates[repostTargetPostId] ?? false;
        _repostCache[repostTargetPostId] = isReposted;
      }
    }

    return post.copyWith(
      isLiked: isLiked,
      isLikePending: _isLikeSyncPending(normalizedPostId),
      isReposted: isReposted,
      isRepostPending: _repostPendingTargetIds.contains(repostTargetPostId),
    );
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

  bool isPostReposted(PostModel sourcePost) {
    final targetPostId = _repostTargetPostIdOf(sourcePost);
    if (targetPostId.isEmpty) return false;
    return _repostCache[targetPostId] ?? false;
  }

  void applyRepostState(String targetPostId, {required bool isReposted}) {
    final normalizedTargetId = targetPostId.trim();
    if (normalizedTargetId.isEmpty) return;
    _updateRepostStateForTarget(
      normalizedTargetId,
      isReposted: isReposted,
      isPending: false,
    );
  }

  void removePostById(String postId) {
    final normalizedPostId = postId.trim();
    if (normalizedPostId.isEmpty) return;

    posts.removeWhere((post) => post.postId == normalizedPostId);
    _locallyPrependedPosts.remove(normalizedPostId);
    _likeCache.remove(normalizedPostId);
    _confirmedLikeStates.remove(normalizedPostId);
    _queuedLikeStates.remove(normalizedPostId);
    _likeSyncingPosts.remove(normalizedPostId);

    if (posts.isEmpty) {
      status.value = ProfilePostsStatus.empty;
    }
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
    final targetPostId = _repostTargetPostIdOf(sourcePost);
    if (targetPostId.isEmpty) {
      _showError('Khong tim thay bai viet goc de dang lai.');
      return null;
    }

    if (_repostPendingTargetIds.contains(targetPostId)) {
      return null;
    }

    final previousState = _repostCache[targetPostId] ?? sourcePost.isReposted;
    _updateRepostStateForTarget(
      targetPostId,
      isReposted: true,
      isPending: true,
    );

    try {
      final created = await _service.createRepost(sourcePost: sourcePost);
      _updateRepostStateForTarget(
        targetPostId,
        isReposted: true,
        isPending: false,
      );
      Get.snackbar(
        'Thong bao',
        'Da dang lai bai viet thanh cong.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
      return created;
    } catch (error) {
      _updateRepostStateForTarget(
        targetPostId,
        isReposted: previousState,
        isPending: false,
      );
      _showError(_mapError(error));
      return null;
    }
  }

  Future<PostModel?> undoRepost(PostModel sourcePost) async {
    final targetPostId = _repostTargetPostIdOf(sourcePost);
    if (targetPostId.isEmpty) {
      _showError('Khong tim thay bai viet goc de huy dang lai.');
      return null;
    }

    if (_repostPendingTargetIds.contains(targetPostId)) {
      return null;
    }

    final previousState = _repostCache[targetPostId] ?? sourcePost.isReposted;
    _updateRepostStateForTarget(
      targetPostId,
      isReposted: false,
      isPending: true,
    );

    try {
      final removed = await _service.undoRepost(sourcePost: sourcePost);
      _updateRepostStateForTarget(
        targetPostId,
        isReposted: false,
        isPending: false,
      );
      Get.snackbar(
        'Thong bao',
        'Da huy dang lai bai viet.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
      return removed;
    } catch (error) {
      _updateRepostStateForTarget(
        targetPostId,
        isReposted: previousState,
        isPending: false,
      );
      _showError(_mapError(error));
      return null;
    }
  }

  void onShareTap() {
    Get.snackbar(
      'ThÃ´ng bÃ¡o',
      'TÃ­nh nÄƒng chia sáº» sáº½ Ä‘Æ°á»£c triá»ƒn khai á»Ÿ bÆ°á»›c tiáº¿p theo.',
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

      final likedHydratedPosts = await _attachLikeStates(
        page.posts,
        reset: reset,
      );
      final hydratedPosts = await _attachRepostStates(
        likedHydratedPosts,
        reset: reset,
      );

      if (reset) {
        posts.assignAll(_mergeWithLocallyPrependedPosts(hydratedPosts));
      } else {
        posts.assignAll(_mergePosts(posts, hydratedPosts));
      }
      _pruneResolvedRepostCache(posts);
      _ensureRepostReferencesLoaded(posts);

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

  Future<List<PostModel>> _attachRepostStates(
    List<PostModel> incoming, {
    required bool reset,
  }) async {
    if (incoming.isEmpty) return incoming;

    final targetPostIds = incoming
        .map(_repostTargetPostIdOf)
        .where((postId) => postId.isNotEmpty)
        .toSet()
        .toList(growable: false);

    final idsToFetch =
        reset
            ? targetPostIds
            : targetPostIds
                .where((postId) => !_repostCache.containsKey(postId))
                .toList(growable: false);

    if (idsToFetch.isNotEmpty) {
      final latestStates = await _service.getRepostStates(idsToFetch);
      _repostCache.addAll(latestStates);
    }

    return incoming
        .map((post) {
          final targetPostId = _repostTargetPostIdOf(post);
          if (targetPostId.isEmpty) {
            return post.copyWith(isReposted: false, isRepostPending: false);
          }

          return post.copyWith(
            isReposted: _repostCache[targetPostId] ?? false,
            isRepostPending: _repostPendingTargetIds.contains(targetPostId),
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
    if (index != -1) {
      if (_locallyPrependedPosts.containsKey(updatedPost.postId)) {
        _locallyPrependedPosts[updatedPost.postId] = updatedPost;
      }
      posts[index] = updatedPost;
      posts.refresh();
    }

    if (_resolvedRepostPostsByReferenceId.containsKey(updatedPost.postId)) {
      _resolvedRepostPostsByReferenceId[updatedPost.postId] = updatedPost;
    }
  }

  String _repostTargetPostIdOf(PostModel post) {
    return _service.resolveRepostTargetPostId(post);
  }

  void _updateRepostStateForTarget(
    String targetPostId, {
    required bool isReposted,
    required bool isPending,
  }) {
    if (targetPostId.isEmpty) return;

    _repostCache[targetPostId] = isReposted;
    if (isPending) {
      _repostPendingTargetIds.add(targetPostId);
    } else {
      _repostPendingTargetIds.remove(targetPostId);
    }

    var hasPostUpdates = false;
    for (var index = 0; index < posts.length; index++) {
      final current = posts[index];
      if (_repostTargetPostIdOf(current) != targetPostId) {
        continue;
      }

      if (current.isReposted == isReposted &&
          current.isRepostPending == isPending) {
        continue;
      }

      final updated = current.copyWith(
        isReposted: isReposted,
        isRepostPending: isPending,
      );
      posts[index] = updated;
      if (_locallyPrependedPosts.containsKey(updated.postId)) {
        _locallyPrependedPosts[updated.postId] = updated;
      }
      hasPostUpdates = true;
    }

    final resolvedKeys = _resolvedRepostPostsByReferenceId.keys.toList(
      growable: false,
    );
    for (final referencePostId in resolvedKeys) {
      final resolvedPost = _resolvedRepostPostsByReferenceId[referencePostId];
      if (resolvedPost == null) continue;
      if (_repostTargetPostIdOf(resolvedPost) != targetPostId) {
        continue;
      }
      if (resolvedPost.isReposted == isReposted &&
          resolvedPost.isRepostPending == isPending) {
        continue;
      }
      _resolvedRepostPostsByReferenceId[referencePostId] = resolvedPost
          .copyWith(isReposted: isReposted, isRepostPending: isPending);
    }

    if (hasPostUpdates) {
      posts.refresh();
    }
  }

  void _pruneResolvedRepostCache(Iterable<PostModel> sourcePosts) {
    final activeReferenceIds =
        sourcePosts
            .where((post) => post.isRepostOnly)
            .map(_referencePostIdOf)
            .where((postId) => postId.isNotEmpty)
            .toSet();

    final staleCachedIds = _resolvedRepostPostsByReferenceId.keys
        .where((postId) => !activeReferenceIds.contains(postId))
        .toList(growable: false);

    for (final postId in staleCachedIds) {
      _resolvedRepostPostsByReferenceId.remove(postId);
    }

    _repostReferenceLoadingIds.removeWhere(
      (postId) => !activeReferenceIds.contains(postId),
    );
    _fetchedRepostReferenceIds.removeWhere(
      (postId) => !activeReferenceIds.contains(postId),
    );
  }

  void _ensureRepostReferencesLoaded(Iterable<PostModel> sourcePosts) {
    for (final post in sourcePosts) {
      if (!post.isRepostOnly) {
        continue;
      }

      final referencePostId = _referencePostIdOf(post);
      if (referencePostId.isEmpty ||
          _fetchedRepostReferenceIds.contains(referencePostId) ||
          _repostReferenceLoadingIds.contains(referencePostId)) {
        continue;
      }

      if (!_resolvedRepostPostsByReferenceId.containsKey(referencePostId)) {
        final fallbackPost = _fallbackOriginalFromRepost(post);
        if (fallbackPost != null) {
          _resolvedRepostPostsByReferenceId[referencePostId] = fallbackPost;
        }
      }

      _repostReferenceLoadingIds.add(referencePostId);
      unawaited(_loadRepostReference(referencePostId));
    }
  }

  Future<void> _loadRepostReference(String referencePostId) async {
    try {
      final fetchedPost = await fetchPostById(referencePostId);
      if (fetchedPost != null) {
        _resolvedRepostPostsByReferenceId[referencePostId] = fetchedPost;
        _fetchedRepostReferenceIds.add(referencePostId);
      }
    } finally {
      _repostReferenceLoadingIds.remove(referencePostId);
    }
  }

  String _referencePostIdOf(PostModel post) {
    return (post.referencePostId ?? post.referencePost?.postId ?? '').trim();
  }

  PostModel? _fallbackOriginalFromRepost(PostModel repostPost) {
    final reference = repostPost.referencePost;
    final referencePostId = _referencePostIdOf(repostPost);
    if (reference == null || referencePostId.isEmpty) return null;

    return PostModel(
      postId: referencePostId,
      authorId: reference.authorId,
      postType: reference.postType,
      content: reference.content,
      media: reference.media,
      tags: reference.tags,
      isPublic: reference.isPublic,
      stats: repostPost.stats,
      trendScore: repostPost.trendScore,
      trendBucket: repostPost.trendBucket,
      author: reference.author,
      createdAt: reference.createdAt,
      updatedAt: reference.createdAt,
      deletedAt: reference.deletedAt,
      isLiked:
          _likeCache[referencePostId] ??
          _confirmedLikeStates[referencePostId] ??
          false,
      isLikePending: _isLikeSyncPending(referencePostId),
      isReposted: _repostCache[referencePostId] ?? false,
      isRepostPending: _repostPendingTargetIds.contains(referencePostId),
    );
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

    return 'KhÃ´ng thá»ƒ táº£i danh sÃ¡ch bÃ i viáº¿t lÃºc nÃ y. Vui lÃ²ng thá»­ láº¡i.';
  }

  void _showError(String message) {
    Get.snackbar(
      'Lá»—i',
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
    );
  }
}
