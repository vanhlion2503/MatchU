import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:matchu_app/models/feed/hidden_post_author_model.dart';
import 'package:matchu_app/models/feed/post_model.dart';

class PostRestrictionService {
  PostRestrictionService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get uid => _auth.currentUser?.uid.trim() ?? '';

  CollectionReference<Map<String, dynamic>> _hiddenPostAuthorsRef(
    String userId,
  ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('hiddenPostAuthors');
  }

  Future<Set<String>> fetchHiddenPostAuthorIds() async {
    final currentUid = uid;
    if (currentUid.isEmpty) {
      return const <String>{};
    }

    final snapshot = await _hiddenPostAuthorsRef(currentUid).get();
    return snapshot.docs
        .map((doc) => (doc.data()['authorId'] ?? doc.id).toString().trim())
        .where((authorId) => authorId.isNotEmpty)
        .toSet();
  }

  Future<List<HiddenPostAuthorModel>> fetchHiddenPostAuthors() async {
    final currentUid = uid;
    if (currentUid.isEmpty) {
      return const <HiddenPostAuthorModel>[];
    }

    final snapshot =
        await _hiddenPostAuthorsRef(
          currentUid,
        ).orderBy('hiddenAt', descending: true).get();

    return snapshot.docs
        .map(HiddenPostAuthorModel.fromDoc)
        .where((item) => item.authorId.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<void> hidePostAuthorFromPost(PostModel post) async {
    final currentUid = uid;
    if (currentUid.isEmpty) {
      throw StateError(
        'B\u1EA1n c\u1EA7n \u0111\u0103ng nh\u1EADp \u0111\u1EC3 \u1EA9n b\u00E0i vi\u1EBFt.',
      );
    }

    final authorId = post.authorId.trim();
    if (authorId.isEmpty) {
      throw StateError(
        'Kh\u00F4ng t\u00ECm th\u1EA5y t\u00E1c gi\u1EA3 \u0111\u1EC3 \u1EA9n b\u00E0i vi\u1EBFt.',
      );
    }

    if (authorId == currentUid) {
      throw StateError(
        'B\u1EA1n kh\u00F4ng th\u1EC3 \u1EA9n to\u00E0n b\u1ED9 b\u00E0i vi\u1EBFt c\u1EE7a ch\u00EDnh m\u00ECnh.',
      );
    }

    final payload = <String, dynamic>{
      'userId': currentUid,
      'authorId': authorId,
      'displayName': post.author.name.trim(),
      'nickname': post.author.nickname.trim(),
      'avatarUrl': post.author.avatar.trim(),
      'sourcePostId': post.postId.trim(),
      'hiddenAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _hiddenPostAuthorsRef(
      currentUid,
    ).doc(authorId).set(payload, SetOptions(merge: true));
  }

  Future<void> unhidePostAuthor(String authorId) async {
    final currentUid = uid;
    if (currentUid.isEmpty) {
      throw StateError(
        'B\u1EA1n c\u1EA7n \u0111\u0103ng nh\u1EADp \u0111\u1EC3 b\u1ECF \u1EA9n b\u00E0i vi\u1EBFt.',
      );
    }

    final normalizedAuthorId = authorId.trim();
    if (normalizedAuthorId.isEmpty) {
      throw StateError(
        'Kh\u00F4ng t\u00ECm th\u1EA5y ng\u01B0\u1EDDi d\u00F9ng \u0111\u1EC3 b\u1ECF \u1EA9n.',
      );
    }

    await _hiddenPostAuthorsRef(currentUid).doc(normalizedAuthorId).delete();
  }
}
