import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:matchu_app/models/feed/media_model.dart';
import 'package:matchu_app/models/feed/stats_model.dart';

enum PostType {
  post,
  quote,
  repost;

  bool get requiresReference => this != PostType.post;
  bool get isRepostOnly => this == PostType.repost;

  String get firestoreValue {
    switch (this) {
      case PostType.post:
        return 'post';
      case PostType.quote:
        return 'quote';
      case PostType.repost:
        return 'repost';
    }
  }

  static PostType fromFirestoreValue(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase();
    switch (normalized) {
      case 'quote':
        return PostType.quote;
      case 'repost':
        return PostType.repost;
      default:
        return PostType.post;
    }
  }
}

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

class PostReferenceModel {
  const PostReferenceModel({
    required this.postId,
    required this.authorId,
    required this.postType,
    required this.content,
    required this.media,
    required this.tags,
    required this.isPublic,
    required this.author,
    this.createdAt,
    this.deletedAt,
  });

  final String postId;
  final String authorId;
  final PostType postType;
  final String content;
  final List<MediaModel> media;
  final List<String> tags;
  final bool isPublic;
  final PostAuthorModel author;
  final DateTime? createdAt;
  final DateTime? deletedAt;

  bool get hasContent => content.trim().isNotEmpty;
  bool get hasMedia => media.isNotEmpty;
  bool get isUnavailable => deletedAt != null;

  factory PostReferenceModel.fromPost(PostModel post) {
    return PostReferenceModel(
      postId: post.postId,
      authorId: post.authorId,
      postType: post.postType,
      content: post.content,
      media: post.media,
      tags: post.tags,
      isPublic: post.isPublic,
      author: post.author,
      createdAt: post.createdAt,
      deletedAt: post.deletedAt,
    );
  }

  factory PostReferenceModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const PostReferenceModel(
        postId: '',
        authorId: '',
        postType: PostType.post,
        content: '',
        media: <MediaModel>[],
        tags: <String>[],
        isPublic: true,
        author: PostAuthorModel(
          id: '',
          name: '',
          nickname: '',
          avatar: '',
          isVerified: false,
        ),
      );
    }

    return PostReferenceModel(
      postId: (json['postId'] ?? '').toString(),
      authorId: (json['authorId'] ?? '').toString(),
      postType: PostType.fromFirestoreValue(json['postType']),
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
      isPublic: json['isPublic'] != false,
      author: PostAuthorModel.fromJson(_asMap(json['author'])),
      createdAt: _parseDateTime(json['createdAt']),
      deletedAt: _parseDateTime(json['deletedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'postId': postId,
      'authorId': authorId,
      'postType': postType.firestoreValue,
      'content': content,
      'media': media.map((item) => item.toJson()).toList(growable: false),
      'tags': tags,
      'isPublic': isPublic,
      'author': author.toJson(),
      'createdAt': createdAt,
      'deletedAt': deletedAt,
    };
  }

  PostReferenceModel copyWith({
    String? postId,
    String? authorId,
    PostType? postType,
    String? content,
    List<MediaModel>? media,
    List<String>? tags,
    bool? isPublic,
    PostAuthorModel? author,
    DateTime? createdAt,
    DateTime? deletedAt,
  }) {
    return PostReferenceModel(
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      postType: postType ?? this.postType,
      content: content ?? this.content,
      media: media ?? this.media,
      tags: tags ?? this.tags,
      isPublic: isPublic ?? this.isPublic,
      author: author ?? this.author,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }
}

class PostModel {
  const PostModel({
    required this.postId,
    required this.authorId,
    required this.postType,
    required this.content,
    required this.media,
    required this.tags,
    required this.isPublic,
    required this.stats,
    required this.trendScore,
    required this.trendBucket,
    required this.author,
    this.referencePostId,
    this.referencePost,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.isLiked = false,
    this.isLikePending = false,
    this.isReposted = false,
    this.isRepostPending = false,
    this.isSaved = false,
    this.isSavePending = false,
  });

  final String postId;
  final String authorId;
  final PostType postType;
  final String content;
  final List<MediaModel> media;
  final List<String> tags;
  final bool isPublic;
  final StatsModel stats;
  final double trendScore;
  final int trendBucket;
  final PostAuthorModel author;
  final String? referencePostId;
  final PostReferenceModel? referencePost;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  // Local UI state, not stored in Firestore.
  final bool isLiked;
  final bool isLikePending;
  final bool isReposted;
  final bool isRepostPending;
  final bool isSaved;
  final bool isSavePending;

  bool get hasContent => content.trim().isNotEmpty;
  bool get hasMedia => media.isNotEmpty;
  bool get hasReferencePost => referencePost != null;
  bool get isQuotePost => postType == PostType.quote && referencePost != null;
  bool get isRepostOnly => postType == PostType.repost && referencePost != null;
  bool get isStandardPost => postType == PostType.post;

  factory PostModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return PostModel.fromJson(doc.data() ?? <String, dynamic>{}, doc.id);
  }

  factory PostModel.fromJson(Map<String, dynamic> json, String fallbackPostId) {
    final parsedReference = PostReferenceModel.fromJson(
      _asMap(json['referencePost']),
    );
    final parsedReferenceId =
        (json['referencePostId'] ?? parsedReference.postId).toString().trim();

    return PostModel(
      postId: (json['postId'] ?? fallbackPostId).toString(),
      authorId: (json['authorId'] ?? '').toString(),
      postType: PostType.fromFirestoreValue(json['postType']),
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
      referencePostId: parsedReferenceId.isEmpty ? null : parsedReferenceId,
      referencePost: parsedReference.postId.isEmpty ? null : parsedReference,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      deletedAt: _parseDateTime(json['deletedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'postId': postId,
      'authorId': authorId,
      'postType': postType.firestoreValue,
      'content': content,
      'media': media.map((item) => item.toJson()).toList(growable: false),
      'tags': tags,
      'isPublic': isPublic,
      'stats': stats.toJson(),
      'trendScore': trendScore,
      'trendBucket': trendBucket,
      'author': author.toJson(),
      'referencePostId': referencePostId,
      'referencePost': referencePost?.toJson(),
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'deletedAt': deletedAt,
    };
  }

  PostModel copyWith({
    String? postId,
    String? authorId,
    PostType? postType,
    String? content,
    List<MediaModel>? media,
    List<String>? tags,
    bool? isPublic,
    StatsModel? stats,
    double? trendScore,
    int? trendBucket,
    PostAuthorModel? author,
    String? referencePostId,
    PostReferenceModel? referencePost,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool? isLiked,
    bool? isLikePending,
    bool? isReposted,
    bool? isRepostPending,
    bool? isSaved,
    bool? isSavePending,
  }) {
    return PostModel(
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      postType: postType ?? this.postType,
      content: content ?? this.content,
      media: media ?? this.media,
      tags: tags ?? this.tags,
      isPublic: isPublic ?? this.isPublic,
      stats: stats ?? this.stats,
      trendScore: trendScore ?? this.trendScore,
      trendBucket: trendBucket ?? this.trendBucket,
      author: author ?? this.author,
      referencePostId: referencePostId ?? this.referencePostId,
      referencePost: referencePost ?? this.referencePost,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      isLiked: isLiked ?? this.isLiked,
      isLikePending: isLikePending ?? this.isLikePending,
      isReposted: isReposted ?? this.isReposted,
      isRepostPending: isRepostPending ?? this.isRepostPending,
      isSaved: isSaved ?? this.isSaved,
      isSavePending: isSavePending ?? this.isSavePending,
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
