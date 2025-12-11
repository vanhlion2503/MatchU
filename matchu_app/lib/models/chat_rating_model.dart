class ChatRatingModel {
  final String roomId;
  final String fromUid;
  final String toUid;
  final int rating; // 1–5 stars
  final DateTime createdAt;

  ChatRatingModel({
    required this.roomId,
    required this.fromUid,
    required this.toUid,
    required this.rating,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        "roomId": roomId,
        "fromUid": fromUid,
        "toUid": toUid,
        "rating": rating,
        "createdAt": createdAt.toIso8601String(),
      };

  factory ChatRatingModel.fromJson(Map<String, dynamic> json) {
    return ChatRatingModel(
      roomId: json["roomId"],
      fromUid: json["fromUid"],
      toUid: json["toUid"],
      rating: json["rating"],
      createdAt: DateTime.parse(json["createdAt"]),
    );
  }
}
