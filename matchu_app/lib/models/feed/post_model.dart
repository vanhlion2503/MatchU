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

enum PostVisibility {
  public,
  followers,
  private;

  String get firestoreValue {
    switch (this) {
      case PostVisibility.public:
        return 'public';
      case PostVisibility.followers:
        return 'followers';
      case PostVisibility.private:
        return 'private';
    }
  }

  bool get isPublic => this == PostVisibility.public;
  bool get isFollowersOnly => this == PostVisibility.followers;
  bool get isPrivate => this == PostVisibility.private;

  static PostVisibility fromFirestoreValue(
    dynamic value, {
    dynamic legacyIsPublic,
  }) {
    final normalized = value?.toString().trim().toLowerCase();
    switch (normalized) {
      case 'public':
        return PostVisibility.public;
      case 'followers':
      case 'followers_only':
      case 'followersonly':
        return PostVisibility.followers;
      case 'private':
        return PostVisibility.private;
    }

    if (legacyIsPublic == false) {
      return PostVisibility.private;
    }

    return PostVisibility.public;
  }

  static PostVisibility fromLegacyIsPublic(bool isPublic) {
    return isPublic ? PostVisibility.public : PostVisibility.private;
  }
}

enum PostModerationStatus {
  pendingModeration,
  approved,
  rejected,
  reviewRequired;

  String get firestoreValue {
    switch (this) {
      case PostModerationStatus.pendingModeration:
        return 'pending_moderation';
      case PostModerationStatus.approved:
        return 'approved';
      case PostModerationStatus.rejected:
        return 'rejected';
      case PostModerationStatus.reviewRequired:
        return 'review_required';
    }
  }

  bool get isPendingModeration =>
      this == PostModerationStatus.pendingModeration;
  bool get isApproved => this == PostModerationStatus.approved;
  bool get isRejected => this == PostModerationStatus.rejected;
  bool get isReviewRequired => this == PostModerationStatus.reviewRequired;
  bool get isFinalDecision => isApproved || isRejected || isReviewRequired;

  static PostModerationStatus fromFirestoreValue(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase();
    switch (normalized) {
      case 'pending_moderation':
      case 'pending':
      case 'processing':
        return PostModerationStatus.pendingModeration;
      case 'rejected':
        return PostModerationStatus.rejected;
      case 'review_required':
      case 'needs_review':
      case 'human_review':
        return PostModerationStatus.reviewRequired;
      case 'approved':
      default:
        return PostModerationStatus.approved;
    }
  }
}

enum PostRecommendationStatus {
  unknown,
  ready,
  discoveryOnly,
  failed,
  ineligible;

  static PostRecommendationStatus fromFirestoreValue(dynamic value) {
    switch (value?.toString().trim().toLowerCase()) {
      case 'ready':
        return PostRecommendationStatus.ready;
      case 'discovery_only':
        return PostRecommendationStatus.discoveryOnly;
      case 'failed':
        return PostRecommendationStatus.failed;
      case 'ineligible':
        return PostRecommendationStatus.ineligible;
      default:
        return PostRecommendationStatus.unknown;
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
    this.contentVector = const <double>[],
    required this.author,
    PostVisibility? visibility,
    bool? isPublic,
    this.createdAt,
    this.deletedAt,
  }) : visibility =
           visibility ??
           (isPublic == false ? PostVisibility.private : PostVisibility.public);

  final String postId;
  final String authorId;
  final PostType postType;
  final String content;
  final List<MediaModel> media;
  final List<String> tags;
  final List<double> contentVector;
  final PostVisibility visibility;
  final PostAuthorModel author;
  final DateTime? createdAt;
  final DateTime? deletedAt;

  bool get isPublic => visibility.isPublic;
  bool get isFollowersOnly => visibility.isFollowersOnly;
  bool get isPrivate => visibility.isPrivate;
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
      contentVector: post.contentVector,
      visibility: post.visibility,
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
        visibility: PostVisibility.public,
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
          .where(
            (item) =>
                item.url.isNotEmpty ||
                (item.storagePath?.trim().isNotEmpty ?? false),
          )
          .toList(growable: false),
      tags: ((json['tags'] as List<dynamic>?) ?? const [])
          .map((tag) => tag.toString().trim())
          .where((tag) => tag.isNotEmpty)
          .toList(growable: false),
      contentVector: _parseDoubleList(json['contentVector']),
      visibility: PostVisibility.fromFirestoreValue(
        json['visibility'],
        legacyIsPublic: json['isPublic'],
      ),
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
      'contentVector': contentVector,
      'visibility': visibility.firestoreValue,
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
    List<double>? contentVector,
    PostVisibility? visibility,
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
      contentVector: contentVector ?? this.contentVector,
      visibility:
          visibility ??
          (isPublic == null
              ? this.visibility
              : PostVisibility.fromLegacyIsPublic(isPublic)),
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

  static List<double> _parseDoubleList(dynamic value) {
    if (value is! List) return const <double>[];
    return value
        .whereType<num>()
        .map((item) => item.toDouble())
        .toList(growable: false);
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
    this.contentVector = const <double>[],
    this.contentEmbeddingModel,
    this.contentEmbeddingSignature,
    this.contentVectorDimensions = 0,
    this.contentVectorSearchKey,
    this.contentVectorUpdatedAt,
    this.recommendationStatus = PostRecommendationStatus.unknown,
    this.recommendationErrorCode,
    this.recommendationAttemptCount = 0,
    this.recommendationUpdatedAt,
    required this.stats,
    required this.trendScore,
    required this.trendBucket,
    required this.author,
    PostVisibility? visibility,
    bool? isPublic,
    this.requestedVisibility,
    PostModerationStatus? moderationStatus,
    this.moderationSource,
    this.moderationMessageVi,
    this.moderationPolicyVersion,
    this.videoStoragePath,
    this.videoModeration,
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
  }) : visibility =
           visibility ??
           (isPublic == false ? PostVisibility.private : PostVisibility.public),
       moderationStatus = moderationStatus ?? PostModerationStatus.approved;

  final String postId;
  final String authorId;
  final PostType postType;
  final String content;
  final List<MediaModel> media;
  final List<String> tags;
  final List<double> contentVector;
  final String? contentEmbeddingModel;
  final String? contentEmbeddingSignature;
  final int contentVectorDimensions;
  final String? contentVectorSearchKey;
  final DateTime? contentVectorUpdatedAt;
  final PostRecommendationStatus recommendationStatus;
  final String? recommendationErrorCode;
  final int recommendationAttemptCount;
  final DateTime? recommendationUpdatedAt;
  final PostVisibility visibility;
  final PostVisibility? requestedVisibility;
  final PostModerationStatus moderationStatus;
  final String? moderationSource;
  final String? moderationMessageVi;
  final String? moderationPolicyVersion;
  final String? videoStoragePath;
  final Map<String, dynamic>? videoModeration;
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

  bool get isPublic => visibility.isPublic;
  bool get isFollowersOnly => visibility.isFollowersOnly;
  bool get isPrivate => visibility.isPrivate;
  bool get isModerationPending => moderationStatus.isPendingModeration;
  bool get isModerationApproved => moderationStatus.isApproved;
  bool get isRejectedByModeration => moderationStatus.isRejected;
  bool get isReviewRequiredByModeration => moderationStatus.isReviewRequired;
  bool get isHiddenByModeration =>
      isModerationPending ||
      isRejectedByModeration ||
      isReviewRequiredByModeration;
  bool get hasContent => content.trim().isNotEmpty;
  bool get hasMedia => media.isNotEmpty;
  bool get hasVideoMedia =>
      media.any((item) => item.isVideo) ||
      (videoStoragePath?.trim().isNotEmpty ?? false);
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
          .where(
            (item) =>
                item.url.isNotEmpty ||
                (item.storagePath?.trim().isNotEmpty ?? false),
          )
          .toList(growable: false),
      tags: ((json['tags'] as List<dynamic>?) ?? const [])
          .map((tag) => tag.toString().trim())
          .where((tag) => tag.isNotEmpty)
          .toList(growable: false),
      contentVector: _parseDoubleList(json['contentVector']),
      contentEmbeddingModel: _parseNullableString(
        json['contentEmbeddingModel'],
      ),
      contentEmbeddingSignature: _parseNullableString(
        json['contentEmbeddingSignature'],
      ),
      contentVectorDimensions: _parseInt(json['contentVectorDimensions']),
      contentVectorSearchKey: _parseNullableString(
        json['contentVectorSearchKey'],
      ),
      contentVectorUpdatedAt: _parseDateTime(json['contentVectorUpdatedAt']),
      recommendationStatus: PostRecommendationStatus.fromFirestoreValue(
        json['recommendationStatus'],
      ),
      recommendationErrorCode: _parseNullableString(
        json['recommendationErrorCode'],
      ),
      recommendationAttemptCount: _parseInt(json['recommendationAttemptCount']),
      recommendationUpdatedAt: _parseDateTime(json['recommendationUpdatedAt']),
      visibility: PostVisibility.fromFirestoreValue(
        json['visibility'],
        legacyIsPublic: json['isPublic'],
      ),
      requestedVisibility: _parseOptionalVisibility(
        json['requestedVisibility'],
      ),
      moderationStatus: PostModerationStatus.fromFirestoreValue(
        json['moderationStatus'],
      ),
      moderationSource: _parseNullableString(json['moderationSource']),
      moderationMessageVi: _parseNullableString(json['moderationMessageVi']),
      moderationPolicyVersion: _parseNullableString(
        json['moderationPolicyVersion'],
      ),
      videoStoragePath: _parseNullableString(json['videoStoragePath']),
      videoModeration: _asMap(json['videoModeration']),
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
      'contentVector': contentVector,
      'contentEmbeddingModel': contentEmbeddingModel,
      'contentEmbeddingSignature': contentEmbeddingSignature,
      'contentVectorDimensions': contentVectorDimensions,
      'contentVectorSearchKey': contentVectorSearchKey,
      'contentVectorUpdatedAt': contentVectorUpdatedAt,
      'recommendationStatus': _recommendationStatusFirestoreValue,
      'recommendationErrorCode': recommendationErrorCode,
      'recommendationAttemptCount': recommendationAttemptCount,
      'recommendationUpdatedAt': recommendationUpdatedAt,
      'visibility': visibility.firestoreValue,
      'isPublic': isPublic,
      'requestedVisibility': requestedVisibility?.firestoreValue,
      'moderationStatus': moderationStatus.firestoreValue,
      'moderationSource': moderationSource,
      'moderationMessageVi': moderationMessageVi,
      'moderationPolicyVersion': moderationPolicyVersion,
      'videoStoragePath': videoStoragePath,
      'videoModeration': videoModeration,
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
    List<double>? contentVector,
    String? contentEmbeddingModel,
    String? contentEmbeddingSignature,
    int? contentVectorDimensions,
    String? contentVectorSearchKey,
    DateTime? contentVectorUpdatedAt,
    PostRecommendationStatus? recommendationStatus,
    String? recommendationErrorCode,
    int? recommendationAttemptCount,
    DateTime? recommendationUpdatedAt,
    PostVisibility? visibility,
    bool? isPublic,
    PostVisibility? requestedVisibility,
    PostModerationStatus? moderationStatus,
    String? moderationSource,
    String? moderationMessageVi,
    String? moderationPolicyVersion,
    String? videoStoragePath,
    Map<String, dynamic>? videoModeration,
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
      contentVector: contentVector ?? this.contentVector,
      contentEmbeddingModel:
          contentEmbeddingModel ?? this.contentEmbeddingModel,
      contentEmbeddingSignature:
          contentEmbeddingSignature ?? this.contentEmbeddingSignature,
      contentVectorDimensions:
          contentVectorDimensions ?? this.contentVectorDimensions,
      contentVectorSearchKey:
          contentVectorSearchKey ?? this.contentVectorSearchKey,
      contentVectorUpdatedAt:
          contentVectorUpdatedAt ?? this.contentVectorUpdatedAt,
      recommendationStatus: recommendationStatus ?? this.recommendationStatus,
      recommendationErrorCode:
          recommendationErrorCode ?? this.recommendationErrorCode,
      recommendationAttemptCount:
          recommendationAttemptCount ?? this.recommendationAttemptCount,
      recommendationUpdatedAt:
          recommendationUpdatedAt ?? this.recommendationUpdatedAt,
      visibility:
          visibility ??
          (isPublic == null
              ? this.visibility
              : PostVisibility.fromLegacyIsPublic(isPublic)),
      requestedVisibility: requestedVisibility ?? this.requestedVisibility,
      moderationStatus: moderationStatus ?? this.moderationStatus,
      moderationSource: moderationSource ?? this.moderationSource,
      moderationMessageVi: moderationMessageVi ?? this.moderationMessageVi,
      moderationPolicyVersion:
          moderationPolicyVersion ?? this.moderationPolicyVersion,
      videoStoragePath: videoStoragePath ?? this.videoStoragePath,
      videoModeration: videoModeration ?? this.videoModeration,
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

  String get _recommendationStatusFirestoreValue {
    switch (recommendationStatus) {
      case PostRecommendationStatus.discoveryOnly:
        return 'discovery_only';
      case PostRecommendationStatus.ready:
        return 'ready';
      case PostRecommendationStatus.failed:
        return 'failed';
      case PostRecommendationStatus.ineligible:
        return 'ineligible';
      case PostRecommendationStatus.unknown:
        return 'unknown';
    }
  }

  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return 0;
  }

  static List<double> _parseDoubleList(dynamic value) {
    if (value is! List) return const <double>[];
    return value
        .whereType<num>()
        .map((item) => item.toDouble())
        .toList(growable: false);
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

  static String? _parseNullableString(dynamic value) {
    final normalized = value?.toString().trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  static PostVisibility? _parseOptionalVisibility(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase();
    switch (normalized) {
      case 'public':
      case 'followers':
      case 'followers_only':
      case 'followersonly':
      case 'private':
        return PostVisibility.fromFirestoreValue(normalized);
      default:
        return null;
    }
  }
}
