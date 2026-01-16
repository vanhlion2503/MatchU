enum TelepathyLevel {
  high,
  medium,
  low,
}

class TelepathyResult {
  final int score; // %
  final int matchedCount;
  final int total;
  final TelepathyLevel level;
  final String summaryText;
  final Map<String, dynamic> highlight; // chi tiết để UI dùng

  TelepathyResult({
    required this.score,
    required this.matchedCount,
    required this.total,
    required this.level,
    required this.summaryText,
    required this.highlight,
  });

  Map<String, dynamic> toJson() => {
        "score": score,
        "matchedCount": matchedCount,
        "total": total,
        "level": level.name,
        "summaryText": summaryText,
        "highlight": highlight,
      };

  factory TelepathyResult.fromJson(Map<String, dynamic> json) {
    final levelName = json["level"];
    final level = TelepathyLevel.values.firstWhere(
      (e) => e.name == levelName,
      orElse: () => TelepathyLevel.low,
    );

    return TelepathyResult(
      score: (json["score"] ?? 0) as int,
      matchedCount: (json["matchedCount"] ?? 0) as int,
      total: (json["total"] ?? 0) as int,
      level: level,
      summaryText: json["summaryText"] ?? "",
      highlight: Map<String, dynamic>.from(json["highlight"] ?? {}),
    );
  }
}
