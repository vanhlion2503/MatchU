import 'package:matchu_app/models/feed/post_model.dart';

class RecommendationScore {
  const RecommendationScore({
    required this.postId,
    required this.contentBasedScore,
    required this.trendingScore,
    required this.followingBoost,
    required this.finalScore,
    this.discoveryScore = 0,
    this.seenPenalty = 0,
  });

  final String postId;
  final double contentBasedScore;
  final double trendingScore;
  final double discoveryScore;
  final double followingBoost;
  final double finalScore;
  final double seenPenalty;

  Map<String, dynamic> toJson() {
    return {
      'postId': postId,
      'contentBasedScore': contentBasedScore,
      'trendingScore': trendingScore,
      'discoveryScore': discoveryScore,
      'followingBoost': followingBoost,
      'finalScore': finalScore,
      'seenPenalty': seenPenalty,
    };
  }
}

class PaginatedRecommendations {
  const PaginatedRecommendations({
    required this.posts,
    required this.limit,
    required this.page,
    required this.hasMore,
    required this.metadata,
    this.scoresByPostId = const <String, RecommendationScore>{},
    this.sessionId,
    this.poolId,
  });

  final List<PostModel> posts;
  final int limit;
  final int page;
  final bool hasMore;
  final Map<String, dynamic> metadata;
  final Map<String, RecommendationScore> scoresByPostId;
  final String? sessionId;
  final String? poolId;
}
