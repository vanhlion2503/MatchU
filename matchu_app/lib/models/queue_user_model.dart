import 'package:matchu_app/models/matching/matching_mode.dart';

class QueueUserModel {
  final String uid;
  final String gender;
  final String targetGender;
  final String sessionId;
  final MatchingMode matchingMode;

  final double avgChatRating;
  final List<String> interests;
  final DateTime createdAt;

  QueueUserModel({
    required this.uid,
    required this.gender,
    required this.targetGender,
    required this.sessionId,
    this.matchingMode = MatchingMode.chat,
    required this.avgChatRating,
    this.interests = const [],
    required this.createdAt,
  });

  // ================= TO JSON =================
  Map<String, dynamic> toJson() {
    return {
      "uid": uid,
      "gender": gender,
      "targetGender": targetGender,
      "sessionId": sessionId,
      "matchingMode": matchingMode.value,
      "avgChatRating": avgChatRating,
      "interests": interests,
      "createdAt": createdAt.toIso8601String(),
    };
  }

  // ================= FROM JSON =================
  factory QueueUserModel.fromJson(Map<String, dynamic> json) {
    return QueueUserModel(
      uid: json["uid"] as String,
      gender: json["gender"] as String,
      targetGender: json["targetGender"] ?? "random",
      sessionId: json["sessionId"] as String, // 🔥 FIX
      matchingMode: MatchingMode.fromValue(json["matchingMode"]),
      avgChatRating: (json["avgChatRating"] ?? 5).toDouble(), // 🔥 FIX
      interests: List<String>.from(json["interests"] ?? []),
      createdAt: DateTime.parse(json["createdAt"]),
    );
  }
}
