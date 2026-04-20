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

    _syncShareCount(post);
  }

  static void _syncShareCount(PostModel post) {
    final referencePostId = post.referencePostId?.trim() ?? '';
    if (referencePostId.isEmpty) return;

    if (Get.isRegistered<FeedController>()) {
      Get.find<FeedController>().adjustShareCount(referencePostId);
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
        ).adjustShareCount(referencePostId);
      }
    }

    if (Get.isRegistered<PostDetailController>()) {
      Get.find<PostDetailController>().adjustShareCount(referencePostId);
    }
  }
}
