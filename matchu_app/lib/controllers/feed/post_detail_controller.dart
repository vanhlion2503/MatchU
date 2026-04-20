import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/feed/feed_controller.dart';
import 'package:matchu_app/controllers/feed/post_comments_controller.dart';
import 'package:matchu_app/controllers/profile/profile_posts_controller.dart';
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
       _profilePostsController =
           args.profilePostsControllerTag != null &&
                   Get.isRegistered<ProfilePostsController>(
                     tag: args.profilePostsControllerTag,
                   )
               ? Get.find<ProfilePostsController>(
                 tag: args.profilePostsControllerTag,
               )
               : null,
       post = args.post.obs;

  final PostDetailRouteArgs args;
  final PostService _postService;
  final FeedController? _feedController;
  final ProfilePostsController? _profilePostsController;
  final Rx<PostModel> post;

  late final String commentsTag =
      'post_detail_comments_${args.post.postId}_${DateTime.now().microsecondsSinceEpoch}';
  late final PostCommentsController commentsController;

  Worker? _feedWorker;
  Worker? _profileWorker;

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

    _syncPostFromSources();
    final feedController = _feedController;
    if (feedController != null) {
      _feedWorker = ever<List<PostModel>>(
        feedController.posts,
        (_) => _syncPostFromSources(),
      );
    }

    final profilePostsController = _profilePostsController;
    if (profilePostsController != null) {
      _profileWorker = ever<List<PostModel>>(
        profilePostsController.posts,
        (_) => _syncPostFromSources(),
      );
    }
  }

  Future<void> toggleLike() async {
    final profilePostsController = _profilePostsController;
    if (profilePostsController != null &&
        profilePostsController.findPostById(postId) != null) {
      await profilePostsController.toggleLike(postId);
      _syncPostFromSources();
      return;
    }

    final feedController = _feedController;
    if (feedController != null && feedController.findPostById(postId) != null) {
      await feedController.toggleLike(postId);
      _syncPostFromSources();
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

  Future<PostModel?> repostCurrentPost() async {
    try {
      final created = await _postService.createRepost(sourcePost: post.value);
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

  void adjustCommentCount(int delta) {
    final currentPost = post.value;
    final nextCount = currentPost.stats.commentCount + delta;

    post.value = currentPost.copyWith(
      stats: currentPost.stats.copyWith(
        commentCount: nextCount < 0 ? 0 : nextCount,
      ),
    );

    _profilePostsController?.adjustCommentCount(postId, delta: delta);
    _feedController?.adjustCommentCount(postId, delta: delta);
  }

  void adjustShareCount(String targetPostId, {int delta = 1}) {
    if (post.value.postId != targetPostId) return;

    final currentPost = post.value;
    final nextCount = currentPost.stats.shareCount + delta;
    post.value = currentPost.copyWith(
      stats: currentPost.stats.copyWith(
        shareCount: nextCount < 0 ? 0 : nextCount,
      ),
    );

    _profilePostsController?.adjustShareCount(targetPostId, delta: delta);
    _feedController?.adjustShareCount(targetPostId, delta: delta);
  }

  void _syncPostFromSources() {
    final latestProfilePost = _profilePostsController?.findPostById(postId);
    if (latestProfilePost != null) {
      post.value = latestProfilePost;
      return;
    }

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
    _profileWorker?.dispose();
    if (Get.isRegistered<PostCommentsController>(tag: commentsTag)) {
      Get.delete<PostCommentsController>(tag: commentsTag, force: true);
    }
    super.onClose();
  }
}
