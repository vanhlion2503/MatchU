import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/models/feed/post_search_result.dart';
import 'package:matchu_app/services/feed/post_service.dart';
import 'package:matchu_app/repositories/profile_privacy/profile_privacy_access_repository.dart';

class PostSearchRepository {
  PostSearchRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
    PostService? postService,
    ProfilePrivacyAccessRepository? privacyAccessRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _postService = postService ?? PostService(),
       _privacyAccessRepository =
           privacyAccessRepository ?? ProfilePrivacyAccessRepository();

  static const int pageSize = 20;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;
  final PostService _postService;
  final ProfilePrivacyAccessRepository _privacyAccessRepository;

  String get currentUserId => _auth.currentUser?.uid.trim() ?? '';

  Future<PostSearchPage> search({
    required String query,
    required int offset,
    int limit = pageSize,
  }) async {
    final callable = _functions.httpsCallable('searchPosts');
    final response = await callable.call<Map<String, dynamic>>({
      'query': query.trim(),
      'offset': offset,
      'limit': limit,
    });
    final data = Map<String, dynamic>.from(response.data);
    final rawItems = (data['items'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    final postIds = rawItems
        .map((item) => item['postId']?.toString().trim() ?? '')
        .where((postId) => postId.isNotEmpty)
        .toList(growable: false);
    final postsById = await _fetchPostsByIds(postIds);

    final items = <PostSearchItem>[];
    for (final item in rawItems) {
      final postId = item['postId']?.toString().trim() ?? '';
      final post = postsById[postId];
      if (post == null) continue;
      items.add(
        PostSearchItem(
          post: post,
          matchType: PostSearchMatchType.fromApi(
            item['matchType']?.toString() ?? '',
          ),
          score: _toDouble(item['score']),
        ),
      );
    }

    return PostSearchPage(
      items: items,
      hasMore: data['hasMore'] == true,
      totalMatched: _toInt(data['totalMatched']),
      // Advance by server items, including a post removed between the callable
      // response and the Firestore hydration request.
      nextOffset: offset + rawItems.length,
    );
  }

  Future<void> setPostLiked(String postId, {required bool isLiked}) {
    return isLiked
        ? _postService.likePost(postId)
        : _postService.unlikePost(postId);
  }

  Future<void> setPostSaved(String postId, {required bool isSaved}) {
    return isSaved
        ? _postService.savePost(postId)
        : _postService.unsavePost(postId);
  }

  Future<Map<String, PostModel>> _fetchPostsByIds(List<String> postIds) async {
    if (postIds.isEmpty) return const <String, PostModel>{};

    final postsById = <String, PostModel>{};
    for (var offset = 0; offset < postIds.length; offset += 30) {
      final end = (offset + 30).clamp(0, postIds.length);
      final ids = postIds.sublist(offset, end);
      final snapshot =
          await _firestore
              .collection('posts')
              .where(FieldPath.documentId, whereIn: ids)
              .get();
      for (final doc in snapshot.docs) {
        final post = PostModel.fromDoc(doc);
        if (post.deletedAt != null ||
            !post.isPublic ||
            !post.isModerationApproved ||
            post.postType.isRepostOnly) {
          continue;
        }
        postsById[post.postId] = post;
      }
    }

    final hydratedIds = postsById.keys.toList(growable: false);
    final states = await Future.wait([
      _postService.getLikeStates(hydratedIds),
      _postService.getSavedStates(hydratedIds),
      _postService.getRepostStates(hydratedIds),
    ]);
    for (final entry in postsById.entries.toList(growable: false)) {
      postsById[entry.key] = entry.value.copyWith(
        isLiked: states[0][entry.key] ?? false,
        isSaved: states[1][entry.key] ?? false,
        isReposted: states[2][entry.key] ?? false,
      );
    }
    final accessiblePosts = await _privacyAccessRepository
        .filterAccessiblePosts(postsById.values);
    final accessibleIds = accessiblePosts.map((post) => post.postId).toSet();
    postsById.removeWhere((postId, _) => !accessibleIds.contains(postId));
    return postsById;
  }

  double _toDouble(dynamic value) => value is num ? value.toDouble() : 0;
  int _toInt(dynamic value) => value is num ? value.toInt() : 0;
}
