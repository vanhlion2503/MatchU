import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:matchu_app/models/feed/post_model.dart';

/// Applies account-level privacy on top of each post's own visibility.
class ProfilePrivacyAccessRepository {
  ProfilePrivacyAccessRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get currentUserId => _auth.currentUser?.uid.trim() ?? '';

  Future<bool> canViewAuthorPosts(String authorId) async {
    final normalizedAuthorId = authorId.trim();
    if (normalizedAuthorId.isEmpty) return false;
    if (normalizedAuthorId == currentUserId) return true;

    final snapshot =
        await _firestore.collection('users').doc(normalizedAuthorId).get();
    if (!snapshot.exists) return false;
    return _canViewUserData(snapshot.data());
  }

  Future<List<PostModel>> filterAccessiblePosts(
    Iterable<PostModel> posts,
  ) async {
    final source = posts.toList(growable: false);
    if (source.isEmpty) return const <PostModel>[];

    final authorIds = source
        .map((post) => post.authorId.trim())
        .where((id) => id.isNotEmpty && id != currentUserId)
        .toSet()
        .toList(growable: false);
    final inaccessibleAuthors = <String>{};

    for (var offset = 0; offset < authorIds.length; offset += 30) {
      final end = (offset + 30).clamp(0, authorIds.length);
      final ids = authorIds.sublist(offset, end);
      final snapshot =
          await _firestore
              .collection('users')
              .where(FieldPath.documentId, whereIn: ids)
              .get();
      final foundIds = <String>{};
      for (final document in snapshot.docs) {
        foundIds.add(document.id);
        if (!_canViewUserData(document.data())) {
          inaccessibleAuthors.add(document.id);
        }
      }
      // A deleted/missing author must not leave orphaned content visible.
      inaccessibleAuthors.addAll(ids.where((id) => !foundIds.contains(id)));
    }

    return source
        .where((post) => !inaccessibleAuthors.contains(post.authorId.trim()))
        .toList(growable: false);
  }

  bool _canViewUserData(Map<String, dynamic>? data) {
    if (data?['isPrivateAccount'] != true) return true;
    final followers = List<String>.from(data?['followers'] ?? const []);
    return currentUserId.isNotEmpty && followers.contains(currentUserId);
  }
}
