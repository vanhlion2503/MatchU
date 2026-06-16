import 'package:cloud_firestore/cloud_firestore.dart';

class PostReportModel {
  PostReportModel({
    required this.fromUid,
    required this.toUid,
    required this.postId,
    required this.postType,
    required this.categoryKey,
    required this.categoryTitle,
    required this.reasonKey,
    required this.reasonTitle,
    required this.createdAt,
    this.postAuthorName = '',
    this.postAuthorNickname = '',
    this.postContentPreview = '',
    this.postMediaUrls = const [],
    this.customReason = '',
    this.description = '',
    this.imageUrls = const [],
  });

  final String fromUid;
  final String toUid;
  final String postId;
  final String postType;
  final String postAuthorName;
  final String postAuthorNickname;
  final String postContentPreview;
  final List<String> postMediaUrls;
  final String categoryKey;
  final String categoryTitle;
  final String reasonKey;
  final String reasonTitle;
  final String customReason;
  final String description;
  final List<String> imageUrls;
  final DateTime createdAt;

  Map<String, dynamic> toJson({List<String>? imageUrlsOverride}) {
    return {
      'fromUid': fromUid,
      'toUid': toUid,
      'postId': postId,
      'postType': postType,
      'postAuthorName': postAuthorName,
      'postAuthorNickname': postAuthorNickname,
      'postContentPreview': postContentPreview,
      'postMediaUrls': postMediaUrls,
      'categoryKey': categoryKey,
      'categoryTitle': categoryTitle,
      'reasonKey': reasonKey,
      'reasonTitle': reasonTitle,
      'customReason': customReason,
      'description': description,
      'imageUrls': imageUrlsOverride ?? imageUrls,
      'source': 'post',
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
