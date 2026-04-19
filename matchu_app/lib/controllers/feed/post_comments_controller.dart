import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/models/feed/post_comment_model.dart';
import 'package:matchu_app/services/feed/post_comment_service.dart';
import 'package:matchu_app/translates/firebase_error_translator.dart';

enum CommentSortMode { featured, newest }

extension CommentSortModeLabel on CommentSortMode {
  String get label {
    switch (this) {
      case CommentSortMode.featured:
        return 'Nổi bật';
      case CommentSortMode.newest:
        return 'Mới nhất';
    }
  }
}

class PostCommentsController extends GetxController {
  PostCommentsController({
    required this.postId,
    this.onCommentCountChanged,
    this.initialCommentCount = 0,
    this.pageSize = PostCommentService.defaultTopLevelPageSize,
    PostCommentService? service,
  }) : _service = service ?? PostCommentService();

  final String postId;
  final ValueChanged<int>? onCommentCountChanged;
  final int initialCommentCount;
  final int pageSize;
  final PostCommentService _service;

  final TextEditingController inputController = TextEditingController();
  final FocusNode inputFocusNode = FocusNode();

  final RxList<PostCommentModel> comments = <PostCommentModel>[].obs;
  final RxList<CommentThreadEntry> threadEntries = <CommentThreadEntry>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool isSubmitting = false.obs;
  final RxBool hasInputText = false.obs;
  final RxBool isLoadingMoreComments = false.obs;
  final RxBool hasMoreComments = true.obs;
  final RxnString errorMessage = RxnString();
  final Rxn<PostCommentModel> replyingTo = Rxn<PostCommentModel>();
  final RxSet<String> expandedCommentIds = <String>{}.obs;
  final RxSet<String> loadingReplyParentIds = <String>{}.obs;
  final RxInt totalCommentCount = 0.obs;
  final Rx<CommentSortMode> sortMode = CommentSortMode.featured.obs;

  final Map<String, bool> _likeCache = <String, bool>{};
  final Map<String, bool> _confirmedLikeStates = <String, bool>{};
  final Map<String, bool> _queuedLikeStates = <String, bool>{};
  final Set<String> _likeSyncingCommentIds = <String>{};
  final Set<String> _loadedReplyParentIds = <String>{};
  final Map<String, int> _topLevelOrderRanks = <String, int>{};

  DocumentSnapshot<Map<String, dynamic>>? _topLevelCursor;

  void _rebuildThreadEntries() {
    final expandedIds = Set<String>.from(expandedCommentIds);
    final currentSortMode = sortMode.value;
    final currentComments = comments.toList(growable: false);
    final existingIds =
        currentComments.map((comment) => comment.commentId).toSet();
    final groupedByParent = <String?, List<PostCommentModel>>{};

    for (final comment in currentComments) {
      final parentId =
          comment.parentId != null && existingIds.contains(comment.parentId)
              ? comment.parentId
              : null;

      groupedByParent
          .putIfAbsent(parentId, () => <PostCommentModel>[])
          .add(comment);
    }

    for (final entry in groupedByParent.entries) {
      entry.value.sort(
        (a, b) => _compareThreadComments(
          parentId: entry.key,
          currentSortMode: currentSortMode,
          a: a,
          b: b,
        ),
      );
    }

    final flattened = <CommentThreadEntry>[];

    void visit(
      String? parentId,
      int depth,
      List<bool> ancestorBranchContinues,
    ) {
      final children = groupedByParent[parentId];
      if (children == null || children.isEmpty) return;

      for (var index = 0; index < children.length; index++) {
        final comment = children[index];
        final loadedChildren = groupedByParent[comment.commentId];
        final hasNextSibling = index < children.length - 1;
        final hasChildren =
            (loadedChildren?.isNotEmpty ?? false) || comment.replyCount > 0;
        final isExpanded =
            hasChildren && expandedIds.contains(comment.commentId);

        flattened.add(
          CommentThreadEntry(
            comment: comment,
            depth: depth,
            ancestorBranchContinues: List<bool>.unmodifiable(
              ancestorBranchContinues,
            ),
            hasNextSibling: hasNextSibling,
            hasChildren: hasChildren,
            isExpanded: isExpanded,
          ),
        );

        if (!isExpanded) continue;

        visit(
          comment.commentId,
          depth + 1,
          depth == 0
              ? ancestorBranchContinues
              : <bool>[...ancestorBranchContinues, hasNextSibling],
        );
      }
    }

    visit(null, 0, const <bool>[]);
    threadEntries.assignAll(flattened);
  }

  @override
  void onInit() {
    super.onInit();
    totalCommentCount.value = initialCommentCount;
    inputController.addListener(_handleInputChanged);
    _handleInputChanged();
    loadComments();
  }

  bool isReplyLoading(String commentId) {
    return loadingReplyParentIds.contains(commentId);
  }

  Future<void> loadComments() async {
    try {
      isLoading.value = true;
      errorMessage.value = null;
      _resetLoadedState();

      await _loadMoreTopLevelComments(resetCursor: true);
    } catch (error) {
      errorMessage.value = _mapError(error);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMoreComments() async {
    if (isLoading.value ||
        isLoadingMoreComments.value ||
        !hasMoreComments.value) {
      return;
    }

    try {
      isLoadingMoreComments.value = true;
      await _loadMoreTopLevelComments();
    } catch (error) {
      _showError(_mapError(error));
    } finally {
      isLoadingMoreComments.value = false;
    }
  }

  void updateSortMode(CommentSortMode nextMode) {
    if (sortMode.value == nextMode) return;

    sortMode.value = nextMode;
    _rebuildTopLevelOrder(comments);
    _rebuildThreadEntries();
  }

  void startReply(PostCommentModel comment) {
    replyingTo.value = comment;
    _expandThreadPath(comment.commentId);
    inputFocusNode.requestFocus();
  }

  void dismissComposer() {
    inputFocusNode.unfocus();
    if (inputController.text.trim().isEmpty) {
      replyingTo.value = null;
    }
  }

  void cancelReply() {
    replyingTo.value = null;
  }

  void toggleReplies(PostCommentModel comment) {
    if (comment.replyCount <= 0) return;

    final commentId = comment.commentId;
    final nextExpanded = Set<String>.from(expandedCommentIds);

    if (nextExpanded.contains(commentId)) {
      nextExpanded.remove(commentId);
      nextExpanded.removeAll(_descendantIdsOf(commentId));
      _replaceExpandedIds(nextExpanded);
      return;
    }

    if (_loadedReplyParentIds.contains(commentId) ||
        _hasLoadedChildren(commentId)) {
      _expandThreadPath(commentId);
      return;
    }

    if (loadingReplyParentIds.contains(commentId)) return;
    unawaited(_loadRepliesForParent(comment));
  }

  Future<void> toggleLike(PostCommentModel comment) async {
    final currentComment = _findComment(comment.commentId);
    if (currentComment == null) return;

    final shouldLike = !currentComment.isLiked;
    _replaceComment(
      currentComment.copyWith(
        isLiked: shouldLike,
        isLikePending: true,
        likeCount: _nextLikeCount(currentComment.likeCount, shouldLike),
      ),
    );

    _likeCache[comment.commentId] = shouldLike;
    _queuedLikeStates[comment.commentId] = shouldLike;
    unawaited(_syncLikeState(comment.commentId));
  }

  Future<void> submitComment() async {
    if (isSubmitting.value) return;

    final content = inputController.text.trim();
    if (content.isEmpty) return;

    isSubmitting.value = true;
    try {
      final created = await _service.addComment(
        postId: postId,
        content: content,
        parentId: replyingTo.value?.commentId,
      );

      _insertLocalComment(created);
      totalCommentCount.value += 1;
      inputController.clear();
      replyingTo.value = null;
      onCommentCountChanged?.call(1);
    } catch (error) {
      _showError(_mapError(error));
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> _loadMoreTopLevelComments({bool resetCursor = false}) async {
    final page = await _service.fetchTopLevelCommentsPage(
      postId,
      startAfter: resetCursor ? null : _topLevelCursor,
      limit: pageSize,
    );

    if (resetCursor) {
      comments.clear();
    }

    _topLevelCursor = page.nextCursor;
    hasMoreComments.value = page.hasMore;
    _upsertComments(page.comments, rebuildThreadEntries: false);
    if (resetCursor) {
      _rebuildTopLevelOrder(comments);
    } else {
      _appendTopLevelOrder(page.comments);
    }
    _rebuildThreadEntries();
  }

  Future<void> _loadRepliesForParent(PostCommentModel parentComment) async {
    final parentId = parentComment.commentId;
    _setReplyLoading(parentId, true);

    try {
      final replies = await _service.fetchReplies(postId, parentId);
      _loadedReplyParentIds.add(parentId);
      _upsertComments(replies);
      _expandThreadPath(parentId);
    } catch (error) {
      _showError(_mapError(error));
    } finally {
      _setReplyLoading(parentId, false);
    }
  }

  void _insertLocalComment(PostCommentModel comment) {
    _upsertComments(<PostCommentModel>[comment]);

    final parentId = comment.parentId;
    if (parentId != null) {
      final parent = _findComment(parentId);
      if (parent != null) {
        _replaceComment(parent.copyWith(replyCount: parent.replyCount + 1));
      }
      _expandThreadPath(parentId);
    } else {
      _pinTopLevelCommentToFront(comment.commentId);
    }
  }

  void _upsertComments(
    Iterable<PostCommentModel> incomingComments, {
    bool rebuildThreadEntries = true,
  }) {
    final nextComments = comments.toList(growable: true);
    var hasChanges = false;

    for (final incoming in incomingComments) {
      _mergeLikeCaches(incoming);

      final index = nextComments.indexWhere(
        (comment) => comment.commentId == incoming.commentId,
      );
      if (index == -1) {
        nextComments.add(incoming);
        hasChanges = true;
        continue;
      }

      final merged = _mergeCommentWithLocalState(
        existing: nextComments[index],
        incoming: incoming,
      );
      nextComments[index] = merged;
      hasChanges = true;
    }

    if (hasChanges) {
      comments.assignAll(nextComments);
      if (rebuildThreadEntries) {
        _rebuildThreadEntries();
      }
    }
  }

  PostCommentModel _mergeCommentWithLocalState({
    required PostCommentModel existing,
    required PostCommentModel incoming,
  }) {
    final commentId = incoming.commentId;
    final hasPendingLike =
        _queuedLikeStates.containsKey(commentId) ||
        _likeSyncingCommentIds.contains(commentId) ||
        existing.isLikePending;

    if (!hasPendingLike) {
      return incoming.copyWith(
        isLiked: _confirmedLikeStates[commentId] ?? incoming.isLiked,
      );
    }

    return incoming.copyWith(
      isLiked: existing.isLiked,
      isLikePending: existing.isLikePending,
      likeCount: existing.likeCount,
    );
  }

  void _mergeLikeCaches(PostCommentModel comment) {
    final commentId = comment.commentId;
    if (_queuedLikeStates.containsKey(commentId) ||
        _likeSyncingCommentIds.contains(commentId)) {
      return;
    }

    _likeCache[commentId] = comment.isLiked;
    _confirmedLikeStates[commentId] = comment.isLiked;
  }

  void _resetLoadedState() {
    comments.clear();
    expandedCommentIds.clear();
    loadingReplyParentIds.clear();
    _loadedReplyParentIds.clear();
    _topLevelOrderRanks.clear();
    _topLevelCursor = null;
    hasMoreComments.value = true;
    isLoadingMoreComments.value = false;
    threadEntries.clear();

    _likeCache.clear();
    _confirmedLikeStates.clear();
    _queuedLikeStates.clear();
    _likeSyncingCommentIds.clear();
  }

  void _expandThreadPath(String commentId) {
    final nextExpanded = Set<String>.from(expandedCommentIds);
    String? currentId = commentId;

    while (currentId != null && currentId.isNotEmpty) {
      nextExpanded.add(currentId);
      currentId = _parentIdOf(currentId);
    }

    _replaceExpandedIds(nextExpanded);
  }

  String? _parentIdOf(String commentId) {
    final comment = _findComment(commentId);
    return comment?.parentId;
  }

  bool _hasLoadedChildren(String commentId) {
    return comments.any((item) => item.parentId == commentId);
  }

  PostCommentModel? _findComment(String commentId) {
    for (final comment in comments) {
      if (comment.commentId == commentId) return comment;
    }
    return null;
  }

  void _replaceComment(PostCommentModel updatedComment) {
    final nextComments = comments.toList(growable: true);
    final index = nextComments.indexWhere(
      (comment) => comment.commentId == updatedComment.commentId,
    );
    if (index == -1) return;

    nextComments[index] = updatedComment;
    comments.assignAll(nextComments);
    _rebuildThreadEntries();
  }

  bool _isLikeSyncPending(String commentId) {
    return _queuedLikeStates.containsKey(commentId) ||
        _likeSyncingCommentIds.contains(commentId);
  }

  Future<void> _syncLikeState(String commentId) async {
    if (_likeSyncingCommentIds.contains(commentId)) return;

    _likeSyncingCommentIds.add(commentId);
    _updateLikePendingState(commentId);

    try {
      while (true) {
        final targetState = _queuedLikeStates[commentId];
        if (targetState == null) break;

        final confirmedState = _confirmedLikeStates[commentId] ?? false;
        if (targetState == confirmedState) {
          _queuedLikeStates.remove(commentId);
          _updateLikePendingState(commentId);
          continue;
        }

        try {
          if (targetState) {
            await _service.likeComment(postId, commentId);
          } else {
            await _service.unlikeComment(postId, commentId);
          }

          _confirmedLikeStates[commentId] = targetState;
          if (_queuedLikeStates[commentId] == targetState) {
            _queuedLikeStates.remove(commentId);
          }
        } catch (error) {
          _queuedLikeStates.remove(commentId);
          _revertLikeState(commentId);
          _showError(_mapError(error));
          break;
        }
      }
    } finally {
      _likeSyncingCommentIds.remove(commentId);
      _updateLikePendingState(commentId);
      if (_queuedLikeStates.containsKey(commentId)) {
        unawaited(_syncLikeState(commentId));
      }
    }
  }

  void _updateLikePendingState(String commentId) {
    final currentComment = _findComment(commentId);
    if (currentComment == null) return;

    final shouldBePending = _isLikeSyncPending(commentId);
    if (currentComment.isLikePending == shouldBePending) return;

    _replaceComment(currentComment.copyWith(isLikePending: shouldBePending));
  }

  void _revertLikeState(String commentId) {
    final currentComment = _findComment(commentId);
    if (currentComment == null) return;

    final confirmedState = _confirmedLikeStates[commentId] ?? false;
    _likeCache[commentId] = confirmedState;

    final resolvedLikeCount =
        currentComment.isLiked == confirmedState
            ? currentComment.likeCount
            : _nextLikeCount(currentComment.likeCount, confirmedState);

    _replaceComment(
      currentComment.copyWith(
        isLiked: confirmedState,
        isLikePending: false,
        likeCount: resolvedLikeCount,
      ),
    );
  }

  Set<String> _descendantIdsOf(String commentId) {
    final descendants = <String>{};
    final pending = <String>[commentId];

    while (pending.isNotEmpty) {
      final parentId = pending.removeLast();
      final children = comments
          .where((item) => item.parentId == parentId)
          .map((item) => item.commentId)
          .toList(growable: false);

      for (final childId in children) {
        if (!descendants.add(childId)) continue;
        pending.add(childId);
      }
    }

    return descendants;
  }

  void _replaceExpandedIds(Set<String> nextExpanded) {
    expandedCommentIds
      ..clear()
      ..addAll(nextExpanded);
    _rebuildThreadEntries();
  }

  void _setReplyLoading(String commentId, bool isLoadingReply) {
    if (isLoadingReply) {
      loadingReplyParentIds.add(commentId);
    } else {
      loadingReplyParentIds.remove(commentId);
    }
    loadingReplyParentIds.refresh();
  }

  int _compareThreadComments({
    required String? parentId,
    required CommentSortMode currentSortMode,
    required PostCommentModel a,
    required PostCommentModel b,
  }) {
    if (parentId != null) {
      return _compareByCreatedAt(a, b, descending: false);
    }

    final rankedComparison = _compareByTopLevelOrderRank(a, b);
    if (rankedComparison != null) return rankedComparison;

    switch (currentSortMode) {
      case CommentSortMode.featured:
        return _compareByFeaturedScore(a, b);
      case CommentSortMode.newest:
        return _compareByCreatedAt(a, b, descending: true);
    }
  }

  int _compareByFeaturedScore(PostCommentModel a, PostCommentModel b) {
    final now = DateTime.now();
    final aScore = _featuredScore(a, now);
    final bScore = _featuredScore(b, now);
    final scoreComparison = bScore.compareTo(aScore);
    if (scoreComparison != 0) return scoreComparison;

    final replyComparison = b.replyCount.compareTo(a.replyCount);
    if (replyComparison != 0) return replyComparison;

    final likeComparison = b.likeCount.compareTo(a.likeCount);
    if (likeComparison != 0) return likeComparison;

    return _compareByCreatedAt(a, b, descending: true);
  }

  int? _compareByTopLevelOrderRank(PostCommentModel a, PostCommentModel b) {
    final aRank = _topLevelOrderRanks[a.commentId];
    final bRank = _topLevelOrderRanks[b.commentId];
    if (aRank == null && bRank == null) return null;
    if (aRank == null) return 1;
    if (bRank == null) return -1;

    final rankComparison = aRank.compareTo(bRank);
    if (rankComparison != 0) return rankComparison;
    return null;
  }

  void _rebuildTopLevelOrder(Iterable<PostCommentModel> source) {
    final topLevelComments = source
        .where((comment) => !comment.isReply)
        .toList(growable: true);

    topLevelComments.sort(_compareTopLevelByCurrentMode);

    _topLevelOrderRanks
      ..clear()
      ..addEntries(
        topLevelComments.indexed.map(
          (entry) => MapEntry(entry.$2.commentId, entry.$1),
        ),
      );
  }

  void _appendTopLevelOrder(Iterable<PostCommentModel> source) {
    final newTopLevelComments = source
        .where((comment) => !comment.isReply)
        .where((comment) => !_topLevelOrderRanks.containsKey(comment.commentId))
        .toList(growable: true);

    if (newTopLevelComments.isEmpty) return;

    newTopLevelComments.sort(_compareTopLevelByCurrentMode);

    var nextRank =
        _topLevelOrderRanks.isEmpty
            ? 0
            : _topLevelOrderRanks.values.reduce(max) + 1;

    for (final comment in newTopLevelComments) {
      _topLevelOrderRanks[comment.commentId] = nextRank;
      nextRank += 1;
    }
  }

  void _pinTopLevelCommentToFront(String commentId) {
    if (_topLevelOrderRanks.isEmpty) {
      _topLevelOrderRanks[commentId] = 0;
      return;
    }

    final currentMinRank = _topLevelOrderRanks.values.reduce(min);
    _topLevelOrderRanks[commentId] = currentMinRank - 1;
  }

  int _compareTopLevelByCurrentMode(PostCommentModel a, PostCommentModel b) {
    switch (sortMode.value) {
      case CommentSortMode.featured:
        return _compareByFeaturedScore(a, b);
      case CommentSortMode.newest:
        return _compareByCreatedAt(a, b, descending: true);
    }
  }

  double _featuredScore(PostCommentModel comment, DateTime now) {
    final createdAt = comment.createdAt;
    if (createdAt == null) return 0;

    final ageInHours = max(
      0.0,
      now.difference(createdAt).inMinutes / Duration.minutesPerHour,
    );
    final engagement = comment.likeCount + (2 * comment.replyCount);
    final decay = pow(ageInHours + 2, 1.2).toDouble();
    return engagement / decay;
  }

  int _compareByCreatedAt(
    PostCommentModel a,
    PostCommentModel b, {
    required bool descending,
  }) {
    final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final timeComparison =
        descending ? bTime.compareTo(aTime) : aTime.compareTo(bTime);
    if (timeComparison != 0) return timeComparison;

    return a.commentId.compareTo(b.commentId);
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

    return 'Không thể xử lý bình luận lúc này. Vui lòng thử lại.';
  }

  void _showError(String message) {
    Get.snackbar(
      'Lỗi',
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
    );
  }

  void _handleInputChanged() {
    final nextState = inputController.text.trim().isNotEmpty;
    if (hasInputText.value == nextState) return;
    hasInputText.value = nextState;
  }

  @override
  void onClose() {
    inputController.removeListener(_handleInputChanged);
    inputController.dispose();
    inputFocusNode.dispose();
    super.onClose();
  }
}

class CommentThreadEntry {
  const CommentThreadEntry({
    required this.comment,
    required this.depth,
    required this.ancestorBranchContinues,
    required this.hasNextSibling,
    required this.hasChildren,
    required this.isExpanded,
  });

  final PostCommentModel comment;
  final int depth;
  final List<bool> ancestorBranchContinues;
  final bool hasNextSibling;
  final bool hasChildren;
  final bool isExpanded;
}
