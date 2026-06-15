import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:matchu_app/models/feed/blocked_user_model.dart';
import 'package:matchu_app/models/feed/hidden_post_author_model.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/models/user_model.dart';

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

  CollectionReference<Map<String, dynamic>> _blockedUsersRef(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('blockedUsers');
  }

  Future<Set<String>> fetchBlockedUserIds() async {
    final currentUid = uid;
    if (currentUid.isEmpty) {
      return const <String>{};
    }

    final snapshot = await _blockedUsersRef(currentUid).get();
    return snapshot.docs
        .map((doc) => (doc.data()['blockedUserId'] ?? doc.id).toString().trim())
        .where((blockedUserId) => blockedUserId.isNotEmpty)
        .toSet();
  }

  Future<List<BlockedUserModel>> fetchBlockedUsers() async {
    final currentUid = uid;
    if (currentUid.isEmpty) {
      return const <BlockedUserModel>[];
    }

    final snapshot = await _blockedUsersRef(currentUid).get();
    final items =
        snapshot.docs
            .map(BlockedUserModel.fromDoc)
            .where((item) => item.blockedUserId.trim().isNotEmpty)
            .toList();

    items.sort((a, b) {
      final aBlockedAt = a.blockedAt;
      final bBlockedAt = b.blockedAt;
      if (aBlockedAt == null && bBlockedAt == null) return 0;
      if (aBlockedAt == null) return 1;
      if (bBlockedAt == null) return -1;
      return bBlockedAt.compareTo(aBlockedAt);
    });

    return List<BlockedUserModel>.unmodifiable(items);
  }

  Future<bool> isUserBlocked(String blockedUserId) async {
    final currentUid = uid;
    final normalizedBlockedUserId = blockedUserId.trim();
    if (currentUid.isEmpty || normalizedBlockedUserId.isEmpty) {
      return false;
    }

    final doc =
        await _blockedUsersRef(currentUid).doc(normalizedBlockedUserId).get();
    return doc.exists;
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

  Future<void> blockUser(UserModel targetUser) async {
    final currentUid = uid;
    if (currentUid.isEmpty) {
      throw StateError(
        'B\u1EA1n c\u1EA7n \u0111\u0103ng nh\u1EADp \u0111\u1EC3 ch\u1EB7n ng\u01B0\u1EDDi d\u00F9ng.',
      );
    }

    final blockedUserId = targetUser.uid.trim();
    if (blockedUserId.isEmpty) {
      throw StateError(
        'Kh\u00F4ng t\u00ECm th\u1EA5y ng\u01B0\u1EDDi d\u00F9ng \u0111\u1EC3 ch\u1EB7n.',
      );
    }

    if (blockedUserId == currentUid) {
      throw StateError(
        'B\u1EA1n kh\u00F4ng th\u1EC3 ch\u1EB7n ch\u00EDnh m\u00ECnh.',
      );
    }

    final blockRef = _blockedUsersRef(currentUid).doc(blockedUserId);

    final payload = <String, dynamic>{
      'userId': currentUid,
      'blockedUserId': blockedUserId,
      'displayName': targetUser.fullname.trim(),
      'nickname': targetUser.nickname.trim(),
      'avatarUrl': targetUser.avatarUrl.trim(),
      'blockedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await blockRef.set(payload);
  }

  Future<void> unblockUser(String blockedUserId) async {
    final currentUid = uid;
    if (currentUid.isEmpty) {
      throw StateError(
        'B\u1EA1n c\u1EA7n \u0111\u0103ng nh\u1EADp \u0111\u1EC3 g\u1EE1 ch\u1EB7n.',
      );
    }

    final normalizedBlockedUserId = blockedUserId.trim();
    if (normalizedBlockedUserId.isEmpty) {
      throw StateError(
        'Kh\u00F4ng t\u00ECm th\u1EA5y ng\u01B0\u1EDDi d\u00F9ng \u0111\u1EC3 g\u1EE1 ch\u1EB7n.',
      );
    }

    await _blockedUsersRef(currentUid).doc(normalizedBlockedUserId).delete();
  }
}
