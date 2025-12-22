class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final String type;  // text | image | system
  final DateTime createdAt;
  

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    this.type = "text",
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        "id": id,
        "senderId": senderId,
        "text": text,
        "type": type,
        "createdAt": createdAt.toIso8601String(),
      };

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json["id"],
      senderId: json["senderId"],
      text: json["text"],
      type: json["type"],
      createdAt: DateTime.parse(json["createdAt"]),
    );
  }
}
