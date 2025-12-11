class TempChatRoomModel {
  final String roomId;
  final String userA;
  final String userB;
  final DateTime createdAt;
  final DateTime expireAt;

  final bool userALiked;
  final bool userBLiked;

  final String status; // active | expired | matched | rejected

  TempChatRoomModel({
    required this.roomId,
    required this.userA,
    required this.userB,
    required this.createdAt,
    required this.expireAt,
    this.userALiked = false,
    this.userBLiked = false,
    this.status = "active",
  });

  Map<String, dynamic> toJson() => {
        "roomId": roomId,
        "userA": userA,
        "userB": userB,
        "createdAt": createdAt.toIso8601String(),
        "expireAt": expireAt.toIso8601String(),
        "userALiked": userALiked,
        "userBLiked": userBLiked,
        "status": status,
      };

  factory TempChatRoomModel.fromJson(Map<String, dynamic> json) {
    return TempChatRoomModel(
      roomId: json["roomId"],
      userA: json["userA"],
      userB: json["userB"],
      createdAt: DateTime.parse(json["createdAt"]),
      expireAt: DateTime.parse(json["expireAt"]),
      userALiked: json["userALiked"] ?? false,
      userBLiked: json["userBLiked"] ?? false,
      status: json["status"] ?? "active",
    );
  }
}
