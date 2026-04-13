import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/models/feed/post_comment_model.dart';
import 'package:matchu_app/services/feed/post_comment_service.dart';

class PostCommentsController extends GetxController {
  PostCommentsController({
    required this.postId,
    this.onCommentCountChanged,
    PostCommentService? service,
  }) : _service = service ?? PostCommentService();

  final String postId;
  final ValueChanged<int>? onCommentCountChanged;
  final PostCommentService _service;

  final TextEditingController inputController = TextEditingController();
  final FocusNode inputFocusNode = FocusNode();

  final RxList<PostCommentModel> comments = <PostCommentModel>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool isSubmitting = false.obs;
  final RxBool hasInputText = false.obs;
  final RxnString errorMessage = RxnString();
  final Rxn<PostCommentModel> replyingTo = Rxn<PostCommentModel>();
  final RxSet<String> expandedCommentIds = <String>{}.obs;

  List<CommentThreadEntry> get threadEntries {
    final sorted = comments.toList(growable: false)..sort((a, b) {
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aTime.compareTo(bTime);
    });
    final expandedIds = Set<String>.from(expandedCommentIds);

    final existingIds = sorted.map((comment) => comment.commentId).toSet();
    final groupedByParent = <String?, List<PostCommentModel>>{};

    for (final comment in sorted) {
      final parentId =
          comment.parentId != null && existingIds.contains(comment.parentId)
              ? comment.parentId
              : null;

      groupedByParent
          .putIfAbsent(parentId, () => <PostCommentModel>[])
          .add(comment);
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
        final hasNextSibling = index < children.length - 1;
        final hasChildren =
            groupedByParent[comment.commentId]?.isNotEmpty ?? false;
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
    return flattened;
  }

  @override
  void onInit() {
    super.onInit();
    inputController.addListener(_handleInputChanged);
    _handleInputChanged();
    loadComments();
  }

  Future<void> loadComments() async {
    try {
      isLoading.value = true;
      errorMessage.value = null;
      expandedCommentIds.clear();
      final loadedComments = await _service.fetchComments(postId);
      comments.assignAll(loadedComments);
    } catch (error) {
      errorMessage.value = error.toString();
    } finally {
      isLoading.value = false;
    }
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
    if (!_hasChildren(comment.commentId)) return;

    final nextExpanded = Set<String>.from(expandedCommentIds);
    if (nextExpanded.contains(comment.commentId)) {
      nextExpanded.remove(comment.commentId);
      nextExpanded.removeAll(_descendantIdsOf(comment.commentId));
    } else {
      nextExpanded.add(comment.commentId);
    }
    _replaceExpandedIds(nextExpanded);
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
      inputController.clear();
      replyingTo.value = null;
      onCommentCountChanged?.call(1);
    } catch (error) {
      Get.snackbar(
        'Lỗi',
        error.toString(),
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    } finally {
      isSubmitting.value = false;
    }
  }

  void _insertLocalComment(PostCommentModel comment) {
    comments.add(comment);

    final parentId = comment.parentId;
    if (parentId != null) {
      final index = comments.indexWhere((item) => item.commentId == parentId);
      if (index != -1) {
        final parent = comments[index];
        comments[index] = parent.copyWith(replyCount: parent.replyCount + 1);
      }
      _expandThreadPath(parentId);
    }

    comments.refresh();
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
    final index = comments.indexWhere((item) => item.commentId == commentId);
    if (index == -1) return null;
    return comments[index].parentId;
  }

  bool _hasChildren(String commentId) {
    return comments.any((item) => item.parentId == commentId);
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
