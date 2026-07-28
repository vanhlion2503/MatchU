import 'package:cloud_firestore/cloud_firestore.dart';

class CommentReportModel {
  const CommentReportModel({
    required this.fromUid,
    required this.toUid,
    required this.postId,
    required this.commentId,
    required this.categoryKey,
    required this.categoryTitle,
    required this.reasonKey,
    required this.reasonTitle,
    required this.createdAt,
    this.parentId,
    this.commentContentPreview = '',
    this.commentImageUrl = '',
    this.commentVoiceUrl = '',
    this.commentAuthorName = '',
    this.commentAuthorNickname = '',
    this.customReason = '',
    this.description = '',
  });

  final String fromUid;
  final String toUid;
  final String postId;
  final String commentId;
  final String? parentId;
  final String commentContentPreview;
  final String commentImageUrl;
  final String commentVoiceUrl;
  final String commentAuthorName;
  final String commentAuthorNickname;
  final String categoryKey;
  final String categoryTitle;
  final String reasonKey;
  final String reasonTitle;
  final String customReason;
  final String description;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'fromUid': fromUid,
      'toUid': toUid,
      'postId': postId,
      'commentId': commentId,
      'parentId': parentId,
      'commentContentPreview': commentContentPreview,
      'commentImageUrl': commentImageUrl,
      'commentVoiceUrl': commentVoiceUrl,
      'commentAuthorName': commentAuthorName,
      'commentAuthorNickname': commentAuthorNickname,
      'categoryKey': categoryKey,
      'categoryTitle': categoryTitle,
      'reasonKey': reasonKey,
      'reasonTitle': reasonTitle,
      'customReason': customReason,
      'description': description,
      'source': 'comment',
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
