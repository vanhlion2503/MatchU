class QueueUserModel {
  final String uid;
  final String gender;
  final String targetGender;
  
  final double avgChatRating;
  final List<String> interests;
  final DateTime createdAt;  

  QueueUserModel({
    required this.uid,
    required this.gender,
    required this.targetGender,
    required this.avgChatRating,
    this.interests = const [],
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      "uid": uid,
      "gender": gender,
      "targetGender": targetGender,
      "avgChatRating": avgChatRating,
      "interests": interests,
      "createdAt": createdAt.toIso8601String(),
    };
  }

  factory QueueUserModel.fromJson(Map<String, dynamic> json) {
    return QueueUserModel(
      uid: json["uid"],
      gender: json["gender"],
      targetGender: json["targetGender"] ?? "random",
      avgChatRating:
          (json["avgChatRating"] ?? 5.0 * 1.0), // default 5 sao
      interests: List<String>.from(json["interests"] ?? []),
      createdAt: DateTime.parse(json["createdAt"]),
    );
  }
}
