import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:matchu_app/models/feed/media_model.dart';
import 'package:matchu_app/models/feed/post_media_draft.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/models/feed/post_page_result.dart';
import 'package:matchu_app/models/feed/stats_model.dart';
import 'package:matchu_app/models/user_model.dart';
import 'package:matchu_app/services/user/user_service.dart';
import 'package:path_provider/path_provider.dart';

class PostService {
  PostService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
    UserService? userService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _userService = userService ?? UserService();

  static const int defaultPageSize = 10;
  static const int maxContentLength = 300;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;
  final UserService _userService;

  CollectionReference<Map<String, dynamic>> get _postsRef =>
      _firestore.collection('posts');

  String get uid => _auth.currentUser?.uid ?? '';

  Future<PostPageResult> fetchLatestPosts({
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = defaultPageSize,
  }) async {
    final collectedPosts = <PostModel>[];
    DocumentSnapshot<Map<String, dynamic>>? cursor = startAfter;
    var canLoadMore = true;

    while (collectedPosts.length < limit && canLoadMore) {
      Query<Map<String, dynamic>> query = _postsRef
          .where('isPublic', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (cursor != null) {
        query = query.startAfterDocument(cursor);
      }

      final snapshot = await query.get();
      final docs = snapshot.docs;

      if (docs.isEmpty) {
        canLoadMore = false;
        break;
      }

      cursor = docs.last;

      for (final doc in docs) {
        final post = PostModel.fromDoc(doc);
        if (post.deletedAt != null || post.postType.isRepostOnly) {
          continue;
        }
        collectedPosts.add(post);
        if (collectedPosts.length == limit) {
          break;
        }
      }

      if (docs.length < limit) {
        canLoadMore = false;
      }
    }

    return PostPageResult(
      posts: collectedPosts,
      lastDocument: cursor,
      hasMore: canLoadMore,
    );
  }

  Future<PostPageResult> fetchPostsByAuthor({
    required String authorId,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = defaultPageSize,
    bool publicOnly = false,
  }) async {
    if (authorId.trim().isEmpty) {
      return const PostPageResult(
        posts: <PostModel>[],
        lastDocument: null,
        hasMore: false,
      );
    }

    final collectedPosts = <PostModel>[];
    DocumentSnapshot<Map<String, dynamic>>? cursor = startAfter;
    var canLoadMore = true;

    while (collectedPosts.length < limit && canLoadMore) {
      Query<Map<String, dynamic>> query = _postsRef.where(
        'authorId',
        isEqualTo: authorId,
      );

      if (publicOnly) {
        query = query.where('isPublic', isEqualTo: true);
      }

      query = query.orderBy('createdAt', descending: true).limit(limit);

      if (cursor != null) {
        query = query.startAfterDocument(cursor);
      }

      final snapshot = await query.get();
      final docs = snapshot.docs;

      if (docs.isEmpty) {
        canLoadMore = false;
        break;
      }

      cursor = docs.last;

      for (final doc in docs) {
        final post = PostModel.fromDoc(doc);
        if (post.deletedAt != null) {
          continue;
        }
        collectedPosts.add(post);
        if (collectedPosts.length == limit) {
          break;
        }
      }

      if (docs.length < limit) {
        canLoadMore = false;
      }
    }

    return PostPageResult(
      posts: collectedPosts,
      lastDocument: cursor,
      hasMore: canLoadMore,
    );
  }

  Future<PostModel?> fetchPostById(String postId) async {
    final normalizedPostId = postId.trim();
    if (normalizedPostId.isEmpty) return null;

    final doc = await _postsRef.doc(normalizedPostId).get();
    if (!doc.exists) return null;

    final post = PostModel.fromDoc(doc);
    if (post.deletedAt != null) return null;
    return post;
  }

  Future<PostModel> createPost({
    required String content,
    required List<PostMediaDraft> mediaDrafts,
    required List<String> tags,
    bool isPublic = true,
  }) {
    return _createPost(
      postType: PostType.post,
      content: content,
      mediaDrafts: mediaDrafts,
      tags: tags,
      isPublic: isPublic,
    );
  }

  Future<PostModel> createQuotePost({
    required String content,
    required List<PostMediaDraft> mediaDrafts,
    required List<String> tags,
    required PostModel sourcePost,
    bool isPublic = true,
  }) {
    return _createPost(
      postType: PostType.quote,
      content: content,
      mediaDrafts: mediaDrafts,
      tags: tags,
      isPublic: isPublic,
      referencePost: _resolveReferencePost(sourcePost),
    );
  }

  Future<PostModel> createRepost({
    required PostModel sourcePost,
    bool isPublic = true,
  }) async {
    if (uid.isEmpty) {
      throw StateError(
        'Báº¡n cáº§n Ä‘Äƒng nháº­p Ä‘á»ƒ Ä‘Äƒng láº¡i bÃ i viáº¿t.',
      );
    }

    final referencePost = _resolveReferencePost(sourcePost);
    if (referencePost.postId.trim().isEmpty) {
      throw StateError(
        'KhÃ´ng tÃ¬m tháº¥y bÃ i viáº¿t gá»‘c Ä‘á»ƒ Ä‘Äƒng láº¡i.',
      );
    }

    final repostRef = _postsRef.doc(_repostDocId(referencePost.postId));
    final existingSnap = await repostRef.get();
    if (existingSnap.exists) {
      final existing = PostModel.fromDoc(existingSnap);
      if (existing.deletedAt == null) {
        throw StateError('Báº¡n Ä‘Ã£ Ä‘Äƒng láº¡i bÃ i viáº¿t nÃ y rá»“i.');
      }
    }

    return _createPost(
      postType: PostType.repost,
      content: '',
      mediaDrafts: const <PostMediaDraft>[],
      tags: const <String>[],
      isPublic: isPublic,
      referencePost: referencePost,
      explicitPostRef: repostRef,
    );
  }

  String resolveRepostTargetPostId(PostModel sourcePost) {
    final referencePost = _resolveReferencePost(sourcePost);
    return referencePost.postId.trim();
  }

  Future<bool> isPostReposted(PostModel sourcePost) async {
    final targetPostId = resolveRepostTargetPostId(sourcePost);
    if (targetPostId.isEmpty) return false;

    final states = await getRepostStates(<String>[targetPostId]);
    return states[targetPostId] ?? false;
  }

  Future<Map<String, bool>> getRepostStates(List<String> sourcePostIds) async {
    final normalizedIds = sourcePostIds
        .map((postId) => postId.trim())
        .where((postId) => postId.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (normalizedIds.isEmpty) {
      return const {};
    }

    if (uid.isEmpty) {
      return {for (final postId in normalizedIds) postId: false};
    }

    final entries = await Future.wait(
      normalizedIds.map((postId) async {
        final repostSnap = await _postsRef.doc(_repostDocId(postId)).get();
        if (!repostSnap.exists) {
          return MapEntry(postId, false);
        }

        final repostData = repostSnap.data() ?? const <String, dynamic>{};
        final isDeleted = repostData['deletedAt'] != null;
        return MapEntry(postId, !isDeleted);
      }),
    );

    return Map<String, bool>.fromEntries(entries);
  }

  Future<PostModel> undoRepost({required PostModel sourcePost}) async {
    if (uid.isEmpty) {
      throw StateError('Ban can dang nhap de huy dang lai.');
    }

    final referencePost = _resolveReferencePost(sourcePost);
    final referencePostId = referencePost.postId.trim();
    if (referencePostId.isEmpty) {
      throw StateError('Khong tim thay bai viet goc de huy dang lai.');
    }

    final repostRef = _postsRef.doc(_repostDocId(referencePostId));

    return _firestore.runTransaction((transaction) async {
      final repostSnap = await transaction.get(repostRef);
      if (!repostSnap.exists) {
        throw StateError('Ban chua dang lai bai viet nay.');
      }

      final repost = PostModel.fromDoc(repostSnap);
      if (repost.deletedAt != null) {
        throw StateError('Ban chua dang lai bai viet nay.');
      }

      if (repost.authorId != uid) {
        throw StateError('Ban khong the huy dang lai bai viet nay.');
      }

      final resolvedReferencePostId =
          (repost.referencePostId ?? referencePostId).trim();
      if (resolvedReferencePostId.isNotEmpty) {
        final referencePostRef = _postsRef.doc(resolvedReferencePostId);
        final referenceSnap = await transaction.get(referencePostRef);

        if (referenceSnap.exists) {
          final referenceData = referenceSnap.data() ?? <String, dynamic>{};
          final rawStats = referenceData['stats'];
          final statsMap =
              rawStats is Map
                  ? Map<String, dynamic>.from(rawStats)
                  : const <String, dynamic>{};
          final currentShareCount =
              (statsMap['shareCount'] as num?)?.toInt() ?? 0;

          transaction.update(referencePostRef, {
            'stats.shareCount':
                currentShareCount > 0 ? currentShareCount - 1 : 0,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      transaction.update(repostRef, {
        'deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(_firestore.collection('users').doc(uid), {
        'totalPosts': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return repost;
    });
  }

  Future<PostModel> _createPost({
    required PostType postType,
    required String content,
    required List<PostMediaDraft> mediaDrafts,
    required List<String> tags,
    required bool isPublic,
    PostReferenceModel? referencePost,
    DocumentReference<Map<String, dynamic>>? explicitPostRef,
  }) async {
    if (uid.isEmpty) {
      throw StateError('Báº¡n cáº§n Ä‘Äƒng nháº­p Ä‘á»ƒ Ä‘Äƒng bÃ i viáº¿t.');
    }

    final normalizedContent = content.trim();
    if (normalizedContent.length > maxContentLength) {
      throw StateError(
        'Ná»™i dung bÃ i viáº¿t khÃ´ng Ä‘Æ°á»£c vÆ°á»£t quÃ¡ 300 kÃ½ tá»±.',
      );
    }

    final hasBody = normalizedContent.isNotEmpty || mediaDrafts.isNotEmpty;
    if (!postType.requiresReference && !hasBody) {
      throw StateError('BÃ i viáº¿t cáº§n cÃ³ ná»™i dung hoáº·c media.');
    }

    if (postType == PostType.repost && hasBody) {
      throw StateError(
        'ÄÄƒng láº¡i khÃ´ng kÃ¨m ná»™i dung hoáº·c tá»‡p Ä‘Ã­nh kÃ¨m.',
      );
    }

    if (postType.requiresReference && referencePost == null) {
      throw StateError('Dáº¡ng bÃ i nÃ y cáº§n cÃ³ bÃ i viáº¿t gá»‘c.');
    }

    final author = await _resolveCurrentAuthor();
    final normalizedTags =
        postType == PostType.repost ? const <String>[] : _normalizeTags(tags);
    final postRef = explicitPostRef ?? _postsRef.doc();
    final uploadedRefs = <Reference>[];
    final createdAt = DateTime.now();

    try {
      final uploadedMedia = await _uploadMedia(
        postId: postRef.id,
        mediaDrafts: mediaDrafts,
        uploadedRefs: uploadedRefs,
      );

      final payload = {
        'postId': postRef.id,
        'authorId': uid,
        'postType': postType.firestoreValue,
        'content': normalizedContent,
        'media': uploadedMedia
            .map((item) => item.toJson())
            .toList(growable: false),
        'tags': normalizedTags,
        'isPublic': isPublic,
        'stats': const StatsModel().toJson(),
        'trendScore': 0,
        'trendBucket': 0,
        'author': author.toJson(),
        'referencePostId': referencePost?.postId,
        'referencePost': referencePost?.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'deletedAt': null,
      };

      final batch = _firestore.batch();
      batch.set(postRef, payload);
      batch.set(_firestore.collection('users').doc(uid), {
        'totalPosts': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final referencePostId = referencePost?.postId.trim() ?? '';
      if (referencePostId.isNotEmpty) {
        batch.update(_postsRef.doc(referencePostId), {
          'stats.shareCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      return PostModel(
        postId: postRef.id,
        authorId: uid,
        postType: postType,
        content: normalizedContent,
        media: uploadedMedia,
        tags: normalizedTags,
        isPublic: isPublic,
        stats: const StatsModel(),
        trendScore: 0,
        trendBucket: 0,
        author: author,
        referencePostId: referencePost?.postId,
        referencePost: referencePost,
        createdAt: createdAt,
        updatedAt: createdAt,
        deletedAt: null,
        isLiked: false,
        isLikePending: false,
      );
    } catch (_) {
      for (final ref in uploadedRefs) {
        try {
          await ref.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<Map<String, bool>> getLikeStates(List<String> postIds) async {
    if (postIds.isEmpty) {
      return const {};
    }

    if (uid.isEmpty) {
      return {for (final postId in postIds) postId: false};
    }

    final entries = await Future.wait(
      postIds.map((postId) async {
        final likeDoc =
            await _postsRef.doc(postId).collection('likes').doc(uid).get();
        return MapEntry(postId, likeDoc.exists);
      }),
    );

    return Map<String, bool>.fromEntries(entries);
  }

  Future<bool> isPostLiked(String postId) async {
    if (uid.isEmpty) return false;
    final likeDoc =
        await _postsRef.doc(postId).collection('likes').doc(uid).get();
    return likeDoc.exists;
  }

  Future<void> likePost(String postId) {
    return _setLike(postId: postId, shouldLike: true);
  }

  Future<void> unlikePost(String postId) {
    return _setLike(postId: postId, shouldLike: false);
  }

  Future<void> _setLike({
    required String postId,
    required bool shouldLike,
  }) async {
    if (uid.isEmpty) {
      throw StateError(
        'Báº¡n cáº§n Ä‘Äƒng nháº­p Ä‘á»ƒ tÆ°Æ¡ng tÃ¡c vá»›i bÃ i viáº¿t.',
      );
    }

    final postRef = _postsRef.doc(postId);
    final likeRef = postRef.collection('likes').doc(uid);

    await _firestore.runTransaction((transaction) async {
      final postSnap = await transaction.get(postRef);
      if (!postSnap.exists) {
        throw StateError('BÃ i viáº¿t khÃ´ng cÃ²n tá»“n táº¡i.');
      }

      final likeSnap = await transaction.get(likeRef);
      final postData = postSnap.data() ?? <String, dynamic>{};
      final rawStats = postData['stats'];
      final statsMap =
          rawStats is Map
              ? Map<String, dynamic>.from(rawStats)
              : const <String, dynamic>{};
      final currentLikeCount = (statsMap['likeCount'] as num?)?.toInt() ?? 0;

      if (shouldLike) {
        if (likeSnap.exists) return;

        transaction.set(likeRef, {
          'userId': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        transaction.update(postRef, {
          'stats.likeCount': currentLikeCount + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      if (!likeSnap.exists) return;

      transaction.delete(likeRef);
      transaction.update(postRef, {
        'stats.likeCount': currentLikeCount > 0 ? currentLikeCount - 1 : 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<PostAuthorModel> _resolveCurrentAuthor() async {
    final user = await _userService.getUser(uid);
    if (user == null) {
      throw StateError(
        'KhÃ´ng tÃ¬m tháº¥y thÃ´ng tin ngÆ°á»i dÃ¹ng hiá»‡n táº¡i.',
      );
    }

    return _authorFromUser(user);
  }

  Future<List<MediaModel>> _uploadMedia({
    required String postId,
    required List<PostMediaDraft> mediaDrafts,
    required List<Reference> uploadedRefs,
  }) async {
    final uploaded = <MediaModel>[];

    for (var index = 0; index < mediaDrafts.length; index++) {
      final draft = mediaDrafts[index];
      final ref = _storage.ref(_storagePathForDraft(postId, draft, index));
      final uploadFile =
          draft.isImage
              ? await _prepareImageFile(postId, draft.file, index)
              : draft.file;

      await ref.putFile(
        uploadFile,
        SettableMetadata(contentType: _contentTypeForDraft(draft)),
      );

      uploadedRefs.add(ref);
      final url = await ref.getDownloadURL();
      uploaded.add(MediaModel(url: url, type: draft.type));
    }

    return uploaded;
  }

  Future<File> _prepareImageFile(String postId, File source, int index) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/post_${postId}_$index.jpg';
      final Uint8List? bytes = await FlutterImageCompress.compressWithFile(
        source.path,
        quality: 78,
        format: CompressFormat.jpeg,
      );

      if (bytes == null) return source;

      final file = File(targetPath);
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (_) {
      return source;
    }
  }

  String _storagePathForDraft(String postId, PostMediaDraft draft, int index) {
    if (draft.isImage) {
      return 'posts/$uid/$postId/image_$index.jpg';
    }

    final extension = _fileExtension(draft.fileName);
    return 'posts/$uid/$postId/video_$index.$extension';
  }

  String _contentTypeForDraft(PostMediaDraft draft) {
    if (draft.isImage) {
      return 'image/jpeg';
    }

    final extension = _fileExtension(draft.fileName);
    switch (extension) {
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      case 'm4v':
        return 'video/x-m4v';
      default:
        return 'video/mp4';
    }
  }

  PostAuthorModel _authorFromUser(UserModel user) {
    final nickname = user.nickname.trim();
    final displayName =
        user.fullname.trim().isNotEmpty ? user.fullname.trim() : nickname;

    return PostAuthorModel(
      id: user.uid,
      nickname: nickname,
      name: displayName.isNotEmpty ? displayName : 'NgÆ°á»i dÃ¹ng',
      avatar: user.avatarUrl,
      isVerified: user.isFaceVerified,
    );
  }

  PostReferenceModel _resolveReferencePost(PostModel sourcePost) {
    if (sourcePost.isRepostOnly && sourcePost.referencePost != null) {
      return sourcePost.referencePost!;
    }

    return PostReferenceModel.fromPost(sourcePost);
  }

  String _repostDocId(String sourcePostId) {
    final sanitized = sourcePostId.trim().replaceAll('/', '_');
    return 'repost_${uid}_$sanitized';
  }

  List<String> _normalizeTags(List<String> tags) {
    final unique = <String>{};

    for (final tag in tags) {
      final normalized = tag.trim().toLowerCase().replaceAll(
        RegExp(r'\s+'),
        '',
      );
      if (normalized.isEmpty) continue;
      unique.add(normalized);
    }

    return unique.toList(growable: false);
  }

  String _fileExtension(String fileName) {
    final segments = fileName.toLowerCase().split('.');
    if (segments.length < 2) return 'mp4';
    return segments.last;
  }
}
