import 'package:cloud_firestore/cloud_firestore.dart';

class TempMessageModel {
  final String senderId;
  final String text;
  final String type; // 👈 text | emoji
  final String? replyToId;
  final String? replyText;

  TempMessageModel({
    required this.senderId,
    required this.text,
    this.type = "text", // 👈 mặc định
    this.replyToId,
    this.replyText,
  });

  /// 🔥 GỬI LÊN FIRESTORE
  Map<String, dynamic> toJson() => {
        "senderId": senderId,
        "text": text,
        "type": type, // 👈 QUAN TRỌNG
        "replyToId": replyToId,
        "replyText": replyText,
        "createdAt": FieldValue.serverTimestamp(),
      };

  /// 🔥 ĐỌC TỪ FIRESTORE
  factory TempMessageModel.fromJson(Map<String, dynamic> json) {
    return TempMessageModel(
      senderId: json["senderId"],
      text: json["text"] ?? "",
      type: json["type"] ?? "text", // 👈 fallback
      replyToId: json["replyToId"],
      replyText: json["replyText"],
    );
  }
}
