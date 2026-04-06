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

  List<CommentThreadEntry> get threadEntries {
    final sorted = comments.toList(growable: false)..sort((a, b) {
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aTime.compareTo(bTime);
    });

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

    void visit(String? parentId, int depth) {
      final children = groupedByParent[parentId];
      if (children == null || children.isEmpty) return;

      for (final comment in children) {
        flattened.add(CommentThreadEntry(comment: comment, depth: depth));
        visit(comment.commentId, depth + 1);
      }
    }

    visit(null, 0);
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
    inputFocusNode.requestFocus();
  }

  void cancelReply() {
    replyingTo.value = null;
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
    }

    comments.refresh();
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
  const CommentThreadEntry({required this.comment, required this.depth});

  final PostCommentModel comment;
  final int depth;
}
