import 'package:matchu_app/models/feed/post_model.dart';

class PostDetailRouteArgs {
  const PostDetailRouteArgs({
    required this.post,
    this.profilePostsControllerTag,
  });

  final PostModel post;
  final String? profilePostsControllerTag;
}
