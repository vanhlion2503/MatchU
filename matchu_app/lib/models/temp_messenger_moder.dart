import 'package:cloud_firestore/cloud_firestore.dart';

class TempMessageModel {
  final String senderId;
  final String text;
  final String? replyToId;
  final String? replyText;

  TempMessageModel({
    required this.senderId,
    required this.text,
    this.replyToId,
    this.replyText,
  });

  /// 🔥 GỬI LÊN FIRESTORE
  Map<String, dynamic> toJson() => {
        "senderId": senderId,
        "text": text,
        "type": "text",
        "replyToId": replyToId,
        "replyText": replyText,
        "createdAt": FieldValue.serverTimestamp(), // ✅ CHUẨN
      };

  /// 🔥 ĐỌC TỪ FIRESTORE
  factory TempMessageModel.fromJson(Map<String, dynamic> json) {
    return TempMessageModel(
      senderId: json["senderId"],
      text: json["text"],
    );
  }
}
