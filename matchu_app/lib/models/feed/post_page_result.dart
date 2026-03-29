import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:matchu_app/models/feed/post_model.dart';

class PostPageResult {
  const PostPageResult({
    required this.posts,
    required this.lastDocument,
    required this.hasMore,
  });

  final List<PostModel> posts;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;
}
