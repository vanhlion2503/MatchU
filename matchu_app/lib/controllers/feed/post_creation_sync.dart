import 'package:get/get.dart';
import 'package:matchu_app/controllers/feed/feed_controller.dart';
import 'package:matchu_app/controllers/feed/post_detail_controller.dart';
import 'package:matchu_app/controllers/profile/profile_posts_controller.dart';
import 'package:matchu_app/models/feed/post_model.dart';

class PostCreationSync {
  const PostCreationSync._();

  static void sync(PostModel post) {
    if (post.isPublic && Get.isRegistered<FeedController>()) {
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

  static void _removeRepostFromSelfProfiles(PostModel repostPost) {
    final candidateTags = <String>{
      ...ProfilePostsController.selfProfileTags(repostPost.authorId),
      ProfilePostsController.otherProfileTag(
        repostPost.authorId,
        includePrivate: false,
      ),
    };

    for (final tag in candidateTags) {
      if (!Get.isRegistered<ProfilePostsController>(tag: tag)) {
        continue;
      }
      Get.find<ProfilePostsController>(
        tag: tag,
      ).removePostById(repostPost.postId);
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
