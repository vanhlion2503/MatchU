import 'package:cloud_firestore/cloud_firestore.dart';

class UserReportMatchingModel {
  final String roomId;
  final String fromUid;
  final String toUid;
  final String reason;
  final String description;
  final DateTime createdAt;

  UserReportMatchingModel({
    required this.roomId,
    required this.fromUid,
    required this.toUid,
    required this.reason,
    this.description = "",
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        "roomId": roomId,
        "fromUid": fromUid,
        "toUid": toUid,
        "reason": reason,
        "description": description,
        "createdAt": Timestamp.fromDate(createdAt),
      };
}
