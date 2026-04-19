import 'package:get/get.dart';
import 'package:matchu_app/controllers/feed/feed_controller.dart';
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
  }
}
