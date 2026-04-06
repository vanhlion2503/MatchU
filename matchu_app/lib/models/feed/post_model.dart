import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:matchu_app/models/feed/media_model.dart';
import 'package:matchu_app/models/feed/stats_model.dart';

class PostAuthorModel {
  const PostAuthorModel({
    required this.id,
    required this.name,
    required this.nickname,
    required this.avatar,
    required this.isVerified,
  });

  final String id;
  final String name;
  final String nickname;
  final String avatar;
  final bool isVerified;

  factory PostAuthorModel.fromJson(Map<String, dynamic>? json) {
    return PostAuthorModel(
      id: (json?['id'] ?? '').toString(),
      name: (json?['name'] ?? '').toString(),
      nickname: (json?['nickname'] ?? '').toString(),
      avatar: (json?['avatar'] ?? '').toString(),
      isVerified: json?['isVerified'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'nickname': nickname,
      'avatar': avatar,
      'isVerified': isVerified,
    };
  }

  PostAuthorModel copyWith({
    String? id,
    String? name,
    String? nickname,
    String? avatar,
    bool? isVerified,
  }) {
    return PostAuthorModel(
      id: id ?? this.id,
      name: name ?? this.name,
      nickname: nickname ?? this.nickname,
      avatar: avatar ?? this.avatar,
      isVerified: isVerified ?? this.isVerified,
    );
  }
}

class PostModel {
  const PostModel({
    required this.postId,
    required this.authorId,
    required this.content,
    required this.media,
    required this.tags,
    required this.isPublic,
    required this.stats,
    required this.trendScore,
    required this.trendBucket,
    required this.author,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.isLiked = false,
    this.isLikePending = false,
  });

  final String postId;
  final String authorId;
  final String content;
  final List<MediaModel> media;
  final List<String> tags;
  final bool isPublic;
  final StatsModel stats;
  final double trendScore;
  final int trendBucket;
  final PostAuthorModel author;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  // Local UI state, not stored in Firestore.
  final bool isLiked;
  final bool isLikePending;

  bool get hasContent => content.trim().isNotEmpty;
  bool get hasMedia => media.isNotEmpty;

  factory PostModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return PostModel.fromJson(doc.data() ?? <String, dynamic>{}, doc.id);
  }

  factory PostModel.fromJson(Map<String, dynamic> json, String fallbackPostId) {
    return PostModel(
      postId: (json['postId'] ?? fallbackPostId).toString(),
      authorId: (json['authorId'] ?? '').toString(),
      content: (json['content'] ?? '').toString().trim(),
      media: ((json['media'] as List<dynamic>?) ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .map(MediaModel.fromJson)
          .where((item) => item.url.isNotEmpty)
          .toList(growable: false),
      tags: ((json['tags'] as List<dynamic>?) ?? const [])
          .map((tag) => tag.toString().trim())
          .where((tag) => tag.isNotEmpty)
          .toList(growable: false),
      isPublic: json['isPublic'] == true,
      stats: StatsModel.fromJson(_asMap(json['stats'])),
      trendScore: _parseDouble(json['trendScore']),
      trendBucket: _parseInt(json['trendBucket']),
      author: PostAuthorModel.fromJson(_asMap(json['author'])),
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      deletedAt: _parseDateTime(json['deletedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'postId': postId,
      'authorId': authorId,
      'content': content,
      'media': media.map((item) => item.toJson()).toList(growable: false),
      'tags': tags,
      'isPublic': isPublic,
      'stats': stats.toJson(),
      'trendScore': trendScore,
      'trendBucket': trendBucket,
      'author': author.toJson(),
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'deletedAt': deletedAt,
    };
  }

  PostModel copyWith({
    String? postId,
    String? authorId,
    String? content,
    List<MediaModel>? media,
    List<String>? tags,
    bool? isPublic,
    StatsModel? stats,
    double? trendScore,
    int? trendBucket,
    PostAuthorModel? author,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool? isLiked,
    bool? isLikePending,
  }) {
    return PostModel(
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      content: content ?? this.content,
      media: media ?? this.media,
      tags: tags ?? this.tags,
      isPublic: isPublic ?? this.isPublic,
      stats: stats ?? this.stats,
      trendScore: trendScore ?? this.trendScore,
      trendBucket: trendBucket ?? this.trendBucket,
      author: author ?? this.author,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      isLiked: isLiked ?? this.isLiked,
      isLikePending: isLikePending ?? this.isLikePending,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return 0;
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }
}
