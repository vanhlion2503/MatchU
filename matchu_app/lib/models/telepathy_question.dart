class TelepathyQuestion {
  final String id;
  final String text;
  final String left;
  final String right;

  TelepathyQuestion({
    required this.id,
    required this.text,
    required this.left,
    required this.right,
  });

  Map<String, dynamic> toJson() => {
    "id": id,
    "text": text,
    "options": [left, right],
  };

  factory TelepathyQuestion.fromJson(Map<String, dynamic> json) {
    return TelepathyQuestion(
      id: json["id"],
      text: json["text"],
      left: json["options"][0],
      right: json["options"][1],
    );
  }
}
