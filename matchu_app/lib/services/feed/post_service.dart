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

  Future<PostModel> createPost({
    required String content,
    required List<PostMediaDraft> mediaDrafts,
    required List<String> tags,
    bool isPublic = true,
  }) async {
    if (uid.isEmpty) {
      throw StateError('Ban can dang nhap de dang bai viet.');
    }

    final normalizedContent = content.trim();
    if (normalizedContent.isEmpty && mediaDrafts.isEmpty) {
      throw StateError('Bai viet can co noi dung hoac media.');
    }
    if (normalizedContent.length > maxContentLength) {
      throw StateError('Noi dung bai viet khong duoc vuot qua 300 ky tu.');
    }

    final author = await _resolveCurrentAuthor();
    final normalizedTags = _normalizeTags(tags);
    final postRef = _postsRef.doc();
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
      await batch.commit();

      return PostModel(
        postId: postRef.id,
        authorId: uid,
        content: normalizedContent,
        media: uploadedMedia,
        tags: normalizedTags,
        isPublic: isPublic,
        stats: const StatsModel(),
        trendScore: 0,
        trendBucket: 0,
        author: author,
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
      throw StateError('Ban can dang nhap de tuong tac voi bai viet.');
    }

    final postRef = _postsRef.doc(postId);
    final likeRef = postRef.collection('likes').doc(uid);

    await _firestore.runTransaction((transaction) async {
      final postSnap = await transaction.get(postRef);
      if (!postSnap.exists) {
        throw StateError('Bai viet khong con ton tai.');
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
      throw StateError('Khong tim thay thong tin nguoi dung hien tai.');
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
    final displayName =
        user.fullname.trim().isNotEmpty
            ? user.fullname.trim()
            : user.nickname.trim();

    return PostAuthorModel(
      id: user.uid,
      name: displayName.isNotEmpty ? displayName : 'Nguoi dung',
      avatar: user.avatarUrl,
    );
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
