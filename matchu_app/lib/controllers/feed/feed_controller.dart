import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/profile/profile_posts_controller.dart';
import 'package:get_storage/get_storage.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/services/feed/post_service.dart';
import 'package:matchu_app/translates/firebase_error_translator.dart';

enum FeedStatus { initial, loading, success, empty, error }

class FeedController extends GetxController {
  static const int _pageSize = 10;
  static const double _loadMoreThreshold = 640;
  static const String _hiddenPostsStorageKeyPrefix = 'feed_hidden_posts_';
  static const Duration _postRemovalAnimationDuration = Duration(
    milliseconds: 220,
  );

  final PostService _service = PostService();
  final GetStorage _storage = GetStorage();

  final RxList<PostModel> posts = <PostModel>[].obs;
  final Rx<FeedStatus> status = FeedStatus.initial.obs;
  final RxBool isRefreshing = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = true.obs;
  final RxnString errorMessage = RxnString();

  final ScrollController scrollController = ScrollController();

  final Map<String, bool> _likeCache = <String, bool>{};
  final Map<String, bool> _confirmedLikeStates = <String, bool>{};
  final Map<String, bool> _queuedLikeStates = <String, bool>{};
  final Set<String> _likeSyncingPosts = <String>{};
  final Map<String, bool> _savedCache = <String, bool>{};
  final Map<String, bool> _confirmedSavedStates = <String, bool>{};
  final Map<String, bool> _queuedSavedStates = <String, bool>{};
  final Set<String> _saveSyncingPosts = <String>{};
  final Map<String, PostModel> _locallyPrependedPosts = <String, PostModel>{};
  final Map<String, bool> _repostCache = <String, bool>{};
  final Set<String> _repostPendingTargetIds = <String>{};
  final Set<String> _hiddenPostIds = <String>{};
  final RxSet<String> _removingPostIds = <String>{}.obs;
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;

  String get currentUserId => _service.uid;
  Duration get postRemovalAnimationDuration => _postRemovalAnimationDuration;

  bool isPostRemoving(String postId) {
    final normalizedPostId = postId.trim();
    if (normalizedPostId.isEmpty) return false;
    return _removingPostIds.contains(normalizedPostId);
  }

  @override
  void onInit() {
    super.onInit();
    _loadHiddenPostIds();
    scrollController.addListener(_handleScroll);
    loadInitialFeed();
  }

  bool canHidePostFromFeed(PostModel post) {
    final normalizedCurrentUserId = currentUserId.trim();
    if (normalizedCurrentUserId.isEmpty) return false;
    return post.authorId.trim() != normalizedCurrentUserId;
  }

  Future<void> hidePostFromFeed(PostModel post) async {
    if (!canHidePostFromFeed(post)) {
      return;
    }

    final normalizedPostId = post.postId.trim();
    if (normalizedPostId.isEmpty) {
      return;
    }

    final isNewHiddenPost = _hiddenPostIds.add(normalizedPostId);
    if (isNewHiddenPost) {
      await _persistHiddenPostIds();
    }

    await _removePostByIdWithAnimation(normalizedPostId);

    if (posts.isEmpty && hasMore.value) {
      unawaited(loadMore());
    }

    Get.snackbar(
      'Thông báo',
      'Đã ẩn bài viết khỏi bảng tin của bạn.',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
    );
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
    if (!post.isPublic || post.postType.isRepostOnly) return;
    if (_isPostHidden(post.postId)) return;

    final targetPostId = _repostTargetPostIdOf(post);
    if (targetPostId.isNotEmpty && !_repostCache.containsKey(targetPostId)) {
      _repostCache[targetPostId] = post.isReposted;
    }

    _locallyPrependedPosts[post.postId] = post;
    _likeCache[post.postId] = post.isLiked;
    _confirmedLikeStates[post.postId] = post.isLiked;
    _savedCache[post.postId] = post.isSaved;
    _confirmedSavedStates[post.postId] = post.isSaved;
    posts.assignAll(_mergePosts(posts, [post]));
    errorMessage.value = null;
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

  void adjustShareCount(String postId, {int delta = 1}) {
    final currentPost = _findPost(postId);
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

  PostModel? findPostById(String postId) {
    return _findPost(postId);
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
    final cachedSavedState =
        _savedCache[normalizedPostId] ??
        _confirmedSavedStates[normalizedPostId];
    final isSaved =
        cachedSavedState ?? await _service.isPostSaved(normalizedPostId);

    if (cachedLikeState == null) {
      _likeCache[normalizedPostId] = isLiked;
      _confirmedLikeStates[normalizedPostId] = isLiked;
    }
    if (cachedSavedState == null) {
      _savedCache[normalizedPostId] = isSaved;
      _confirmedSavedStates[normalizedPostId] = isSaved;
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
      isSaved: isSaved,
      isSavePending: _isSaveSyncPending(normalizedPostId),
      isReposted: isReposted,
      isRepostPending: _repostPendingTargetIds.contains(repostTargetPostId),
    );
  }

  Future<PostModel?> repostPost(PostModel sourcePost) async {
    final targetPostId = _repostTargetPostIdOf(sourcePost);
    if (targetPostId.isEmpty) {
      _showError('Không tìm thấy bài viết gốc để đăng lại.');
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
      _showError('Không tìm thấy bài viết gốc để hủy đăng lại.');
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

  Future<PostModel?> deletePost(PostModel post) async {
    try {
      final deletedPost = await _service.deletePost(post: post);
      await _removePostByIdWithAnimation(deletedPost.postId);
      Get.snackbar(
        'Thông báo',
        'Đã xóa bài viết.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
      return deletedPost;
    } catch (error) {
      _showError(_mapError(error));
      return null;
    }
  }

  void removePostById(String postId) {
    final normalizedPostId = postId.trim();
    if (normalizedPostId.isEmpty) return;

    _removePostByIdImmediate(normalizedPostId);
    _removingPostIds.remove(normalizedPostId);
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

      final likedHydratedPosts = await _attachLikeStates(
        page.posts,
        reset: reset,
      );
      final hydratedPosts = await _attachRepostStates(
        likedHydratedPosts,
        reset: reset,
      );
      final savedHydratedPosts = await _attachSavedStates(
        hydratedPosts,
        reset: reset,
      );
      final visibleHydratedPosts = _filterHiddenPosts(savedHydratedPosts);

      if (reset) {
        posts.assignAll(_mergeWithLocallyPrependedPosts(visibleHydratedPosts));
      } else {
        posts.assignAll(_mergePosts(posts, visibleHydratedPosts));
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

  Future<void> toggleSave(String postId) async {
    final currentPost = _findPost(postId);
    if (currentPost == null) return;

    final shouldSave = !currentPost.isSaved;
    final optimisticPost = currentPost.copyWith(
      isSaved: shouldSave,
      isSavePending: true,
    );

    _replacePost(optimisticPost);
    _savedCache[postId] = shouldSave;
    _queuedSavedStates[postId] = shouldSave;
    _syncSavedStateToProfile(
      optimisticPost.copyWith(isSavePending: false),
      isSaved: shouldSave,
    );
    unawaited(_syncSavedState(postId));
  }

  void onShareTap() {
    Get.snackbar(
      'Thông báo',
      'Tính năng chia sẻ sẽ được triển khai ở bước tiếp theo.',
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
      _confirmedLikeStates.addAll(latestStates);

      for (final entry in latestStates.entries) {
        if (_isLikeSyncPending(entry.key)) continue;
        _likeCache[entry.key] = entry.value;
      }
    }

    return incoming
        .map((post) {
          final currentPost = _findPost(post.postId);
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

  Future<List<PostModel>> _attachSavedStates(
    List<PostModel> incoming, {
    required bool reset,
  }) async {
    if (incoming.isEmpty) return incoming;

    final postIds = incoming.map((post) => post.postId).toList(growable: false);
    final idsToFetch =
        reset
            ? postIds
            : postIds
                .where((postId) => !_savedCache.containsKey(postId))
                .toList(growable: false);

    if (idsToFetch.isNotEmpty) {
      final latestStates = await _service.getSavedStates(idsToFetch);
      _confirmedSavedStates.addAll(latestStates);

      for (final entry in latestStates.entries) {
        if (_isSaveSyncPending(entry.key)) continue;
        _savedCache[entry.key] = entry.value;
      }
    }

    return incoming
        .map((post) {
          return post.copyWith(
            isSaved:
                _savedCache[post.postId] ??
                _confirmedSavedStates[post.postId] ??
                false,
            isSavePending: _isSaveSyncPending(post.postId),
          );
        })
        .toList(growable: false);
  }

  List<PostModel> _mergePosts(
    List<PostModel> current,
    List<PostModel> incoming,
  ) {
    final merged = <String, PostModel>{
      for (final post in current)
        if (!_isPostHidden(post.postId)) post.postId: post,
    };

    for (final post in incoming) {
      if (_isPostHidden(post.postId)) {
        continue;
      }
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

    final visibleLocalPosts = _locallyPrependedPosts.values
        .where((post) => !_isPostHidden(post.postId))
        .toList(growable: false);

    if (visibleLocalPosts.isEmpty) return incoming;
    return _mergePosts(incoming, visibleLocalPosts);
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
    if (_locallyPrependedPosts.containsKey(updatedPost.postId)) {
      _locallyPrependedPosts[updatedPost.postId] = updatedPost;
    }
    final updatedPosts = posts.toList(growable: false);
    updatedPosts[index] = updatedPost;
    posts.assignAll(updatedPosts);
  }

  String get _hiddenPostsStorageKey =>
      '$_hiddenPostsStorageKeyPrefix${currentUserId.trim()}';

  void _loadHiddenPostIds() {
    final storedValue = _storage.read(_hiddenPostsStorageKey);
    if (storedValue is! List) {
      _hiddenPostIds.clear();
      return;
    }

    _hiddenPostIds
      ..clear()
      ..addAll(
        storedValue
            .map((value) => value.toString().trim())
            .where((postId) => postId.isNotEmpty),
      );
  }

  Future<void> _persistHiddenPostIds() {
    final values = _hiddenPostIds.toList(growable: false);
    return _storage.write(_hiddenPostsStorageKey, values);
  }

  bool _isPostHidden(String postId) {
    final normalizedPostId = postId.trim();
    if (normalizedPostId.isEmpty) return false;
    return _hiddenPostIds.contains(normalizedPostId);
  }

  List<PostModel> _filterHiddenPosts(List<PostModel> incoming) {
    if (_hiddenPostIds.isEmpty || incoming.isEmpty) {
      return incoming;
    }

    return incoming
        .where((post) => !_hiddenPostIds.contains(post.postId.trim()))
        .toList(growable: false);
  }

  Future<void> _removePostByIdWithAnimation(String postId) async {
    final normalizedPostId = postId.trim();
    if (normalizedPostId.isEmpty) return;

    final postIndex = posts.indexWhere(
      (post) => post.postId == normalizedPostId,
    );
    if (postIndex == -1) {
      _clearPostCaches(normalizedPostId);
      _updateStatusAfterPostMutation();
      return;
    }

    if (_removingPostIds.contains(normalizedPostId)) {
      return;
    }

    _removingPostIds.add(normalizedPostId);
    await Future<void>.delayed(_postRemovalAnimationDuration);
    _removePostByIdImmediate(normalizedPostId);
    _removingPostIds.remove(normalizedPostId);
  }

  void _removePostByIdImmediate(String postId) {
    final postIndex = posts.indexWhere((post) => post.postId == postId);
    if (postIndex != -1) {
      posts.removeAt(postIndex);
    }

    _clearPostCaches(postId);
    _updateStatusAfterPostMutation();
  }

  void _clearPostCaches(String postId) {
    _locallyPrependedPosts.remove(postId);
    _likeCache.remove(postId);
    _confirmedLikeStates.remove(postId);
    _queuedLikeStates.remove(postId);
    _likeSyncingPosts.remove(postId);
    _savedCache.remove(postId);
    _confirmedSavedStates.remove(postId);
    _queuedSavedStates.remove(postId);
    _saveSyncingPosts.remove(postId);
  }

  void _updateStatusAfterPostMutation() {
    if (posts.isEmpty) {
      if (status.value != FeedStatus.empty) {
        status.value = FeedStatus.empty;
      }
      return;
    }

    if (status.value == FeedStatus.empty) {
      status.value = FeedStatus.success;
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

    var hasChanges = false;
    final updatedPosts = posts.toList(growable: false);

    for (var index = 0; index < updatedPosts.length; index++) {
      final current = updatedPosts[index];
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
      updatedPosts[index] = updated;
      if (_locallyPrependedPosts.containsKey(updated.postId)) {
        _locallyPrependedPosts[updated.postId] = updated;
      }
      hasChanges = true;
    }

    if (hasChanges) {
      posts.assignAll(updatedPosts);
    }
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
    final currentPost = _findPost(postId);
    if (currentPost == null) return;

    final shouldBePending = _isLikeSyncPending(postId);
    if (currentPost.isLikePending == shouldBePending) return;

    _replacePost(currentPost.copyWith(isLikePending: shouldBePending));
  }

  void _revertLikeState(String postId) {
    final currentPost = _findPost(postId);
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

  bool _isSaveSyncPending(String postId) {
    return _queuedSavedStates.containsKey(postId) ||
        _saveSyncingPosts.contains(postId);
  }

  Future<void> _syncSavedState(String postId) async {
    if (_saveSyncingPosts.contains(postId)) return;

    _saveSyncingPosts.add(postId);
    _updateSavePendingState(postId);

    try {
      while (true) {
        final targetState = _queuedSavedStates[postId];
        if (targetState == null) break;

        final confirmedState = _confirmedSavedStates[postId] ?? false;
        if (targetState == confirmedState) {
          _queuedSavedStates.remove(postId);
          _updateSavePendingState(postId);
          continue;
        }

        try {
          if (targetState) {
            await _service.savePost(postId);
          } else {
            await _service.unsavePost(postId);
          }

          _confirmedSavedStates[postId] = targetState;
          if (_queuedSavedStates[postId] == targetState) {
            _queuedSavedStates.remove(postId);
          }
        } catch (error) {
          _queuedSavedStates.remove(postId);
          _revertSaveState(postId);
          final revertedPost = _findPost(postId);
          if (revertedPost != null) {
            _syncSavedStateToProfile(
              revertedPost.copyWith(isSavePending: false),
              isSaved: revertedPost.isSaved,
            );
          }
          _showError(_mapError(error));
          break;
        }
      }
    } finally {
      _saveSyncingPosts.remove(postId);
      _updateSavePendingState(postId);
      if (_queuedSavedStates.containsKey(postId)) {
        unawaited(_syncSavedState(postId));
      }
    }
  }

  void _updateSavePendingState(String postId) {
    final currentPost = _findPost(postId);
    if (currentPost == null) return;

    final shouldBePending = _isSaveSyncPending(postId);
    if (currentPost.isSavePending == shouldBePending) return;

    _replacePost(currentPost.copyWith(isSavePending: shouldBePending));
  }

  void _revertSaveState(String postId) {
    final currentPost = _findPost(postId);
    if (currentPost == null) return;

    final confirmedState = _confirmedSavedStates[postId] ?? false;
    _savedCache[postId] = confirmedState;
    _replacePost(
      currentPost.copyWith(isSaved: confirmedState, isSavePending: false),
    );
  }

  void _syncSavedStateToProfile(PostModel post, {required bool isSaved}) {
    final normalizedCurrentUserId = currentUserId.trim();
    if (normalizedCurrentUserId.isEmpty) return;

    final savedTag = ProfilePostsController.ownerSavedTag(
      normalizedCurrentUserId,
    );
    if (!Get.isRegistered<ProfilePostsController>(tag: savedTag)) {
      return;
    }

    Get.find<ProfilePostsController>(tag: savedTag).syncSavedStateFromExternal(
      post: post,
      isSaved: isSaved,
      savedAt: isSaved ? DateTime.now() : null,
    );
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

    return 'Không thể tải bảng tin lúc này. Vui lòng thử lại.';
  }

  void _showError(String message) {
    Get.snackbar(
      'Lỗi',
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
