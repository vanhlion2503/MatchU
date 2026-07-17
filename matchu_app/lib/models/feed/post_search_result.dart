import 'package:matchu_app/models/feed/post_model.dart';

enum PostSearchMatchType {
  exactSentence,
  keyPhrase,
  allTerms,
  partial,
  hashtagOnly;

  factory PostSearchMatchType.fromApi(String value) {
    return switch (value.trim()) {
      'exact_sentence' => PostSearchMatchType.exactSentence,
      'key_phrase' => PostSearchMatchType.keyPhrase,
      'all_terms' => PostSearchMatchType.allTerms,
      'hashtag_only' => PostSearchMatchType.hashtagOnly,
      _ => PostSearchMatchType.partial,
    };
  }

  String get label {
    return switch (this) {
      PostSearchMatchType.exactSentence => 'Khớp toàn bộ câu',
      PostSearchMatchType.keyPhrase => 'Khớp cụm từ chính',
      PostSearchMatchType.allTerms => 'Khớp tất cả từ',
      PostSearchMatchType.partial => 'Khớp một phần',
      PostSearchMatchType.hashtagOnly => 'Khớp hashtag',
    };
  }
}

class PostSearchItem {
  const PostSearchItem({
    required this.post,
    required this.matchType,
    required this.score,
  });

  final PostModel post;
  final PostSearchMatchType matchType;
  final double score;

  int get scorePercent => (score * 100).round();

  PostSearchItem copyWith({PostModel? post}) {
    return PostSearchItem(
      post: post ?? this.post,
      matchType: matchType,
      score: score,
    );
  }
}

class PostSearchPage {
  const PostSearchPage({
    required this.items,
    required this.hasMore,
    required this.totalMatched,
    required this.nextOffset,
  });

  final List<PostSearchItem> items;
  final bool hasMore;
  final int totalMatched;
  final int nextOffset;
}
