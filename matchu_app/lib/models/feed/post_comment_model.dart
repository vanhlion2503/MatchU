import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:matchu_app/models/user_model.dart';

class PostCommentAuthorModel {
  const PostCommentAuthorModel({
    required this.userId,
    required this.displayName,
    required this.nickname,
    required this.avatarUrl,
    required this.isVerified,
  });

  final String userId;
  final String displayName;
  final String nickname;
  final String avatarUrl;
  final bool isVerified;

  factory PostCommentAuthorModel.fromUser(UserModel? user, String userId) {
    final nickname = user?.nickname.trim() ?? '';
    final fullname = user?.fullname.trim() ?? '';

    return PostCommentAuthorModel(
      userId: userId,
      displayName:
          fullname.isNotEmpty
              ? fullname
              : (nickname.isNotEmpty ? nickname : 'Người dùng'),
      nickname: nickname,
      avatarUrl: user?.avatarUrl ?? '',
      isVerified: user?.isFaceVerified ?? false,
    );
  }

  PostCommentAuthorModel copyWith({
    String? userId,
    String? displayName,
    String? nickname,
    String? avatarUrl,
    bool? isVerified,
  }) {
    return PostCommentAuthorModel(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isVerified: isVerified ?? this.isVerified,
    );
  }
}

class PostCommentModel {
  const PostCommentModel({
    required this.commentId,
    required this.userId,
    required this.content,
    required this.parentId,
    required this.likeCount,
    required this.replyCount,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.deletedBy,
    this.author,
    this.isEdited = false,
    this.isLiked = false,
    this.isLikePending = false,
    this.isSending = false,
  });

  final String commentId;
  final String userId;
  final String content;
  final String? parentId;
  final int likeCount;
  final int replyCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final String? deletedBy;
  final PostCommentAuthorModel? author;
  final bool isEdited;

  // Local UI state, not stored in Firestore.
  final bool isLiked;
  final bool isLikePending;
  final bool isSending;

  bool get isReply => parentId != null && parentId!.trim().isNotEmpty;
  bool get isDeleted => deletedAt != null;

  factory PostCommentModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return PostCommentModel.fromJson(doc.data() ?? <String, dynamic>{}, doc.id);
  }

  factory PostCommentModel.fromJson(
    Map<String, dynamic> json,
    String fallbackCommentId,
  ) {
    return PostCommentModel(
      commentId: (json['commentId'] ?? fallbackCommentId).toString(),
      userId: (json['userId'] ?? '').toString(),
      content: (json['content'] ?? '').toString().trim(),
      parentId: _parseParentId(json['parentId']),
      likeCount: _parseInt(json['likeCount']),
      replyCount: _parseInt(json['replyCount']),
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      deletedAt: _parseDateTime(json['deletedAt']),
      deletedBy: _parseNullableString(json['deletedBy']),
      isEdited: json['isEdited'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'commentId': commentId,
      'userId': userId,
      'content': content,
      'parentId': parentId,
      'likeCount': likeCount,
      'replyCount': replyCount,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'deletedAt': deletedAt,
      'deletedBy': deletedBy,
      'isEdited': isEdited,
    };
  }

  PostCommentModel copyWith({
    String? commentId,
    String? userId,
    String? content,
    String? parentId,
    int? likeCount,
    int? replyCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? deletedBy,
    PostCommentAuthorModel? author,
    bool? isEdited,
    bool? isLiked,
    bool? isLikePending,
    bool? isSending,
  }) {
    return PostCommentModel(
      commentId: commentId ?? this.commentId,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      parentId: parentId ?? this.parentId,
      likeCount: likeCount ?? this.likeCount,
      replyCount: replyCount ?? this.replyCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      author: author ?? this.author,
      isEdited: isEdited ?? this.isEdited,
      isLiked: isLiked ?? this.isLiked,
      isLikePending: isLikePending ?? this.isLikePending,
      isSending: isSending ?? this.isSending,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static String? _parseParentId(dynamic value) {
    if (value == null) return null;
    final normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }

  static String? _parseNullableString(dynamic value) {
    if (value == null) return null;
    final normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}
