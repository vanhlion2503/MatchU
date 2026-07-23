import 'package:matchu_app/models/matching/matching_mode.dart';

/// Single source of truth for reputation requirements on matching clients.
///
/// Cloud Functions enforce the same limits authoritatively. These client-side
/// checks exist to give users immediate feedback before opening a matching
/// session.
abstract final class MatchingReputationPolicy {
  static const int minimumTempChatScore = 80;
  static const int minimumVideoScore = 90;
  static const int legacyDefaultScore = 100;

  static int minimumScoreFor(MatchingMode mode) {
    return switch (mode) {
      MatchingMode.chat => minimumTempChatScore,
      MatchingMode.video => minimumVideoScore,
    };
  }

  static int scoreFrom(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return num.tryParse(value.trim())?.toInt() ?? legacyDefaultScore;
    }
    return legacyDefaultScore;
  }

  static bool canUse(MatchingMode mode, Object? reputationScore) {
    return scoreFrom(reputationScore) >= minimumScoreFor(mode);
  }
}
