import 'package:cloud_firestore/cloud_firestore.dart';

class TempChatRoomModel {
  final String roomId;
  final String userA;
  final String userB;

  /// 🔥 BẮT BUỘC cho matching
  final List<String> participants;

  final DateTime createdAt;
  final DateTime expireAt;

  final bool userALiked;
  final bool userBLiked;

  final String status; // active | expired | matched | rejected

  TempChatRoomModel({
    required this.roomId,
    required this.userA,
    required this.userB,
    required this.participants,
    required this.createdAt,
    required this.expireAt,
    this.userALiked = false,
    this.userBLiked = false,
    this.status = "active",
  });

  // =========================================================
  // TO FIRESTORE
  // =========================================================
  Map<String, dynamic> toJson() => {
        "roomId": roomId,
        "userA": userA,
        "userB": userB,
        "participants": participants,
        "createdAt": Timestamp.fromDate(createdAt),
        "expireAt": Timestamp.fromDate(expireAt),
        "userALiked": userALiked,
        "userBLiked": userBLiked,
        "status": status,
      };

  // =========================================================
  // FROM FIRESTORE
  // =========================================================
  factory TempChatRoomModel.fromJson(Map<String, dynamic> json) {
    return TempChatRoomModel(
      roomId: json["roomId"],
      userA: json["userA"],
      userB: json["userB"],
      participants: List<String>.from(json["participants"] ?? []),
      createdAt: (json["createdAt"] as Timestamp).toDate(),
      expireAt: (json["expireAt"] as Timestamp).toDate(),
      userALiked: json["userALiked"] ?? false,
      userBLiked: json["userBLiked"] ?? false,
      status: json["status"] ?? "active",
    );
  }
}
