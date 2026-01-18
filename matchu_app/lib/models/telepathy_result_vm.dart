import 'telepathy_result.dart';

class TelepathyResultVM {
  final TelepathyResult baseResult;

  /// AI insight (optional)
  final String? aiText;
  final String? aiTone;
  final bool aiLoading;
  final bool aiError;

  TelepathyResultVM({
    required this.baseResult,
    this.aiText,
    this.aiTone,
    this.aiLoading = false,
    this.aiError = false,
  });

  TelepathyLevel get level => baseResult.level;
  int get score => baseResult.score;
  String get summaryText => baseResult.summaryText;
}
