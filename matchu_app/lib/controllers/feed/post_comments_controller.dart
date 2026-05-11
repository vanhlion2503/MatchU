import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:matchu_app/controllers/user/user_controller.dart';
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
    required this.postAuthorId,
    this.onCommentCountChanged,
    this.initialCommentCount = 0,
    this.pageSize = PostCommentService.defaultTopLevelPageSize,
    PostCommentService? service,
  }) : _service = service ?? PostCommentService();

  final String postId;
  final String postAuthorId;
  final ValueChanged<int>? onCommentCountChanged;
  final int initialCommentCount;
  final int pageSize;
  final PostCommentService _service;
  final GetStorage _storage = GetStorage();

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
  final Rxn<PostCommentModel> editingComment = Rxn<PostCommentModel>();
  final RxSet<String> expandedCommentIds = <String>{}.obs;
  final RxSet<String> loadingReplyParentIds = <String>{}.obs;
  final RxSet<String> hiddenCommentIds = <String>{}.obs;
  final RxSet<String> actioningCommentIds = <String>{}.obs;
  final RxInt totalCommentCount = 0.obs;
  final Rx<CommentSortMode> sortMode = CommentSortMode.featured.obs;

  final Map<String, bool> _likeCache = <String, bool>{};
  final Map<String, bool> _confirmedLikeStates = <String, bool>{};
  final Map<String, bool> _queuedLikeStates = <String, bool>{};
  final Set<String> _likeSyncingCommentIds = <String>{};
  final Set<String> _loadedReplyParentIds = <String>{};
  final Map<String, int> _topLevelOrderRanks = <String, int>{};
  int _optimisticCommentSequence = 0;

  DocumentSnapshot<Map<String, dynamic>>? _topLevelCursor;

  void _rebuildThreadEntries() {
    final expandedIds = Set<String>.from(expandedCommentIds);
    final currentSortMode = sortMode.value;
    final allComments = comments.toList(growable: false);
    final currentComments = _visibleCommentsForThread(allComments);
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

  List<PostCommentModel> _visibleCommentsForThread(
    List<PostCommentModel> source,
  ) {
    if (source.isEmpty) return const <PostCommentModel>[];

    final commentById = <String, PostCommentModel>{
      for (final comment in source) comment.commentId: comment,
    };
    final hiddenIds = Set<String>.from(hiddenCommentIds);
    final suppressedCache = <String, bool>{};

    bool isSuppressed(PostCommentModel comment) {
      final cached = suppressedCache[comment.commentId];
      if (cached != null) return cached;

      if (hiddenIds.contains(comment.commentId)) {
        suppressedCache[comment.commentId] = true;
        return true;
      }

      final parentId = comment.parentId;
      if (parentId == null || parentId.isEmpty) {
        suppressedCache[comment.commentId] = false;
        return false;
      }

      final parent = commentById[parentId];
      final isParentSuppressed = parent != null && isSuppressed(parent);
      suppressedCache[comment.commentId] = isParentSuppressed;
      return isParentSuppressed;
    }

    bool hasVisibleLoadedChild(PostCommentModel comment) {
      return source.any(
        (candidate) =>
            candidate.parentId == comment.commentId &&
            !isSuppressed(candidate) &&
            (!candidate.isDeleted ||
                candidate.replyCount > 0 ||
                hasVisibleLoadedChild(candidate)),
      );
    }

    return source
        .where((comment) => !isSuppressed(comment))
        .where(
          (comment) =>
              !comment.isDeleted ||
              comment.replyCount > 0 ||
              hasVisibleLoadedChild(comment),
        )
        .toList(growable: false);
  }

  @override
  void onInit() {
    super.onInit();
    _loadHiddenCommentIds();
    totalCommentCount.value = initialCommentCount;
    inputController.addListener(_handleInputChanged);
    _handleInputChanged();
    loadComments();
  }

  bool isReplyLoading(String commentId) {
    return loadingReplyParentIds.contains(commentId);
  }

  bool isCommentActioning(String commentId) {
    return actioningCommentIds.contains(commentId);
  }

  String get currentUserId => _service.uid.trim();

  bool canEditComment(PostCommentModel comment) {
    final uid = currentUserId;
    if (uid.isEmpty || comment.isSending || comment.isDeleted) return false;
    return comment.userId.trim() == uid;
  }

  bool canDeleteComment(PostCommentModel comment) {
    final uid = currentUserId;
    if (uid.isEmpty || comment.isSending || comment.isDeleted) return false;
    return comment.userId.trim() == uid || postAuthorId.trim() == uid;
  }

  bool canHideComment(PostCommentModel comment) {
    final uid = currentUserId;
    if (comment.isSending || comment.isDeleted) return false;
    if (hiddenCommentIds.contains(comment.commentId)) return false;
    return comment.userId.trim() != uid && postAuthorId.trim() != uid;
  }

  bool hasCommentActions(PostCommentModel comment) {
    return canEditComment(comment) ||
        canDeleteComment(comment) ||
        canHideComment(comment);
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
    if (comment.isDeleted || comment.isSending) return;
    if (editingComment.value != null) {
      editingComment.value = null;
      inputController.clear();
    }
    replyingTo.value = comment;
    _expandThreadPath(comment.commentId);
    inputFocusNode.requestFocus();
  }

  void startEdit(PostCommentModel comment) {
    final currentComment = _findComment(comment.commentId);
    if (currentComment == null || !canEditComment(currentComment)) return;

    replyingTo.value = null;
    editingComment.value = currentComment;
    inputController.text = currentComment.content;
    inputController.selection = TextSelection.collapsed(
      offset: inputController.text.length,
    );
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

  void cancelEdit() {
    editingComment.value = null;
    inputController.clear();
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
    if (currentComment.isSending) return;

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

    final commentBeingEdited = editingComment.value;
    if (commentBeingEdited != null) {
      await _submitEditedComment(commentBeingEdited);
      return;
    }

    final currentUid = _service.uid.trim();
    if (currentUid.isEmpty) {
      _showError('Bạn cần đăng nhập để bình luận.');
      return;
    }

    final content = inputController.text.trim();
    if (content.isEmpty) return;

    final parentId = replyingTo.value?.commentId;
    final optimisticComment = _createOptimisticComment(
      userId: currentUid,
      content: content,
      parentId: parentId,
    );

    isSubmitting.value = true;
    _insertLocalComment(optimisticComment);
    totalCommentCount.value += 1;
    onCommentCountChanged?.call(1);
    inputController.clear();
    replyingTo.value = null;

    try {
      final created = await _service.addComment(
        postId: postId,
        content: content,
        parentId: parentId,
      );
      _resolveOptimisticComment(
        optimisticCommentId: optimisticComment.commentId,
        serverComment: created,
      );
    } catch (error) {
      _rollbackOptimisticComment(optimisticComment.commentId);
      totalCommentCount.value = max(0, totalCommentCount.value - 1);
      onCommentCountChanged?.call(-1);
      _showError(_mapError(error));
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> _submitEditedComment(PostCommentModel editingTarget) async {
    final currentUid = _service.uid.trim();
    if (currentUid.isEmpty) {
      _showError('Bạn cần đăng nhập để chỉnh sửa bình luận.');
      return;
    }

    final currentComment = _findComment(editingTarget.commentId);
    if (currentComment == null || !canEditComment(currentComment)) {
      editingComment.value = null;
      inputController.clear();
      return;
    }

    final content = inputController.text.trim();
    if (content.isEmpty) return;

    if (content == currentComment.content.trim()) {
      cancelEdit();
      return;
    }

    final editedAt = DateTime.now();
    final optimisticComment = currentComment.copyWith(
      content: content,
      isEdited: true,
      updatedAt: editedAt,
    );

    isSubmitting.value = true;
    _replaceComment(optimisticComment);
    editingComment.value = null;
    inputController.clear();

    try {
      final updatedComment = await _service.editComment(
        postId: postId,
        commentId: currentComment.commentId,
        content: content,
      );
      final latestComment = _findComment(currentComment.commentId);
      _replaceComment(
        updatedComment.copyWith(
          author: latestComment?.author ?? currentComment.author,
          likeCount: latestComment?.likeCount ?? currentComment.likeCount,
          replyCount: latestComment?.replyCount ?? currentComment.replyCount,
          isLiked: latestComment?.isLiked ?? currentComment.isLiked,
          isLikePending:
              latestComment?.isLikePending ?? currentComment.isLikePending,
          isSending: false,
        ),
      );
    } catch (error) {
      _replaceComment(currentComment);
      editingComment.value = currentComment;
      inputController.text = content;
      inputController.selection = TextSelection.collapsed(
        offset: inputController.text.length,
      );
      inputFocusNode.requestFocus();
      _showError(_mapError(error));
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> deleteComment(PostCommentModel comment) async {
    final currentComment = _findComment(comment.commentId);
    if (currentComment == null || !canDeleteComment(currentComment)) return;
    if (actioningCommentIds.contains(currentComment.commentId)) return;

    final commentId = currentComment.commentId;
    final previousRank = _topLevelOrderRanks[commentId];
    final shouldKeepPlaceholder =
        currentComment.replyCount > 0 || _hasLoadedChildren(commentId);
    final deletedAt = DateTime.now();
    final deletedComment = currentComment.copyWith(
      content: '',
      deletedAt: deletedAt,
      deletedBy: currentUserId,
      updatedAt: deletedAt,
    );

    actioningCommentIds.add(commentId);
    actioningCommentIds.refresh();
    _clearComposerTarget(commentId);

    if (shouldKeepPlaceholder) {
      _replaceComment(deletedComment, rebuildThreadEntries: false);
    } else {
      _removeCommentById(commentId);
      _topLevelOrderRanks.remove(commentId);
      _clearLikeCachesForComment(commentId);
      _removeExpandedCommentAndDescendants(commentId);
    }

    _adjustLoadedParentReplyCount(currentComment.parentId, -1);
    totalCommentCount.value = max(0, totalCommentCount.value - 1);
    onCommentCountChanged?.call(-1);
    _rebuildThreadEntries();

    try {
      final serverComment = await _service.deleteComment(
        postId: postId,
        commentId: commentId,
      );
      if (shouldKeepPlaceholder) {
        final latestComment = _findComment(commentId);
        if (latestComment != null) {
          _replaceComment(
            serverComment.copyWith(
              author: latestComment.author ?? currentComment.author,
              likeCount: latestComment.likeCount,
              replyCount: latestComment.replyCount,
              isLiked: latestComment.isLiked,
              isLikePending: latestComment.isLikePending,
              isSending: false,
            ),
          );
        }
      }
    } catch (error) {
      _upsertComments(<PostCommentModel>[
        currentComment,
      ], rebuildThreadEntries: false);
      if (previousRank != null) {
        _topLevelOrderRanks[commentId] = previousRank;
      }
      _adjustLoadedParentReplyCount(currentComment.parentId, 1);
      totalCommentCount.value += 1;
      onCommentCountChanged?.call(1);
      _rebuildThreadEntries();
      _showError(_mapError(error));
    } finally {
      actioningCommentIds.remove(commentId);
      actioningCommentIds.refresh();
    }
  }

  Future<void> hideComment(PostCommentModel comment) async {
    final currentComment = _findComment(comment.commentId);
    if (currentComment == null || !canHideComment(currentComment)) return;

    hiddenCommentIds.add(currentComment.commentId);
    hiddenCommentIds.refresh();
    await _persistHiddenCommentIds();
    _clearComposerTarget(currentComment.commentId);
    _rebuildThreadEntries();

    Get.snackbar(
      'Thông báo',
      'Đã ẩn bình luận này khỏi thiết bị của bạn.',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
    );
  }

  PostCommentModel _createOptimisticComment({
    required String userId,
    required String content,
    required String? parentId,
  }) {
    final normalizedParentId = parentId?.trim();
    final resolvedParentId =
        normalizedParentId == null || normalizedParentId.isEmpty
            ? null
            : normalizedParentId;

    return PostCommentModel(
      commentId:
          '__local_comment_${DateTime.now().microsecondsSinceEpoch}_${_optimisticCommentSequence++}',
      userId: userId,
      content: content,
      parentId: resolvedParentId,
      likeCount: 0,
      replyCount: 0,
      createdAt: DateTime.now(),
      author: _currentUserAuthor(userId),
      isSending: true,
    );
  }

  void _resolveOptimisticComment({
    required String optimisticCommentId,
    required PostCommentModel serverComment,
  }) {
    final nextComments = comments.toList(growable: true);
    final index = nextComments.indexWhere(
      (comment) => comment.commentId == optimisticCommentId,
    );

    if (index == -1) {
      _topLevelOrderRanks.remove(optimisticCommentId);
      if (expandedCommentIds.contains(optimisticCommentId)) {
        expandedCommentIds.remove(optimisticCommentId);
        expandedCommentIds.refresh();
      }
      _clearLikeCachesForComment(optimisticCommentId);
      _upsertComments(<PostCommentModel>[
        serverComment.copyWith(isSending: false),
      ], rebuildThreadEntries: false);
      if (!serverComment.isReply &&
          !_topLevelOrderRanks.containsKey(serverComment.commentId)) {
        _pinTopLevelCommentToFront(serverComment.commentId);
      }
      _rebuildThreadEntries();
      return;
    }

    final optimisticComment = nextComments[index];
    nextComments[index] = serverComment.copyWith(
      isSending: false,
      isLiked: optimisticComment.isLiked,
      isLikePending: optimisticComment.isLikePending,
    );
    comments.assignAll(nextComments);

    _replaceTopLevelCommentId(
      oldCommentId: optimisticCommentId,
      newCommentId: serverComment.commentId,
    );
    _replaceExpandedCommentId(
      oldCommentId: optimisticCommentId,
      newCommentId: serverComment.commentId,
    );
    _clearLikeCachesForComment(optimisticCommentId);
    _rebuildThreadEntries();
  }

  void _rollbackOptimisticComment(String optimisticCommentId) {
    final removedComment = _removeCommentById(optimisticCommentId);
    if (removedComment == null) return;

    _topLevelOrderRanks.remove(optimisticCommentId);
    _clearLikeCachesForComment(optimisticCommentId);
    if (expandedCommentIds.contains(optimisticCommentId)) {
      expandedCommentIds.remove(optimisticCommentId);
      expandedCommentIds.refresh();
    }

    final parentId = removedComment.parentId;
    if (parentId != null) {
      final parent = _findComment(parentId);
      if (parent != null && parent.replyCount > 0) {
        _replaceComment(parent.copyWith(replyCount: parent.replyCount - 1));
        return;
      }
    }

    _rebuildThreadEntries();
  }

  void _adjustLoadedParentReplyCount(String? parentId, int delta) {
    final normalizedParentId = parentId?.trim();
    if (normalizedParentId == null || normalizedParentId.isEmpty) return;

    final parent = _findComment(normalizedParentId);
    if (parent == null) return;

    final nextReplyCount = max(0, parent.replyCount + delta);
    _replaceComment(
      parent.copyWith(replyCount: nextReplyCount),
      rebuildThreadEntries: false,
    );
  }

  void _clearComposerTarget(String commentId) {
    if (replyingTo.value?.commentId == commentId) {
      replyingTo.value = null;
    }
    if (editingComment.value?.commentId == commentId) {
      editingComment.value = null;
      inputController.clear();
    }
  }

  void _removeExpandedCommentAndDescendants(String commentId) {
    if (!expandedCommentIds.contains(commentId)) return;

    final nextExpanded =
        Set<String>.from(expandedCommentIds)
          ..remove(commentId)
          ..removeAll(_descendantIdsOf(commentId));
    expandedCommentIds
      ..clear()
      ..addAll(nextExpanded);
    expandedCommentIds.refresh();
  }

  PostCommentModel? _removeCommentById(String commentId) {
    final nextComments = comments.toList(growable: true);
    final index = nextComments.indexWhere(
      (comment) => comment.commentId == commentId,
    );
    if (index == -1) return null;

    final removed = nextComments.removeAt(index);
    comments.assignAll(nextComments);
    return removed;
  }

  void _replaceTopLevelCommentId({
    required String oldCommentId,
    required String newCommentId,
  }) {
    final rank = _topLevelOrderRanks.remove(oldCommentId);
    if (rank == null) return;
    _topLevelOrderRanks[newCommentId] = rank;
  }

  void _replaceExpandedCommentId({
    required String oldCommentId,
    required String newCommentId,
  }) {
    if (!expandedCommentIds.contains(oldCommentId)) return;

    final nextExpanded =
        Set<String>.from(expandedCommentIds)
          ..remove(oldCommentId)
          ..add(newCommentId);
    expandedCommentIds
      ..clear()
      ..addAll(nextExpanded);
  }

  void _clearLikeCachesForComment(String commentId) {
    _likeCache.remove(commentId);
    _confirmedLikeStates.remove(commentId);
    _queuedLikeStates.remove(commentId);
    _likeSyncingCommentIds.remove(commentId);
  }

  PostCommentAuthorModel _currentUserAuthor(String userId) {
    if (Get.isRegistered<UserController>()) {
      final user = Get.find<UserController>().userRx.value;
      if (user != null) {
        return PostCommentAuthorModel.fromUser(user, userId);
      }
    }

    for (final comment in comments) {
      if (comment.userId == userId && comment.author != null) {
        return comment.author!;
      }
    }

    return PostCommentAuthorModel(
      userId: userId,
      displayName: 'Bạn',
      nickname: '',
      avatarUrl: '',
      isVerified: false,
    );
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
    _upsertComments(<PostCommentModel>[comment], rebuildThreadEntries: false);

    final parentId = comment.parentId;
    if (parentId != null) {
      final parent = _findComment(parentId);
      if (parent != null) {
        _replaceComment(
          parent.copyWith(replyCount: parent.replyCount + 1),
          rebuildThreadEntries: false,
        );
      }
      _expandThreadPath(parentId);
    } else {
      _pinTopLevelCommentToFront(comment.commentId);
      _rebuildThreadEntries();
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

  String get _hiddenCommentsStorageKey {
    final uidPart = currentUserId.isEmpty ? 'anonymous' : currentUserId;
    final postPart = postId.trim().isEmpty ? 'unknown_post' : postId.trim();
    return 'post_hidden_comments_${uidPart}_$postPart';
  }

  void _loadHiddenCommentIds() {
    final storedValue = _storage.read(_hiddenCommentsStorageKey);
    if (storedValue is! List) {
      hiddenCommentIds.clear();
      return;
    }

    hiddenCommentIds
      ..clear()
      ..addAll(
        storedValue
            .map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty),
      );
    hiddenCommentIds.refresh();
  }

  Future<void> _persistHiddenCommentIds() {
    final values = hiddenCommentIds.toList(growable: false);
    return _storage.write(_hiddenCommentsStorageKey, values);
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

  void _replaceComment(
    PostCommentModel updatedComment, {
    bool rebuildThreadEntries = true,
  }) {
    final nextComments = comments.toList(growable: true);
    final index = nextComments.indexWhere(
      (comment) => comment.commentId == updatedComment.commentId,
    );
    if (index == -1) return;

    nextComments[index] = updatedComment;
    comments.assignAll(nextComments);
    if (rebuildThreadEntries) {
      _rebuildThreadEntries();
    }
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
