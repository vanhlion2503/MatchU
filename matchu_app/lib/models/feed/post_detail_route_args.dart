import 'package:matchu_app/models/feed/post_model.dart';

class PostDetailRouteArgs {
  const PostDetailRouteArgs({required this.post, this.focusComposer = false});

  final PostModel post;
  final bool focusComposer;
}
