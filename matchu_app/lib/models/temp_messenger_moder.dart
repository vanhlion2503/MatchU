import "package:cloud_firestore/cloud_firestore.dart";

class TempMessageModel {
  final String senderId;
  final String text;
  final String type; // text | emoji
  final String? replyToId;
  final String? replyText;
  final String status;

  TempMessageModel({
    required this.senderId,
    required this.text,
    this.type = "text",
    this.replyToId,
    this.replyText,
    this.status = "pending",
  });

  // Create payload for temp chat user message.
  Map<String, dynamic> toJson() => {
    "senderId": senderId,
    "text": text,
    "type": type,
    "replyToId": replyToId,
    "replyText": replyText,
    "status": status,
    "blockedBy": null,
    "reason": null,
    "warning": false,
    "aiScore": null,
    "createdAt": FieldValue.serverTimestamp(),
  };

  factory TempMessageModel.fromJson(Map<String, dynamic> json) {
    return TempMessageModel(
      senderId: json["senderId"],
      text: json["text"] ?? "",
      type: json["type"] ?? "text",
      replyToId: json["replyToId"],
      replyText: json["replyText"],
      status: json["status"] ?? "pending",
    );
  }
}
