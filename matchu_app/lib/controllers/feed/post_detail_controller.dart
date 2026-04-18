import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/feed/feed_controller.dart';
import 'package:matchu_app/controllers/feed/post_comments_controller.dart';
import 'package:matchu_app/models/feed/post_detail_route_args.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/services/feed/post_service.dart';
import 'package:matchu_app/translates/firebase_error_translator.dart';

class PostDetailController extends GetxController {
  PostDetailController({
    required this.args,
    PostService? postService,
    FeedController? feedController,
  }) : _postService = postService ?? PostService(),
       _feedController =
           feedController ??
           (Get.isRegistered<FeedController>()
               ? Get.find<FeedController>()
               : null),
       post = args.post.obs;

  final PostDetailRouteArgs args;
  final PostService _postService;
  final FeedController? _feedController;
  final Rx<PostModel> post;

  late final String commentsTag =
      'post_detail_comments_${args.post.postId}_${DateTime.now().microsecondsSinceEpoch}';
  late final PostCommentsController commentsController;

  Worker? _feedWorker;

  String get postId => post.value.postId;

  @override
  void onInit() {
    super.onInit();

    commentsController = Get.put(
      PostCommentsController(
        postId: args.post.postId,
        onCommentCountChanged: adjustCommentCount,
        initialCommentCount: args.post.stats.commentCount,
      ),
      tag: commentsTag,
    );

    _syncPostFromFeed();
    final feedController = _feedController;
    if (feedController != null) {
      _feedWorker = ever<List<PostModel>>(
        feedController.posts,
        (_) => _syncPostFromFeed(),
      );
    }
  }

  Future<void> toggleLike() async {
    final feedController = _feedController;
    if (feedController != null && feedController.findPostById(postId) != null) {
      await feedController.toggleLike(postId);
      _syncPostFromFeed();
      return;
    }

    await _toggleLikeFallback();
  }

  void sharePost() {
    final feedController = _feedController;
    if (feedController != null) {
      feedController.onShareTap();
      return;
    }

    Get.snackbar(
      'Thông báo',
      'Tính năng chia sẻ sẽ được cập nhật ở bước tiếp theo.',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
    );
  }

  void dismissCommentComposer() {
    commentsController.dismissComposer();
  }

  void adjustCommentCount(int delta) {
    final currentPost = post.value;
    final nextCount = currentPost.stats.commentCount + delta;

    post.value = currentPost.copyWith(
      stats: currentPost.stats.copyWith(
        commentCount: nextCount < 0 ? 0 : nextCount,
      ),
    );

    _feedController?.adjustCommentCount(postId, delta: delta);
  }

  void _syncPostFromFeed() {
    final latestPost = _feedController?.findPostById(postId);
    if (latestPost == null) return;
    post.value = latestPost;
  }

  Future<void> _toggleLikeFallback() async {
    final currentPost = post.value;
    final shouldLike = !currentPost.isLiked;

    post.value = currentPost.copyWith(
      isLiked: shouldLike,
      isLikePending: true,
      stats: currentPost.stats.copyWith(
        likeCount: _nextLikeCount(currentPost.stats.likeCount, shouldLike),
      ),
    );

    try {
      if (shouldLike) {
        await _postService.likePost(postId);
      } else {
        await _postService.unlikePost(postId);
      }

      post.value = post.value.copyWith(isLikePending: false);
    } catch (error) {
      post.value = currentPost;
      _showError(_mapError(error));
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

    return 'Không thể xử lý bài viết lúc này. Vui lòng thử lại.';
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
    _feedWorker?.dispose();
    if (Get.isRegistered<PostCommentsController>(tag: commentsTag)) {
      Get.delete<PostCommentsController>(tag: commentsTag, force: true);
    }
    super.onClose();
  }
}
