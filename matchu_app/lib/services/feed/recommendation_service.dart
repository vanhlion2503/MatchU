import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/models/feed/recommendation_result.dart';
import 'package:matchu_app/models/user_model.dart';
import 'package:matchu_app/services/feed/embedding_service.dart';

class RecommendationService {
  RecommendationService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    EmbeddingService? embeddingService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance,
       _embeddingService = embeddingService ?? KeywordEmbeddingService();

  static const double minSimilarityThreshold = 0.7;
  static const double decayFloor = 0.6;
  static const double halfLifeDays = 3;
  static const double maxWeightCap = 100;
  static const int candidateLimit = 160;
  static const int trendingWindowDays = 7;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final EmbeddingService _embeddingService;

  CollectionReference<Map<String, dynamic>> get _postsRef =>
      _firestore.collection('posts');

  Future<PaginatedRecommendations> getRecommendedPosts({
    required String userId,
    int limit = 20,
    int page = 1,
    String? sessionId,
    bool forceRefresh = false,
  }) async {
    final stopwatch = Stopwatch()..start();
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty || limit <= 0) {
      return PaginatedRecommendations(
        posts: const <PostModel>[],
        limit: limit,
        page: page,
        hasMore: false,
        metadata: const <String, dynamic>{
          'totalRecommended': 0,
          'contentBasedCount': 0,
          'trendingCount': 0,
          'followingCount': 0,
          'processingTimeMs': 0,
          'ratio': 'empty',
        },
      );
    }

    try {
      final callable = _functions.httpsCallable('recommendPosts');
      final response = await callable.call<Map<String, dynamic>>({
        'limit': limit,
        'page': page,
        'forceRefresh': forceRefresh,
        if (sessionId?.trim().isNotEmpty == true)
          'sessionId': sessionId!.trim(),
      });
      final data = Map<String, dynamic>.from(response.data);
      final resolvedSessionId = data['sessionId']?.toString().trim();
      final postIds = (data['postIds'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
      final fetched = await _fetchPostsByIds(postIds);
      final posts = fetched.posts;
      stopwatch.stop();
      return PaginatedRecommendations(
        posts: posts,
        limit: limit,
        page: page,
        hasMore: data['hasMore'] == true,
        scoresByPostId: _parseScores(data['scoresByPostId']),
        metadata: Map<String, dynamic>.from(
          data['metadata'] as Map<dynamic, dynamic>? ?? const {},
        )..['clientProcessingTimeMs'] = stopwatch.elapsedMilliseconds,
        sessionId: resolvedSessionId,
        poolId: data['poolId']?.toString().trim(),
      );
    } catch (error) {
      debugPrint('RecommendationService.getRecommendedPosts failed: $error');
      stopwatch.stop();
      rethrow;
    }
  }

  Future<
    ({
      List<PostModel> posts,
      Map<String, DocumentSnapshot<Map<String, dynamic>>> snapshotsByPostId,
    })
  >
  _fetchPostsByIds(List<String> postIds) async {
    if (postIds.isEmpty) {
      return (
        posts: const <PostModel>[],
        snapshotsByPostId:
            const <String, DocumentSnapshot<Map<String, dynamic>>>{},
      );
    }

    final byPostId = <String, PostModel>{};
    final snapshotsByPostId =
        <String, DocumentSnapshot<Map<String, dynamic>>>{};
    for (var offset = 0; offset < postIds.length; offset += 30) {
      final end = offset + 30 < postIds.length ? offset + 30 : postIds.length;
      final ids = postIds.sublist(offset, end);
      try {
        final snapshot =
            await _postsRef.where(FieldPath.documentId, whereIn: ids).get();
        for (final doc in snapshot.docs) {
          final post = PostModel.fromDoc(doc);
          if (!_isEligiblePost(post)) continue;
          byPostId[post.postId] = post;
          snapshotsByPostId[post.postId] = doc;
        }
      } on FirebaseException {
        final fallbackDocs = await Future.wait(
          ids.map((postId) async {
            try {
              return await _postsRef.doc(postId).get();
            } on FirebaseException {
              return null;
            }
          }),
        );
        for (final doc
            in fallbackDocs
                .whereType<DocumentSnapshot<Map<String, dynamic>>>()) {
          if (!doc.exists) continue;
          final post = PostModel.fromDoc(doc);
          if (!_isEligiblePost(post)) continue;
          byPostId[post.postId] = post;
          snapshotsByPostId[post.postId] = doc;
        }
      }
    }

    return (
      posts: postIds
          .map((postId) => byPostId[postId])
          .whereType<PostModel>()
          .toList(growable: false),
      snapshotsByPostId: snapshotsByPostId,
    );
  }

  Map<String, RecommendationScore> _parseScores(dynamic rawScores) {
    if (rawScores is! Map) return const <String, RecommendationScore>{};

    final result = <String, RecommendationScore>{};
    for (final entry in rawScores.entries) {
      final postId = entry.key.toString().trim();
      final value = entry.value;
      if (postId.isEmpty || value is! Map) continue;

      final data = Map<String, dynamic>.from(value);
      result[postId] = RecommendationScore(
        postId: postId,
        contentBasedScore: _parseDouble(data['contentBasedScore']),
        trendingScore: _parseDouble(data['trendingScore']),
        followingBoost: _parseDouble(data['followingBoost']),
        finalScore: _parseDouble(data['finalScore']),
        seenPenalty: _parseDouble(data['seenPenalty']),
      );
    }
    return result;
  }

  List<RecommendationCandidate> getContentBasedPosts({
    required UserModel user,
    required List<PostModel> candidates,
  }) {
    final userVector = user.interestVector;
    if (userVector.isEmpty) return const <RecommendationCandidate>[];

    final now = DateTime.now();
    final scored = <RecommendationCandidate>[];
    for (final post in candidates) {
      final postVector = _embeddingService.vectorForPost(post);
      final similarity = calculateCosineSimilarity(userVector, postVector);
      if (similarity < minSimilarityThreshold) continue;

      final decayFactor = calculateTimeDecay(post.createdAt, now: now);
      scored.add(
        RecommendationCandidate(
          post: post,
          contentBasedScore: similarity * decayFactor,
        ),
      );
    }

    scored.sort((a, b) => b.contentBasedScore.compareTo(a.contentBasedScore));
    return scored;
  }

  List<RecommendationCandidate> getTrendingPosts({
    required List<PostModel> candidates,
  }) {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: trendingWindowDays));
    final scored = <RecommendationCandidate>[];

    for (final post in candidates) {
      final createdAt = post.createdAt;
      if (createdAt != null && createdAt.isBefore(cutoff)) continue;

      scored.add(
        RecommendationCandidate(
          post: post,
          trendingScore: calculateTrendingScore(post, now: now),
        ),
      );
    }

    scored.sort((a, b) => b.trendingScore.compareTo(a.trendingScore));
    return scored;
  }

  List<RecommendationCandidate> getFollowingPosts({
    required List<PostModel> candidates,
    required Set<String> followingIds,
  }) {
    if (followingIds.isEmpty) return const <RecommendationCandidate>[];

    final scored = candidates
        .where((post) => followingIds.contains(post.authorId.trim()))
        .map((post) => RecommendationCandidate(post: post, followingBoost: 1))
        .toList(growable: false);

    scored.sort((a, b) {
      final aCreatedAt =
          a.post.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bCreatedAt =
          b.post.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bCreatedAt.compareTo(aCreatedAt);
    });
    return scored;
  }

  List<RankedRecommendation> mergeAndRankRecommendations({
    required List<RecommendationCandidate> contentBasedPosts,
    required List<RecommendationCandidate> trendingPosts,
    required List<RecommendationCandidate> followingPosts,
    required double contentRatio,
    required double trendingRatio,
    required double followingRatio,
    required int limit,
  }) {
    final byPostId = <String, RecommendationCandidate>{};

    void merge(List<RecommendationCandidate> source) {
      for (final item in source) {
        final postId = item.post.postId.trim();
        if (postId.isEmpty) continue;

        final existing = byPostId[postId];
        byPostId[postId] =
            existing == null
                ? item
                : existing.copyWith(
                  contentBasedScore: math.max(
                    existing.contentBasedScore,
                    item.contentBasedScore,
                  ),
                  trendingScore: math.max(
                    existing.trendingScore,
                    item.trendingScore,
                  ),
                  followingBoost: math.max(
                    existing.followingBoost,
                    item.followingBoost,
                  ),
                );
      }
    }

    merge(contentBasedPosts);
    merge(trendingPosts);
    merge(followingPosts);

    final maxTrendingScore = byPostId.values.fold<double>(
      0,
      (maxScore, item) => math.max(maxScore, item.trendingScore),
    );

    final ranked = byPostId.values
        .map((item) {
          final normalizedTrendingScore =
              maxTrendingScore <= 0
                  ? 0.0
                  : item.trendingScore / maxTrendingScore;
          final finalScore =
              (item.contentBasedScore * contentRatio) +
              (normalizedTrendingScore * trendingRatio) +
              (item.followingBoost * followingRatio);

          return RankedRecommendation(
            post: item.post,
            score: RecommendationScore(
              postId: item.post.postId,
              contentBasedScore: item.contentBasedScore,
              trendingScore: normalizedTrendingScore,
              followingBoost: item.followingBoost,
              finalScore: finalScore,
            ),
          );
        })
        .toList(growable: false);

    ranked.sort((a, b) {
      final scoreCompare = b.score.finalScore.compareTo(a.score.finalScore);
      if (scoreCompare != 0) return scoreCompare;

      final aCreatedAt =
          a.post.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bCreatedAt =
          b.post.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bCreatedAt.compareTo(aCreatedAt);
    });

    return ranked.take(limit).toList(growable: false);
  }

  double calculateCosineSimilarity(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty || a.length != b.length) return 0;

    var dotProduct = 0.0;
    var magnitudeA = 0.0;
    var magnitudeB = 0.0;

    for (var index = 0; index < a.length; index++) {
      dotProduct += a[index] * b[index];
      magnitudeA += a[index] * a[index];
      magnitudeB += b[index] * b[index];
    }

    if (magnitudeA == 0 || magnitudeB == 0) return 0;
    return dotProduct / (math.sqrt(magnitudeA) * math.sqrt(magnitudeB));
  }

  double calculateTimeDecay(DateTime? createdAt, {DateTime? now}) {
    if (createdAt == null) return decayFloor;

    final resolvedNow = now ?? DateTime.now();
    final ageInDays = resolvedNow.difference(createdAt).inMinutes / 1440;
    final clampedAgeInDays = ageInDays.isNegative ? 0 : ageInDays;
    final exponentialDecay = math.pow(0.5, clampedAgeInDays / halfLifeDays);
    return math.max(decayFloor, exponentialDecay.toDouble()).clamp(0.0, 1.0);
  }

  double calculateTrendingScore(PostModel post, {DateTime? now}) {
    final rawEngagement =
        (post.stats.likeCount * 1.0) +
        (post.stats.commentCount * 0.8) +
        (post.stats.shareCount * 1.5);
    final freshness = calculateTimeDecay(post.createdAt, now: now);
    return (rawEngagement + post.trendScore + (post.trendBucket * 0.25)) *
        freshness;
  }

  bool _isEligiblePost(PostModel post) {
    return post.deletedAt == null &&
        post.isPublic &&
        post.isModerationApproved &&
        !post.postType.isRepostOnly;
  }

  double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return 0;
  }
}

class RecommendationCandidate {
  const RecommendationCandidate({
    required this.post,
    this.contentBasedScore = 0,
    this.trendingScore = 0,
    this.followingBoost = 0,
  });

  final PostModel post;
  final double contentBasedScore;
  final double trendingScore;
  final double followingBoost;

  RecommendationCandidate copyWith({
    double? contentBasedScore,
    double? trendingScore,
    double? followingBoost,
  }) {
    return RecommendationCandidate(
      post: post,
      contentBasedScore: contentBasedScore ?? this.contentBasedScore,
      trendingScore: trendingScore ?? this.trendingScore,
      followingBoost: followingBoost ?? this.followingBoost,
    );
  }
}

class RankedRecommendation {
  const RankedRecommendation({required this.post, required this.score});

  final PostModel post;
  final RecommendationScore score;
}
