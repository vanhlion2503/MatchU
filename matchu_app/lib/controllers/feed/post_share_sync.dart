import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/feed/feed_controller.dart';
import 'package:matchu_app/controllers/feed/post_detail_controller.dart';
import 'package:matchu_app/controllers/profile/profile_posts_controller.dart';
import 'package:matchu_app/models/feed/post_model.dart';

class PostShareSync {
  const PostShareSync._();

  static void applyCount({
    required PostModel sourcePost,
    required String targetPostId,
    required int externalShareCount,
  }) {
    final normalizedPostId = targetPostId.trim();
    if (normalizedPostId.isEmpty) return;
    final safeCount = externalShareCount < 0 ? 0 : externalShareCount;

    if (Get.isRegistered<FeedController>()) {
      Get.find<FeedController>().applyExternalShareCount(
        normalizedPostId,
        safeCount,
      );
    }

    final reference = sourcePost.referencePost;
    final targetAuthorId =
        sourcePost.isRepostOnly && reference != null
            ? reference.authorId.trim()
            : sourcePost.authorId.trim();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    final candidateTags = <String>{
      if (targetAuthorId.isNotEmpty) ...<String>{
        ProfilePostsController.ownerProfileTag(targetAuthorId),
        ProfilePostsController.otherProfileTag(
          targetAuthorId,
          includePrivate: false,
        ),
        ProfilePostsController.otherProfileTag(
          targetAuthorId,
          includePrivate: false,
          includeFollowersOnly: true,
        ),
        ProfilePostsController.otherProfileTag(
          targetAuthorId,
          includePrivate: true,
        ),
      },
      if (currentUserId.isNotEmpty)
        ProfilePostsController.ownerSavedTag(currentUserId),
    };

    for (final tag in candidateTags) {
      if (!Get.isRegistered<ProfilePostsController>(tag: tag)) continue;
      Get.find<ProfilePostsController>(
        tag: tag,
      ).applyExternalShareCount(normalizedPostId, safeCount);
    }

    if (Get.isRegistered<PostDetailController>()) {
      Get.find<PostDetailController>().applyExternalShareCount(
        normalizedPostId,
        safeCount,
      );
    }
  }
}
