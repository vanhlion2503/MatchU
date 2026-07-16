import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/translations/post_translations.dart';
import 'package:matchu_app/controllers/feed/feed_controller.dart';
import 'package:matchu_app/controllers/feed/post_detail_controller.dart';
import 'package:matchu_app/controllers/profile/profile_posts_controller.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/services/feed/post_service.dart';

class PostCreationSync {
  const PostCreationSync._();

  static final Map<String, StreamSubscription<PostModel?>>
  _moderationSubscriptions = <String, StreamSubscription<PostModel?>>{};

  static void sync(PostModel post) {
    _watchModerationIfNeeded(post);

    if (post.isPublic &&
        post.isModerationApproved &&
        Get.isRegistered<FeedController>()) {
      Get.find<FeedController>().prependPost(post);
    }

    for (final tag in ProfilePostsController.selfProfileTags(post.authorId)) {
      if (!Get.isRegistered<ProfilePostsController>(tag: tag)) {
        continue;
      }

      Get.find<ProfilePostsController>(tag: tag).prependPost(post);
    }

    _syncShareCount(post, delta: 1);
    if (post.postType.isRepostOnly) {
      _syncRepostState(post, isReposted: true);
    }
  }

  static void syncRepostRemoved(PostModel repostPost) {
    if (!repostPost.postType.isRepostOnly) return;
    _removeRepostFromSelfProfiles(repostPost);
    _syncShareCount(repostPost, delta: -1);
    _syncRepostState(repostPost, isReposted: false);
  }

  static void syncPostDeleted(PostModel post) {
    _cancelModerationWatch(post.postId);
    _removePostFromFeedAndProfiles(post);
    if (post.postType.requiresReference) {
      _syncShareCount(post, delta: -1);
    }
    if (post.postType.isRepostOnly) {
      _syncRepostState(post, isReposted: false);
    }
  }

  static void syncPostUpdated(PostModel post) {
    _watchModerationIfNeeded(post);

    if (Get.isRegistered<FeedController>()) {
      Get.find<FeedController>().applyPostUpdate(post);
    }

    final candidateTags = <String>{
      ...ProfilePostsController.selfProfileTags(post.authorId),
      ProfilePostsController.ownerSavedTag(post.authorId),
      ProfilePostsController.otherProfileTag(
        post.authorId,
        includePrivate: false,
      ),
      ProfilePostsController.otherProfileTag(
        post.authorId,
        includePrivate: false,
        includeFollowersOnly: true,
      ),
      ProfilePostsController.otherProfileTag(
        post.authorId,
        includePrivate: true,
      ),
    };

    for (final tag in candidateTags) {
      if (!Get.isRegistered<ProfilePostsController>(tag: tag)) {
        continue;
      }

      Get.find<ProfilePostsController>(tag: tag).applyPostUpdate(post);
    }

    if (Get.isRegistered<PostDetailController>()) {
      Get.find<PostDetailController>().applyPostUpdate(post);
    }
  }

  static void _watchModerationIfNeeded(PostModel post) {
    final postId = post.postId.trim();
    if (postId.isEmpty || !post.isModerationPending) return;
    if (_moderationSubscriptions.containsKey(postId)) return;

    _moderationSubscriptions[postId] = PostService().watchPost(postId).listen((
      updatedPost,
    ) {
      if (updatedPost == null) {
        _cancelModerationWatch(postId);
        return;
      }

      syncPostUpdated(updatedPost);
      if (!updatedPost.moderationStatus.isFinalDecision) return;

      _cancelModerationWatch(postId);
      _notifyModerationDecision(updatedPost);
    });
  }

  static void _cancelModerationWatch(String postId) {
    final normalizedPostId = postId.trim();
    if (normalizedPostId.isEmpty) return;

    final subscription = _moderationSubscriptions.remove(normalizedPostId);
    unawaited(subscription?.cancel());
  }

  static void _notifyModerationDecision(PostModel post) {
    if (post.isModerationApproved) {
      Get.snackbar(
        PostTranslationKeys.notice.tr,
        'Video đã được duyệt và bài viết có thể hiển thị theo quyền riêng tư đã chọn.'
            .tr,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
      return;
    }

    final message = post.moderationMessageVi?.trim();
    Get.snackbar(
      (post.isRejectedByModeration
              ? PostTranslationKeys.moderationRejected
              : PostTranslationKeys.moderationReview)
          .tr,
      message?.isNotEmpty == true
          ? postTr(message!)
          : post.isRejectedByModeration
          ? 'Video vi phạm tiêu chuẩn cộng đồng nên bài viết đã bị ẩn.'.tr
          : 'Video cần được quản trị viên xem xét trước khi hiển thị.'.tr,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
    );
  }

  static void _removePostFromFeedAndProfiles(PostModel post) {
    if (Get.isRegistered<FeedController>()) {
      final feedController = Get.find<FeedController>();
      if (feedController.findPostById(post.postId) != null) {
        feedController.removePostById(post.postId);
      }
    }

    final candidateTags = <String>{
      ...ProfilePostsController.selfProfileTags(post.authorId),
      ProfilePostsController.otherProfileTag(
        post.authorId,
        includePrivate: false,
      ),
      ProfilePostsController.otherProfileTag(
        post.authorId,
        includePrivate: false,
        includeFollowersOnly: true,
      ),
      ProfilePostsController.otherProfileTag(
        post.authorId,
        includePrivate: true,
      ),
    };

    for (final tag in candidateTags) {
      if (!Get.isRegistered<ProfilePostsController>(tag: tag)) {
        continue;
      }
      final profileController = Get.find<ProfilePostsController>(tag: tag);
      if (profileController.findPostById(post.postId) != null) {
        profileController.removePostById(post.postId);
      }
    }
  }

  static void _removeRepostFromSelfProfiles(PostModel repostPost) {
    final candidateTags = <String>{
      ...ProfilePostsController.selfProfileTags(repostPost.authorId),
      ProfilePostsController.otherProfileTag(
        repostPost.authorId,
        includePrivate: false,
      ),
      ProfilePostsController.otherProfileTag(
        repostPost.authorId,
        includePrivate: false,
        includeFollowersOnly: true,
      ),
    };

    for (final tag in candidateTags) {
      if (!Get.isRegistered<ProfilePostsController>(tag: tag)) {
        continue;
      }
      final profileController = Get.find<ProfilePostsController>(tag: tag);
      if (profileController.findPostById(repostPost.postId) != null) {
        profileController.removePostById(repostPost.postId);
      }
    }
  }

  static void _syncShareCount(PostModel post, {required int delta}) {
    final referencePostId = post.referencePostId?.trim() ?? '';
    if (referencePostId.isEmpty) return;

    if (Get.isRegistered<FeedController>()) {
      Get.find<FeedController>().adjustShareCount(
        referencePostId,
        delta: delta,
      );
    }

    final referenceAuthorId = post.referencePost?.authorId.trim() ?? '';
    if (referenceAuthorId.isNotEmpty) {
      final candidateTags = <String>{
        ProfilePostsController.ownerProfileTag(referenceAuthorId),
        ProfilePostsController.otherProfileTag(
          referenceAuthorId,
          includePrivate: false,
        ),
        ProfilePostsController.otherProfileTag(
          referenceAuthorId,
          includePrivate: false,
          includeFollowersOnly: true,
        ),
        ProfilePostsController.otherProfileTag(
          referenceAuthorId,
          includePrivate: true,
        ),
      };

      for (final tag in candidateTags) {
        if (!Get.isRegistered<ProfilePostsController>(tag: tag)) {
          continue;
        }
        Get.find<ProfilePostsController>(
          tag: tag,
        ).adjustShareCount(referencePostId, delta: delta);
      }
    }

    if (Get.isRegistered<PostDetailController>()) {
      Get.find<PostDetailController>().adjustShareCount(
        referencePostId,
        delta: delta,
      );
    }
  }

  static void _syncRepostState(PostModel post, {required bool isReposted}) {
    final referencePostId = post.referencePostId?.trim() ?? '';
    if (referencePostId.isEmpty) return;

    if (Get.isRegistered<FeedController>()) {
      Get.find<FeedController>().applyRepostState(
        referencePostId,
        isReposted: isReposted,
      );
    }

    final referenceAuthorId = post.referencePost?.authorId.trim() ?? '';
    if (referenceAuthorId.isNotEmpty) {
      final candidateTags = <String>{
        ProfilePostsController.ownerProfileTag(referenceAuthorId),
        ProfilePostsController.otherProfileTag(
          referenceAuthorId,
          includePrivate: false,
        ),
        ProfilePostsController.otherProfileTag(
          referenceAuthorId,
          includePrivate: false,
          includeFollowersOnly: true,
        ),
        ProfilePostsController.otherProfileTag(
          referenceAuthorId,
          includePrivate: true,
        ),
      };

      for (final tag in candidateTags) {
        if (!Get.isRegistered<ProfilePostsController>(tag: tag)) {
          continue;
        }
        Get.find<ProfilePostsController>(
          tag: tag,
        ).applyRepostState(referencePostId, isReposted: isReposted);
      }
    }

    if (Get.isRegistered<PostDetailController>()) {
      Get.find<PostDetailController>().applyRepostState(
        referencePostId,
        isReposted: isReposted,
      );
    }
  }
}
