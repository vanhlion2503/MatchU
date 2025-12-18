import 'package:cloud_firestore/cloud_firestore.dart';

class TempMessageModel {
  final String senderId;
  final String text;

  TempMessageModel({
    required this.senderId,
    required this.text,
  });

  /// 🔥 GỬI LÊN FIRESTORE
  Map<String, dynamic> toJson() => {
        "senderId": senderId,
        "text": text,
        "type": "text",
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
