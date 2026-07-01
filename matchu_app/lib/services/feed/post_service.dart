import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:matchu_app/models/feed/media_model.dart';
import 'package:matchu_app/models/feed/post_media_draft.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/models/feed/post_page_result.dart';
import 'package:matchu_app/models/feed/stats_model.dart';
import 'package:matchu_app/models/user_model.dart';
import 'package:matchu_app/services/feed/post_text_moderation_service.dart';
import 'package:matchu_app/services/moderation/image_moderation_service.dart';
import 'package:matchu_app/services/user/user_service.dart';
import 'package:path_provider/path_provider.dart';

class PostService {
  PostService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
    UserService? userService,
    PostTextModerationService? textModerationService,
    ImageModerationService? imageModerationService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _userService = userService ?? UserService(),
       _textModerationService =
           textModerationService ?? PostTextModerationService(),
       _imageModerationService =
           imageModerationService ?? ImageModerationService();

  static const int defaultPageSize = 10;
  static const int maxContentLength = 300;
  static const int maxMediaItems = 6;
  static const int minReputationToCreatePost = 60;
  static const int _whereInLimit = 30;
  static const String _authorPublicScope = 'public';
  static const String _authorFollowersScope = 'followers';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;
  final UserService _userService;
  final PostTextModerationService _textModerationService;
  final ImageModerationService _imageModerationService;

  CollectionReference<Map<String, dynamic>> get _postsRef =>
      _firestore.collection('posts');

  String get uid => _auth.currentUser?.uid ?? '';

  Future<List<String>> fetchFollowingUserIds() async {
    final normalizedCurrentUserId = uid.trim();
    if (normalizedCurrentUserId.isEmpty) {
      return const <String>[];
    }

    final user = await _userService.getUser(normalizedCurrentUserId);
    if (user == null) {
      return const <String>[];
    }

    return user.following
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty && id != normalizedCurrentUserId)
        .toSet()
        .toList(growable: false);
  }

  CollectionReference<Map<String, dynamic>> _savedPostsRef(String userId) {
    return _firestore.collection('users').doc(userId).collection('savedPosts');
  }

  Future<String?> _resolveAuthenticatedUid({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final normalizedUid = user.uid.trim();
    if (normalizedUid.isEmpty) return null;

    try {
      await user.getIdToken(forceRefresh);
    } catch (_) {
      return null;
    }

    final latestUid = _auth.currentUser?.uid.trim() ?? '';
    if (latestUid.isEmpty || latestUid != normalizedUid) {
      return null;
    }

    return latestUid;
  }

  Future<T> _runSavedReadsWithAuthRetry<T>({
    required Future<T> Function(String authenticatedUid) action,
    required T fallbackValue,
  }) async {
    final firstUid = await _resolveAuthenticatedUid();
    if (firstUid == null) return fallbackValue;

    try {
      return await action(firstUid);
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') rethrow;
    }

    final refreshedUid = await _resolveAuthenticatedUid(forceRefresh: true);
    if (refreshedUid == null) return fallbackValue;

    try {
      return await action(refreshedUid);
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        return fallbackValue;
      }
      rethrow;
    }
  }

  Future<PostPageResult> fetchLatestPosts({
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = defaultPageSize,
  }) async {
    final collectedPosts = <PostModel>[];
    DocumentSnapshot<Map<String, dynamic>>? cursor = startAfter;
    var canLoadMore = true;

    while (collectedPosts.length < limit && canLoadMore) {
      Query<Map<String, dynamic>> query = _postsRef
          .where('visibility', isEqualTo: PostVisibility.public.firestoreValue)
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

  Future<
    ({
      List<PostModel> posts,
      Map<String, DocumentSnapshot<Map<String, dynamic>>> lastDocumentsByAuthor,
      Set<String> exhaustedAuthorIds,
    })
  >
  fetchFollowersOnlyPostsByAuthors({
    required Iterable<String> authorIds,
    required Map<String, DocumentSnapshot<Map<String, dynamic>>>
    startAfterByAuthor,
    required Set<String> exhaustedAuthorIds,
    int limitPerAuthor = 2,
  }) async {
    final normalizedAuthorIds = authorIds
        .map((authorId) => authorId.trim())
        .where((authorId) => authorId.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (normalizedAuthorIds.isEmpty || limitPerAuthor <= 0) {
      return (
        posts: const <PostModel>[],
        lastDocumentsByAuthor:
            const <String, DocumentSnapshot<Map<String, dynamic>>>{},
        exhaustedAuthorIds: const <String>{},
      );
    }

    final collectedPosts = <PostModel>[];
    final nextCursors = <String, DocumentSnapshot<Map<String, dynamic>>>{};
    final newlyExhaustedAuthorIds = <String>{};

    for (final authorId in normalizedAuthorIds) {
      if (exhaustedAuthorIds.contains(authorId)) continue;

      var query = _postsRef
          .where('authorId', isEqualTo: authorId)
          .where(
            'visibility',
            isEqualTo: PostVisibility.followers.firestoreValue,
          )
          .orderBy('createdAt', descending: true)
          .limit(limitPerAuthor);

      final cursor = startAfterByAuthor[authorId];
      if (cursor != null) {
        query = query.startAfterDocument(cursor);
      }

      try {
        final snapshot = await query.get();
        final docs = snapshot.docs;
        if (docs.isEmpty) {
          newlyExhaustedAuthorIds.add(authorId);
          continue;
        }

        nextCursors[authorId] = docs.last;
        if (docs.length < limitPerAuthor) {
          newlyExhaustedAuthorIds.add(authorId);
        }

        for (final doc in docs) {
          final post = PostModel.fromDoc(doc);
          if (post.deletedAt != null || post.postType.isRepostOnly) {
            continue;
          }
          collectedPosts.add(post);
        }
      } on FirebaseException catch (error) {
        if (error.code == 'permission-denied') {
          newlyExhaustedAuthorIds.add(authorId);
          continue;
        }
        rethrow;
      }
    }

    collectedPosts.sort((a, b) {
      final aCreatedAt = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bCreatedAt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bCreatedAt.compareTo(aCreatedAt);
    });

    return (
      posts: collectedPosts,
      lastDocumentsByAuthor: nextCursors,
      exhaustedAuthorIds: newlyExhaustedAuthorIds,
    );
  }

  Future<PostPageResult> fetchPostsByAuthor({
    required String authorId,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    Map<String, DocumentSnapshot<Map<String, dynamic>>>? startAfterByScope,
    int limit = defaultPageSize,
    bool publicOnly = false,
    bool includeFollowersOnly = false,
  }) async {
    if (authorId.trim().isEmpty) {
      return const PostPageResult(
        posts: <PostModel>[],
        lastDocument: null,
        hasMore: false,
      );
    }

    if (publicOnly && includeFollowersOnly) {
      return _fetchPublicAndFollowersPostsByAuthor(
        authorId: authorId,
        startAfterByScope: startAfterByScope ?? const {},
        limit: limit,
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
        query = query.where(
          'visibility',
          isEqualTo: PostVisibility.public.firestoreValue,
        );
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

  Future<PostPageResult> _fetchPublicAndFollowersPostsByAuthor({
    required String authorId,
    required Map<String, DocumentSnapshot<Map<String, dynamic>>>
    startAfterByScope,
    required int limit,
  }) async {
    final publicQuery = _postsRef
        .where('authorId', isEqualTo: authorId)
        .where('visibility', isEqualTo: PostVisibility.public.firestoreValue)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    final followersQuery = _postsRef
        .where('authorId', isEqualTo: authorId)
        .where('visibility', isEqualTo: PostVisibility.followers.firestoreValue)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    final publicSnapshot =
        await _queryWithOptionalCursor(
          publicQuery,
          startAfterByScope[_authorPublicScope],
        ).get();
    final followersSnapshot =
        await _queryWithOptionalCursor(
          followersQuery,
          startAfterByScope[_authorFollowersScope],
        ).get();

    final lastDocumentsByScope =
        <String, DocumentSnapshot<Map<String, dynamic>>>{};
    if (publicSnapshot.docs.isNotEmpty) {
      lastDocumentsByScope[_authorPublicScope] = publicSnapshot.docs.last;
    }
    if (followersSnapshot.docs.isNotEmpty) {
      lastDocumentsByScope[_authorFollowersScope] = followersSnapshot.docs.last;
    }

    final mergedPosts = <String, PostModel>{};
    for (final doc in [...publicSnapshot.docs, ...followersSnapshot.docs]) {
      final post = PostModel.fromDoc(doc);
      if (post.deletedAt != null) continue;
      mergedPosts[post.postId] = post;
    }

    final sortedPosts = mergedPosts.values.toList(growable: false);
    sortedPosts.sort((a, b) {
      final aCreatedAt = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bCreatedAt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bCreatedAt.compareTo(aCreatedAt);
    });

    return PostPageResult(
      posts: sortedPosts,
      lastDocument: null,
      hasMore:
          publicSnapshot.docs.length == limit ||
          followersSnapshot.docs.length == limit,
      lastDocumentsByScope: lastDocumentsByScope,
    );
  }

  Query<Map<String, dynamic>> _queryWithOptionalCursor(
    Query<Map<String, dynamic>> query,
    DocumentSnapshot<Map<String, dynamic>>? cursor,
  ) {
    if (cursor == null) return query;
    return query.startAfterDocument(cursor);
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

  Future<PostPageResult> fetchSavedPosts({
    required String userId,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = defaultPageSize,
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return const PostPageResult(
        posts: <PostModel>[],
        lastDocument: null,
        hasMore: false,
      );
    }

    return _runSavedReadsWithAuthRetry(
      action: (authenticatedUid) async {
        if (authenticatedUid != normalizedUserId) {
          throw StateError('Bạn không có quyền xem danh sách lưu trữ này.');
        }

        final collectedPosts = <PostModel>[];
        final savedAtByPostId = <String, DateTime?>{};
        DocumentSnapshot<Map<String, dynamic>>? cursor = startAfter;
        var canLoadMore = true;

        while (collectedPosts.length < limit && canLoadMore) {
          final remaining = limit - collectedPosts.length;
          var query = _savedPostsRef(
            authenticatedUid,
          ).orderBy('savedAt', descending: true);
          query = query.limit(remaining * 2);

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
            final savedData = doc.data();
            final postId = (savedData['postId'] ?? doc.id).toString().trim();
            if (postId.isEmpty) continue;

            try {
              final postSnap = await _postsRef.doc(postId).get();
              if (!postSnap.exists) continue;

              final post = PostModel.fromDoc(postSnap);
              if (post.deletedAt != null) continue;

              final isDuplicated = collectedPosts.any(
                (item) => item.postId == post.postId,
              );
              if (isDuplicated) continue;

              collectedPosts.add(post);
              savedAtByPostId[post.postId] = _asDateTime(savedData['savedAt']);

              if (collectedPosts.length == limit) {
                break;
              }
            } on FirebaseException catch (error) {
              if (error.code == 'permission-denied') {
                continue;
              }
              rethrow;
            }
          }

          if (docs.length < remaining * 2) {
            canLoadMore = false;
          }
        }

        return PostPageResult(
          posts: collectedPosts,
          lastDocument: cursor,
          hasMore: canLoadMore,
          savedAtByPostId: savedAtByPostId,
        );
      },
      fallbackValue: const PostPageResult(
        posts: <PostModel>[],
        lastDocument: null,
        hasMore: false,
      ),
    );
  }

  Future<PostModel> createPost({
    required String content,
    required List<PostMediaDraft> mediaDrafts,
    required List<String> tags,
    PostVisibility? visibility,
    bool? isPublic,
  }) {
    return _createPost(
      postType: PostType.post,
      content: content,
      mediaDrafts: mediaDrafts,
      tags: tags,
      visibility: _resolveVisibility(
        visibility: visibility,
        isPublic: isPublic,
      ),
    );
  }

  Future<PostModel> createQuotePost({
    required String content,
    required List<PostMediaDraft> mediaDrafts,
    required List<String> tags,
    required PostModel sourcePost,
    PostVisibility? visibility,
    bool? isPublic,
  }) {
    final resolvedVisibility = _resolveVisibility(
      visibility: visibility,
      isPublic: isPublic,
    );
    _ensureReferencePostCanBeShared(
      sourcePost: sourcePost,
      requestedVisibility: resolvedVisibility,
    );

    return _createPost(
      postType: PostType.quote,
      content: content,
      mediaDrafts: mediaDrafts,
      tags: tags,
      visibility: resolvedVisibility,
      referencePost: _resolveReferencePost(sourcePost),
    );
  }

  Future<PostModel> updatePost({
    required PostModel post,
    required String content,
    required List<MediaModel> retainedMedia,
    required List<PostMediaDraft> newMediaDrafts,
    required List<String> tags,
    required PostVisibility visibility,
  }) async {
    if (uid.isEmpty) {
      throw StateError('Bạn cần đăng nhập để chỉnh sửa bài viết.');
    }

    final normalizedPostId = post.postId.trim();
    if (normalizedPostId.isEmpty) {
      throw StateError('Không tìm thấy bài viết để chỉnh sửa.');
    }

    final normalizedContent = content.trim();
    if (normalizedContent.length > maxContentLength) {
      throw StateError('Nội dung bài viết không được vượt quá 300 ký tự.');
    }

    final postRef = _postsRef.doc(normalizedPostId);
    final postSnap = await postRef.get();
    if (!postSnap.exists) {
      throw StateError('Bài viết không còn tồn tại.');
    }

    final existingPost = PostModel.fromDoc(postSnap);
    _ensurePostCanBeMutated(existingPost, actionLabel: 'chỉnh sửa');
    if (existingPost.postType.isRepostOnly) {
      throw StateError('Bài đăng lại chỉ có thể chỉnh sửa quyền riêng tư.');
    }
    _ensureExistingReferenceCanUseVisibility(
      existingPost: existingPost,
      requestedVisibility: visibility,
    );

    final normalizedRetainedMedia = _resolveRetainedMedia(
      retainedMedia: retainedMedia,
      existingMedia: existingPost.media,
    );
    final nextMediaCount =
        normalizedRetainedMedia.length + newMediaDrafts.length;
    if (nextMediaCount > maxMediaItems) {
      throw StateError(
        'Mỗi bài viết chỉ có thể có tối đa $maxMediaItems tệp đính kèm.',
      );
    }

    final hasBody = normalizedContent.isNotEmpty || nextMediaCount > 0;
    if (!existingPost.postType.requiresReference && !hasBody) {
      throw StateError('Bài viết cần có nội dung hoặc media.');
    }

    await _ensureTextContentAllowed(normalizedContent);

    final uploadedRefs = <Reference>[];

    try {
      final uploadedMedia = await _uploadMedia(
        postId: normalizedPostId,
        mediaDrafts: newMediaDrafts,
        uploadedRefs: uploadedRefs,
        startIndex: existingPost.media.length,
      );
      final nextMedia = <MediaModel>[
        ...normalizedRetainedMedia,
        ...uploadedMedia,
      ];
      final normalizedTags = _normalizeTags(tags);

      await _firestore.runTransaction((transaction) async {
        final latestSnap = await transaction.get(postRef);
        if (!latestSnap.exists) {
          throw StateError('Bài viết không còn tồn tại.');
        }

        final latestPost = PostModel.fromDoc(latestSnap);
        _ensurePostCanBeMutated(latestPost, actionLabel: 'chỉnh sửa');
        if (latestPost.postType.isRepostOnly) {
          throw StateError('Bài đăng lại chỉ có thể chỉnh sửa quyền riêng tư.');
        }
        _ensureExistingReferenceCanUseVisibility(
          existingPost: latestPost,
          requestedVisibility: visibility,
        );

        transaction.update(postRef, {
          'content': normalizedContent,
          'media': nextMedia
              .map((item) => item.toJson())
              .toList(growable: false),
          'tags': normalizedTags,
          'visibility': visibility.firestoreValue,
          'isPublic': visibility.isPublic,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      await _deleteRemovedMediaFiles(
        _removedMediaFiles(
          previousMedia: existingPost.media,
          retainedMedia: normalizedRetainedMedia,
        ),
      );

      return existingPost.copyWith(
        content: normalizedContent,
        media: nextMedia,
        tags: normalizedTags,
        visibility: visibility,
        updatedAt: DateTime.now(),
      );
    } catch (_) {
      await _deleteUploadedRefs(uploadedRefs);
      rethrow;
    }
  }

  Future<PostModel> updatePostVisibility({
    required PostModel post,
    required PostVisibility visibility,
  }) async {
    if (uid.isEmpty) {
      throw StateError('Bạn cần đăng nhập để chỉnh sửa quyền riêng tư.');
    }

    final normalizedPostId = post.postId.trim();
    if (normalizedPostId.isEmpty) {
      throw StateError('Không tìm thấy bài viết để chỉnh sửa quyền riêng tư.');
    }

    final postRef = _postsRef.doc(normalizedPostId);

    return _firestore.runTransaction((transaction) async {
      final postSnap = await transaction.get(postRef);
      if (!postSnap.exists) {
        throw StateError('Bài viết không còn tồn tại.');
      }

      final existingPost = PostModel.fromDoc(postSnap);
      _ensurePostCanBeMutated(existingPost, actionLabel: 'chỉnh sửa');
      _ensureExistingReferenceCanUseVisibility(
        existingPost: existingPost,
        requestedVisibility: visibility,
      );

      transaction.update(postRef, {
        'visibility': visibility.firestoreValue,
        'isPublic': visibility.isPublic,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return existingPost.copyWith(
        visibility: visibility,
        updatedAt: DateTime.now(),
      );
    });
  }

  Future<PostModel> createRepost({
    required PostModel sourcePost,
    PostVisibility? visibility,
    bool? isPublic,
  }) async {
    if (uid.isEmpty) {
      throw StateError('Bạn cần đăng nhập để đăng lại bài viết.');
    }

    final referencePost = _resolveReferencePost(sourcePost);
    if (referencePost.postId.trim().isEmpty) {
      throw StateError('Không tìm thấy bài viết gốc để đăng lại.');
    }

    final repostRef = _postsRef.doc(_repostDocId(referencePost.postId));
    final existingSnap = await repostRef.get();
    if (existingSnap.exists) {
      final existing = PostModel.fromDoc(existingSnap);
      if (existing.deletedAt == null) {
        throw StateError('Bạn đã đăng lại bài viết này rồi.');
      }
    }

    final resolvedVisibility =
        visibility ??
        (isPublic == null
            ? sourcePost.visibility
            : PostVisibility.fromLegacyIsPublic(isPublic));
    _ensureReferencePostCanBeShared(
      sourcePost: sourcePost,
      requestedVisibility: resolvedVisibility,
    );

    return _createPost(
      postType: PostType.repost,
      content: '',
      mediaDrafts: const <PostMediaDraft>[],
      tags: const <String>[],
      visibility: resolvedVisibility,
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
      throw StateError('Bạn cần đăng nhập để hủy đăng lại.');
    }

    final referencePost = _resolveReferencePost(sourcePost);
    final referencePostId = referencePost.postId.trim();
    if (referencePostId.isEmpty) {
      throw StateError('Không tìm thấy bài viết gốc để hủy đăng lại.');
    }

    final repostRef = _postsRef.doc(_repostDocId(referencePostId));

    return _firestore.runTransaction((transaction) async {
      final repostSnap = await transaction.get(repostRef);
      if (!repostSnap.exists) {
        throw StateError('Bạn chưa đăng lại bài viết này.');
      }

      final repost = PostModel.fromDoc(repostSnap);
      if (repost.deletedAt != null) {
        throw StateError('Bạn chưa đăng lại bài viết này.');
      }

      if (repost.authorId != uid) {
        throw StateError('Bạn không thể hủy đăng lại bài viết này.');
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

  Future<PostModel> deletePost({required PostModel post}) async {
    if (uid.isEmpty) {
      throw StateError('Bạn cần đăng nhập để xóa bài viết.');
    }

    final normalizedPostId = post.postId.trim();
    if (normalizedPostId.isEmpty) {
      throw StateError('Không tìm thấy bài viết để xóa.');
    }

    final postRef = _postsRef.doc(normalizedPostId);

    return _firestore.runTransaction((transaction) async {
      final postSnap = await transaction.get(postRef);
      if (!postSnap.exists) {
        throw StateError('Bài viết không còn tồn tại.');
      }

      final existingPost = PostModel.fromDoc(postSnap);
      if (existingPost.deletedAt != null) {
        throw StateError('Bài viết đã được xóa trước đó.');
      }

      if (existingPost.authorId != uid) {
        throw StateError('Bạn không thể xóa bài viết này.');
      }

      final referencePostId = existingPost.referencePostId?.trim() ?? '';
      if (referencePostId.isNotEmpty) {
        final referencePostRef = _postsRef.doc(referencePostId);
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

      transaction.update(postRef, {
        'deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(_firestore.collection('users').doc(uid), {
        'totalPosts': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return existingPost;
    });
  }

  Future<PostModel> _createPost({
    required PostType postType,
    required String content,
    required List<PostMediaDraft> mediaDrafts,
    required List<String> tags,
    required PostVisibility visibility,
    PostReferenceModel? referencePost,
    DocumentReference<Map<String, dynamic>>? explicitPostRef,
  }) async {
    if (uid.isEmpty) {
      throw StateError('Bạn cần đăng nhập để đăng bài viết.');
    }

    final normalizedContent = content.trim();
    if (normalizedContent.length > maxContentLength) {
      throw StateError('Nội dung bài viết không được vượt quá 300 ký tự.');
    }

    final hasBody = normalizedContent.isNotEmpty || mediaDrafts.isNotEmpty;
    if (!postType.requiresReference && !hasBody) {
      throw StateError('Bài viết cần có nội dung hoặc media.');
    }

    if (postType == PostType.repost && hasBody) {
      throw StateError('Đăng lại không kèm nội dung hoặc tệp đính kèm.');
    }

    if (postType.requiresReference && referencePost == null) {
      throw StateError('Dạng bài này cần có bài viết gốc.');
    }

    await _ensureCanCreatePostByReputation();
    await _ensureTextContentAllowed(normalizedContent);

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
        'visibility': visibility.firestoreValue,
        'isPublic': visibility.isPublic,
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
        visibility: visibility,
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

  Future<Map<String, bool>> getSavedStates(List<String> postIds) async {
    final normalizedIds = postIds
        .map((postId) => postId.trim())
        .where((postId) => postId.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (normalizedIds.isEmpty) {
      return const {};
    }

    final defaultStates = {for (final postId in normalizedIds) postId: false};

    return _runSavedReadsWithAuthRetry(
      action: (authenticatedUid) async {
        final resolvedStates = Map<String, bool>.from(defaultStates);

        for (
          var index = 0;
          index < normalizedIds.length;
          index += _whereInLimit
        ) {
          final end =
              index + _whereInLimit < normalizedIds.length
                  ? index + _whereInLimit
                  : normalizedIds.length;
          final chunk = normalizedIds.sublist(index, end);

          final snapshot =
              await _savedPostsRef(
                authenticatedUid,
              ).where(FieldPath.documentId, whereIn: chunk).get();

          for (final doc in snapshot.docs) {
            resolvedStates[doc.id] = true;
          }
        }

        return resolvedStates;
      },
      fallbackValue: defaultStates,
    );
  }

  Future<bool> isPostSaved(String postId) async {
    final normalizedPostId = postId.trim();
    if (normalizedPostId.isEmpty) return false;

    return _runSavedReadsWithAuthRetry(
      action: (authenticatedUid) async {
        final savedDoc =
            await _savedPostsRef(authenticatedUid).doc(normalizedPostId).get();
        return savedDoc.exists;
      },
      fallbackValue: false,
    );
  }

  Future<void> savePost(String postId) {
    return _setSaved(postId: postId, shouldSave: true);
  }

  Future<void> unsavePost(String postId) {
    return _setSaved(postId: postId, shouldSave: false);
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
      throw StateError('Bạn cần đăng nhập để tương tác với bài viết.');
    }

    final postRef = _postsRef.doc(postId);
    final likeRef = postRef.collection('likes').doc(uid);

    await _firestore.runTransaction((transaction) async {
      final postSnap = await transaction.get(postRef);
      if (!postSnap.exists) {
        throw StateError('Bài viết không còn tồn tại.');
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

  Future<void> _setSaved({
    required String postId,
    required bool shouldSave,
  }) async {
    if (uid.isEmpty) {
      throw StateError('Bạn cần đăng nhập để lưu bài viết.');
    }

    final normalizedPostId = postId.trim();
    if (normalizedPostId.isEmpty) {
      throw StateError('Không tìm thấy bài viết để lưu.');
    }

    final postRef = _postsRef.doc(normalizedPostId);
    final savedRef = _savedPostsRef(uid).doc(normalizedPostId);

    await _firestore.runTransaction((transaction) async {
      final postSnap = await transaction.get(postRef);
      if (!postSnap.exists) {
        throw StateError('Bài viết không còn tồn tại.');
      }

      final postData = postSnap.data() ?? const <String, dynamic>{};
      final isDeleted = postData['deletedAt'] != null;
      if (isDeleted) {
        throw StateError('Bài viết này không còn khả dụng.');
      }

      final visibility = PostVisibility.fromFirestoreValue(
        postData['visibility'],
        legacyIsPublic: postData['isPublic'],
      );
      final authorId = (postData['authorId'] ?? '').toString().trim();
      if (visibility.isPrivate && authorId != uid) {
        throw StateError('Bạn không thể lưu bài viết riêng tư này.');
      }

      final savedSnap = await transaction.get(savedRef);

      if (shouldSave) {
        if (savedSnap.exists) return;

        transaction.set(savedRef, {
          'postId': normalizedPostId,
          'userId': uid,
          'savedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      if (!savedSnap.exists) return;
      transaction.delete(savedRef);
    });
  }

  Future<PostAuthorModel> _resolveCurrentAuthor() async {
    final user = await _userService.getUser(uid);
    if (user == null) {
      throw StateError('Không tìm thấy thông tin người dùng hiện tại.');
    }

    return _authorFromUser(user);
  }

  Future<List<MediaModel>> _uploadMedia({
    required String postId,
    required List<PostMediaDraft> mediaDrafts,
    required List<Reference> uploadedRefs,
    int startIndex = 0,
  }) async {
    final uploaded = <MediaModel>[];

    for (var index = 0; index < mediaDrafts.length; index++) {
      final draft = mediaDrafts[index];
      final storageIndex = startIndex + index;
      final ref = _storage.ref(
        _storagePathForDraft(postId, draft, storageIndex),
      );
      final uploadFile =
          draft.isImage
              ? await _prepareImageFile(postId, draft.file, storageIndex)
              : draft.file;

      if (draft.isImage) {
        await _ensureImageContentAllowed(uploadFile);
      }

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

  Future<void> _deleteUploadedRefs(List<Reference> refs) async {
    for (final ref in refs) {
      try {
        await ref.delete();
      } catch (_) {}
    }
  }

  Future<void> _deleteRemovedMediaFiles(List<MediaModel> removedMedia) async {
    for (final media in removedMedia) {
      final url = media.url.trim();
      if (url.isEmpty) continue;

      try {
        await _storage.refFromURL(url).delete();
      } catch (_) {}
    }
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
      name: displayName.isNotEmpty ? displayName : 'Người dùng',
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

  PostVisibility _resolveVisibility({
    required PostVisibility? visibility,
    required bool? isPublic,
  }) {
    if (visibility != null) return visibility;
    if (isPublic != null) {
      return PostVisibility.fromLegacyIsPublic(isPublic);
    }
    return PostVisibility.public;
  }

  void _ensureReferencePostCanBeShared({
    required PostModel sourcePost,
    required PostVisibility requestedVisibility,
  }) {
    if (sourcePost.isPublic) return;
    if (requestedVisibility.isPrivate) return;
    if (sourcePost.authorId.trim() == uid.trim()) return;

    throw StateError(
      'Không thể đăng lại hoặc trích dẫn bài viết không công khai của người khác.',
    );
  }

  void _ensurePostCanBeMutated(PostModel post, {required String actionLabel}) {
    if (post.deletedAt != null) {
      throw StateError('Bài viết đã bị xóa trước đó.');
    }

    if (post.authorId.trim() != uid.trim()) {
      throw StateError('Bạn không thể $actionLabel bài viết này.');
    }
  }

  void _ensureExistingReferenceCanUseVisibility({
    required PostModel existingPost,
    required PostVisibility requestedVisibility,
  }) {
    if (!existingPost.postType.requiresReference) return;
    if (requestedVisibility.isPrivate) return;

    final referencePost = existingPost.referencePost;
    if (referencePost == null) return;
    if (referencePost.isPublic) return;
    if (referencePost.authorId.trim() == uid.trim()) return;

    throw StateError(
      'Không thể công khai bài viết trích dẫn từ bài viết không công khai của người khác.',
    );
  }

  List<MediaModel> _resolveRetainedMedia({
    required List<MediaModel> retainedMedia,
    required List<MediaModel> existingMedia,
  }) {
    final existingByUrl = <String, MediaModel>{
      for (final item in existingMedia)
        if (item.url.trim().isNotEmpty) item.url.trim(): item,
    };
    final seenUrls = <String>{};
    final resolved = <MediaModel>[];

    for (final media in retainedMedia) {
      final url = media.url.trim();
      if (url.isEmpty || !seenUrls.add(url)) continue;

      final existing = existingByUrl[url];
      if (existing == null) {
        throw StateError('Tệp đính kèm không hợp lệ.');
      }

      resolved.add(existing);
    }

    return resolved;
  }

  List<MediaModel> _removedMediaFiles({
    required List<MediaModel> previousMedia,
    required List<MediaModel> retainedMedia,
  }) {
    final retainedUrls =
        retainedMedia
            .map((media) => media.url.trim())
            .where((url) => url.isNotEmpty)
            .toSet();

    return previousMedia
        .where((media) => !retainedUrls.contains(media.url.trim()))
        .toList(growable: false);
  }

  String _repostDocId(String sourcePostId) {
    final sanitized = sourcePostId.trim().replaceAll('/', '_');
    return 'repost_${uid}_$sanitized';
  }

  Future<void> _ensureTextContentAllowed(String content) async {
    if (content.trim().isEmpty) return;

    try {
      final result = await _textModerationService.moderate(content);
      if (!result.isViolation) return;

      final reason = result.reason?.trim();
      throw StateError(
        reason == null || reason.isEmpty
            ? 'Nội dung bài viết vi phạm tiêu chuẩn cộng đồng.'
            : 'Nội dung bài viết vi phạm tiêu chuẩn cộng đồng: $reason',
      );
    } on StateError {
      rethrow;
    } on TimeoutException {
      throw StateError(
        'Không thể kiểm duyệt nội dung lúc này. Vui lòng thử lại sau.',
      );
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'unauthenticated') {
        throw StateError('Bạn cần đăng nhập để đăng bài viết.');
      }

      if (error.code == 'invalid-argument') {
        throw StateError('Nội dung bài viết không hợp lệ.');
      }

      throw StateError(
        'Không thể kiểm duyệt nội dung lúc này. Vui lòng thử lại sau.',
      );
    } catch (_) {
      throw StateError(
        'Không thể kiểm duyệt nội dung lúc này. Vui lòng thử lại sau.',
      );
    }
  }

  Future<void> _ensureImageContentAllowed(File imageFile) async {
    try {
      final result = await _imageModerationService.moderate(
        imageFile,
        context: 'post',
      );
      if (!result.isViolation) return;

      final reason = result.reason?.trim();
      final penaltyMessage =
          result.penalty > 0
              ? ' Bạn bị trừ ${result.penalty} điểm uy tín.'
              : '';
      throw StateError(
        reason == null || reason.isEmpty
            ? 'Hình ảnh vi phạm tiêu chuẩn cộng đồng.$penaltyMessage'
            : 'Hình ảnh vi phạm tiêu chuẩn cộng đồng: $reason.$penaltyMessage',
      );
    } on StateError {
      rethrow;
    } on TimeoutException {
      throw StateError(
        'Không thể kiểm duyệt hình ảnh lúc này. Vui lòng thử lại sau.',
      );
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'unauthenticated') {
        throw StateError('Bạn cần đăng nhập để đăng bài viết.');
      }

      if (error.code == 'invalid-argument') {
        throw StateError('Hình ảnh không hợp lệ.');
      }

      if (error.code == 'failed-precondition') {
        throw StateError(
          'Điểm uy tín dưới $minReputationToCreatePost nên bạn không thể đăng bài viết.',
        );
      }

      throw StateError(
        'Không thể kiểm duyệt hình ảnh lúc này. Vui lòng thử lại sau.',
      );
    } catch (_) {
      throw StateError(
        'Không thể kiểm duyệt hình ảnh lúc này. Vui lòng thử lại sau.',
      );
    }
  }

  Future<void> _ensureCanCreatePostByReputation() async {
    final user = await _userService.getUser(uid);
    if (user == null) {
      throw StateError(
        'KhÃ´ng tÃ¬m tháº¥y thÃ´ng tin ngÆ°á»i dÃ¹ng hiá»‡n táº¡i.',
      );
    }

    if (user.reputationScore >= minReputationToCreatePost) return;

    throw StateError(
      'Điểm uy tín dưới $minReputationToCreatePost nên bạn không thể đăng bài viết.',
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

  DateTime? _asDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
