// FILE: lib/models/telepathy_question.dart

enum QuestionCategory {
  fun,       // Vui vẻ, khởi động
  lifestyle, // Lối sống, thói quen
  love,      // Quan điểm tình yêu
  deep,      // Sâu sắc, giá trị sống
}

class TelepathyQuestion {
  final String id;
  final String text;
  final String left;
  final String right;
  final QuestionCategory category; // <--- MỚI THÊM

  TelepathyQuestion({
    required this.id,
    required this.text,
    required this.left,
    required this.right,
    this.category = QuestionCategory.fun, // Mặc định là Fun
  });

  Map<String, dynamic> toJson() => {
    "id": id,
    "text": text,
    "options": [left, right],
    "category": category.name, // <--- Lưu tên category dạng string
  };

  factory TelepathyQuestion.fromJson(Map<String, dynamic> json) {
    // Parse chuỗi category từ server, nếu lỗi thì fallback về .fun
    final catName = json["category"] as String?;
    final category = QuestionCategory.values.firstWhere(
      (e) => e.name == catName,
      orElse: () => QuestionCategory.fun,
    );

    return TelepathyQuestion(
      id: json["id"],
      text: json["text"],
      left: json["options"][0],
      right: json["options"][1],
      category: category,
    );
  }
}