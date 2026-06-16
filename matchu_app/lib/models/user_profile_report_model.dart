import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfileReportModel {
  UserProfileReportModel({
    required this.fromUid,
    required this.toUid,
    required this.categoryKey,
    required this.categoryTitle,
    required this.reasonKey,
    required this.reasonTitle,
    required this.createdAt,
    this.customReason = '',
    this.description = '',
  });

  final String fromUid;
  final String toUid;
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
      'categoryKey': categoryKey,
      'categoryTitle': categoryTitle,
      'reasonKey': reasonKey,
      'reasonTitle': reasonTitle,
      'customReason': customReason,
      'description': description,
      'source': 'profile',
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
