import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

class CommentTextModerationService {
  CommentTextModerationService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  static const Duration timeout = Duration(seconds: 15);

  final FirebaseFunctions _functions;

  Future<CommentTextModerationResult> moderate(String content) async {
    final normalizedContent = content.trim();
    if (normalizedContent.isEmpty) {
      return const CommentTextModerationResult.allowed();
    }

    final callable = _functions.httpsCallable('moderateCommentText');
    final result = await callable
        .call<Map<String, dynamic>>({'content': normalizedContent})
        .timeout(timeout);

    final data = Map<String, dynamic>.from(result.data);
    final reason = (data['reason'] ?? '').toString().trim();
    final severity = (data['severity'] ?? '').toString().trim();
    final penalty = (data['penalty'] as num?)?.toInt() ?? 0;
    final reputationBefore = (data['reputationBefore'] as num?)?.toInt();
    final reputationAfter = (data['reputationAfter'] as num?)?.toInt();

    return CommentTextModerationResult(
      isViolation: data['isViolation'] == true,
      reason: reason.isNotEmpty ? reason : null,
      severity: severity.isNotEmpty ? severity : null,
      penalty: penalty,
      reputationBefore: reputationBefore,
      reputationAfter: reputationAfter,
    );
  }
}

class CommentTextModerationResult {
  const CommentTextModerationResult({
    required this.isViolation,
    required this.reason,
    required this.severity,
    required this.penalty,
    required this.reputationBefore,
    required this.reputationAfter,
  });

  const CommentTextModerationResult.allowed()
    : isViolation = false,
      reason = null,
      severity = null,
      penalty = 0,
      reputationBefore = null,
      reputationAfter = null;

  final bool isViolation;
  final String? reason;
  final String? severity;
  final int penalty;
  final int? reputationBefore;
  final int? reputationAfter;
}
