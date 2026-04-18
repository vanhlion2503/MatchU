import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:matchu_app/models/feed/post_comment_model.dart';
import 'package:matchu_app/services/user/user_service.dart';

class PostCommentPageResult {
  const PostCommentPageResult({
    required this.comments,
    required this.hasMore,
    this.nextCursor,
  });

  final List<PostCommentModel> comments;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? nextCursor;
}

class PostCommentService {
  PostCommentService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    UserService? userService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _userService = userService ?? UserService();

  static const int maxCommentLength = 300;
  static const int defaultTopLevelPageSize = 5;
  static const int _topLevelScanBatchSize = 24;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final UserService _userService;

  CollectionReference<Map<String, dynamic>> get _postsRef =>
      _firestore.collection('posts');

  String get uid => _auth.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> _commentsRef(String postId) =>
      _postsRef.doc(postId).collection('comments');

  Future<PostCommentPageResult> fetchTopLevelCommentsPage(
    String postId, {
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = defaultTopLevelPageSize,
  }) async {
    if (limit <= 0) {
      return const PostCommentPageResult(comments: [], hasMore: false);
    }

    final topLevelDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    QueryDocumentSnapshot<Map<String, dynamic>>? scanCursor;
    var exhausted = false;

    while (topLevelDocs.length < limit + 1 && !exhausted) {
      Query<Map<String, dynamic>> query = _commentsRef(
        postId,
      ).orderBy('createdAt', descending: true).limit(_topLevelScanBatchSize);

      final effectiveCursor = scanCursor ?? startAfter;
      if (effectiveCursor != null) {
        query = query.startAfterDocument(effectiveCursor);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) {
        exhausted = true;
        break;
      }

      for (final doc in snapshot.docs) {
        scanCursor = doc;
        if (!_isTopLevelComment(doc.data()['parentId'])) continue;

        topLevelDocs.add(doc);
        if (topLevelDocs.length >= limit + 1) {
          break;
        }
      }

      if (snapshot.docs.length < _topLevelScanBatchSize) {
        exhausted = true;
      }
    }

    final selectedDocs = topLevelDocs.take(limit).toList(growable: false);
    final hydrated = await _hydrateDocs(postId, selectedDocs);

    return PostCommentPageResult(
      comments: hydrated,
      hasMore: topLevelDocs.length > limit,
      nextCursor: selectedDocs.isNotEmpty ? selectedDocs.last : startAfter,
    );
  }

  Future<List<PostCommentModel>> fetchReplies(
    String postId,
    String parentId,
  ) async {
    final snapshot =
        await _commentsRef(postId).where('parentId', isEqualTo: parentId).get();

    final hydrated = await _hydrateDocs(postId, snapshot.docs);
    hydrated.sort((a, b) {
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aTime.compareTo(bTime);
    });
    return hydrated;
  }

  Future<PostCommentModel> addComment({
    required String postId,
    required String content,
    String? parentId,
  }) async {
    if (uid.isEmpty) {
      throw StateError('Bạn cần đăng nhập để bình luận.');
    }

    final normalizedContent = content.trim();
    if (normalizedContent.isEmpty) {
      throw StateError('Nội dung bình luận không được để trống.');
    }
    if (normalizedContent.length > maxCommentLength) {
      throw StateError('Bình luận không được vượt quá 300 ký tự.');
    }

    final author = PostCommentAuthorModel.fromUser(
      await _userService.getUser(uid),
      uid,
    );

    final postRef = _postsRef.doc(postId);
    final commentRef = postRef.collection('comments').doc();
    final parentRef =
        parentId == null || parentId.trim().isEmpty
            ? null
            : postRef.collection('comments').doc(parentId.trim());

    await _firestore.runTransaction((transaction) async {
      final postSnap = await transaction.get(postRef);
      if (!postSnap.exists) {
        throw StateError('Bài viết không còn tồn tại.');
      }

      if (parentRef != null) {
        final parentSnap = await transaction.get(parentRef);
        if (!parentSnap.exists) {
          throw StateError('Không tìm thấy bình luận gốc để trả lời.');
        }

        final currentReplyCount =
            (parentSnap.data()?['replyCount'] as num?)?.toInt() ?? 0;

        transaction.update(parentRef, {'replyCount': currentReplyCount + 1});
      }

      final rawStats = postSnap.data()?['stats'];
      final stats =
          rawStats is Map
              ? Map<String, dynamic>.from(rawStats)
              : const <String, dynamic>{};
      final currentCommentCount = (stats['commentCount'] as num?)?.toInt() ?? 0;

      transaction.set(commentRef, {
        'commentId': commentRef.id,
        'userId': uid,
        'content': normalizedContent,
        'parentId': parentRef?.id,
        'likeCount': 0,
        'replyCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.update(postRef, {
        'stats.commentCount': currentCommentCount + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    return PostCommentModel(
      commentId: commentRef.id,
      userId: uid,
      content: normalizedContent,
      parentId: parentRef?.id,
      likeCount: 0,
      replyCount: 0,
      createdAt: DateTime.now(),
      author: author,
    );
  }

  Future<Map<String, bool>> getLikeStates(
    String postId,
    List<String> commentIds,
  ) async {
    if (commentIds.isEmpty) {
      return const {};
    }

    if (uid.isEmpty) {
      return {for (final commentId in commentIds) commentId: false};
    }

    final entries = await Future.wait(
      commentIds.map((commentId) async {
        final likeDoc =
            await _commentsRef(
              postId,
            ).doc(commentId).collection('likes').doc(uid).get();
        return MapEntry(commentId, likeDoc.exists);
      }),
    );

    return Map<String, bool>.fromEntries(entries);
  }

  Future<void> likeComment(String postId, String commentId) {
    return _setCommentLike(
      postId: postId,
      commentId: commentId,
      shouldLike: true,
    );
  }

  Future<void> unlikeComment(String postId, String commentId) {
    return _setCommentLike(
      postId: postId,
      commentId: commentId,
      shouldLike: false,
    );
  }

  Future<void> _setCommentLike({
    required String postId,
    required String commentId,
    required bool shouldLike,
  }) async {
    if (uid.isEmpty) {
      throw StateError('Bạn cần đăng nhập để tương tác với bình luận.');
    }

    final commentRef = _commentsRef(postId).doc(commentId);
    final likeRef = commentRef.collection('likes').doc(uid);

    await _firestore.runTransaction((transaction) async {
      final commentSnap = await transaction.get(commentRef);
      if (!commentSnap.exists) {
        throw StateError('Bình luận không còn tồn tại.');
      }

      final likeSnap = await transaction.get(likeRef);
      final currentLikeCount =
          (commentSnap.data()?['likeCount'] as num?)?.toInt() ?? 0;

      if (shouldLike) {
        if (likeSnap.exists) return;

        transaction.set(likeRef, {
          'userId': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.update(commentRef, {'likeCount': currentLikeCount + 1});
        return;
      }

      if (!likeSnap.exists) return;

      transaction.delete(likeRef);
      transaction.update(commentRef, {
        'likeCount': currentLikeCount > 0 ? currentLikeCount - 1 : 0,
      });
    });
  }

  Future<List<PostCommentModel>> _hydrateDocs(
    String postId,
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final comments = docs
        .map(PostCommentModel.fromDoc)
        .where((comment) => comment.content.trim().isNotEmpty)
        .toList(growable: false);

    if (comments.isEmpty) {
      return const <PostCommentModel>[];
    }

    final authorsFuture = _resolveAuthors(comments);
    final likeStatesFuture = getLikeStates(
      postId,
      comments.map((comment) => comment.commentId).toList(growable: false),
    );
    final authors = await authorsFuture;
    final likeStates = await likeStatesFuture;

    return comments
        .map(
          (comment) => comment.copyWith(
            author: authors[comment.userId],
            isLiked: likeStates[comment.commentId] ?? false,
          ),
        )
        .toList(growable: false);
  }

  Future<Map<String, PostCommentAuthorModel>> _resolveAuthors(
    List<PostCommentModel> comments,
  ) async {
    final userIds = comments.map((comment) => comment.userId).toSet().toList();
    final authors = <String, PostCommentAuthorModel>{};

    final users = await Future.wait(userIds.map(_userService.getUser));
    for (var index = 0; index < userIds.length; index++) {
      authors[userIds[index]] = PostCommentAuthorModel.fromUser(
        users[index],
        userIds[index],
      );
    }

    return authors;
  }

  bool _isTopLevelComment(dynamic parentId) {
    if (parentId == null) return true;
    if (parentId is String) return parentId.trim().isEmpty;
    return parentId.toString().trim().isEmpty;
  }
}
