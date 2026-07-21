import "package:cloud_firestore/cloud_firestore.dart";
import 'package:uuid/uuid.dart';

class TempMessageModel {
  final String id;
  final String senderId;
  final String text;
  final String type; // text | emoji
  final String? replyToId;
  final String? replyText;
  final String status;

  TempMessageModel({
    String? id,
    required this.senderId,
    required this.text,
    this.type = "text",
    this.replyToId,
    this.replyText,
    this.status = "pending",
  }) : id = id ?? const Uuid().v4();

  // Create payload for temp chat user message.
  Map<String, dynamic> toJson() => {
    "clientMessageId": id,
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
    "clientCreatedAt": Timestamp.now(),
    "createdAt": FieldValue.serverTimestamp(),
  };

  factory TempMessageModel.fromJson(Map<String, dynamic> json) {
    return TempMessageModel(
      id: json["clientMessageId"]?.toString(),
      senderId: json["senderId"]?.toString() ?? "",
      text: json["text"] ?? "",
      type: json["type"] ?? "text",
      replyToId: json["replyToId"],
      replyText: json["replyText"],
      status: json["status"] ?? "pending",
    );
  }
}
