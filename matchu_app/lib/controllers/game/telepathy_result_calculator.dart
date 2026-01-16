import 'package:matchu_app/models/telepathy_question.dart';
import 'package:matchu_app/models/telepathy_result.dart';

class TelepathyResultCalculator {
  static TelepathyResult calculate({
    required List<TelepathyQuestion> questions,
    required Map<String, String> myAnswers,
    required Map<String, String> otherAnswers,
  }) {
    int matched = 0;
    final List<Map<String, dynamic>> same = [];
    final List<Map<String, dynamic>> diff = [];

    for (final q in questions) {
      final my = myAnswers[q.id];
      final other = otherAnswers[q.id];

      if (my == null || other == null) continue;

      if (my == other) {
        matched++;
        same.add({"question": q.text, "answer": my});
      } else {
        diff.add({
          "question": q.text,
          "me": my,
          "other": other,
        });
      }
    }

    final total = questions.length;
    final score = total == 0 ? 0 : ((matched / total) * 100).round();
    final level = _level(score);

    return TelepathyResult(
      score: score,
      matchedCount: matched,
      total: total,
      level: level,
      summaryText: _summary(score, level, same, diff),
      highlight: {"same": same, "diff": diff},
    );
  }

  static TelepathyLevel _level(int score) {
    if (score >= 80) return TelepathyLevel.high;
    if (score >= 40) return TelepathyLevel.medium;
    return TelepathyLevel.low;
  }

  static String _summary(
    int score,
    TelepathyLevel level,
    List same,
    List diff,
  ) {
    switch (level) {
      case TelepathyLevel.high:
        return "Wow! $score% tương đồng! Hai bạn hợp cạ quá trời 😳";
      case TelepathyLevel.medium:
        return "Hợp nhau $score%. Khá ổn đấy chứ! 🤝";
      case TelepathyLevel.low:
        return "Chỉ $score% thôi 😅 Trái dấu đôi khi lại hút nhau mạnh!";
    }

  }
}
