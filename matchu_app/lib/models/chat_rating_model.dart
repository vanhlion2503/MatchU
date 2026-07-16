import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRatingModel {
  final String roomId;
  final String fromUid;
  final String toUid;
  final double score;
  final bool skipped;
  final DateTime createdAt;

  ChatRatingModel({
    required this.roomId,
    required this.fromUid,
    required this.toUid,
    required this.score,
    required this.skipped,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    "roomId": roomId,
    "fromUid": fromUid,
    "toUid": toUid,
    "score": score,
    "skipped": skipped,
    "createdAt": Timestamp.fromDate(createdAt),
  };
}
