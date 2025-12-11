class LongTermChatRoomModel {
  final String roomId;
  final List<String> participants;
  final DateTime createdAt;
  final String lastMessage;

  LongTermChatRoomModel({
    required this.roomId,
    required this.participants,
    required this.createdAt,
    this.lastMessage = "",
  });

  Map<String, dynamic> toJson() => {
        "roomId": roomId,
        "participants": participants,
        "createdAt": createdAt.toIso8601String(),
        "lastMessage": lastMessage,
      };

  factory LongTermChatRoomModel.fromJson(Map<String, dynamic> json) {
    return LongTermChatRoomModel(
      roomId: json["roomId"],
      participants: List<String>.from(json["participants"]),
      createdAt: DateTime.parse(json["createdAt"]),
      lastMessage: json["lastMessage"] ?? "",
    );
  }
}
