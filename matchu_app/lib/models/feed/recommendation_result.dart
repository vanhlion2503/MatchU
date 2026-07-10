import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:matchu_app/models/feed/post_model.dart';

class RecommendationScore {
  const RecommendationScore({
    required this.postId,
    required this.contentBasedScore,
    required this.trendingScore,
    required this.followingBoost,
    required this.finalScore,
  });

  final String postId;
  final double contentBasedScore;
  final double trendingScore;
  final double followingBoost;
  final double finalScore;

  Map<String, dynamic> toJson() {
    return {
      'postId': postId,
      'contentBasedScore': contentBasedScore,
      'trendingScore': trendingScore,
      'followingBoost': followingBoost,
      'finalScore': finalScore,
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
    this.lastDocument,
    this.scoresByPostId = const <String, RecommendationScore>{},
  });

  final List<PostModel> posts;
  final int limit;
  final int page;
  final bool hasMore;
  final Map<String, dynamic> metadata;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final Map<String, RecommendationScore> scoresByPostId;
}
