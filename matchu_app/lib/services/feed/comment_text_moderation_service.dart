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

    return CommentTextModerationResult(
      isViolation: data['isViolation'] == true,
      reason: reason.isNotEmpty ? reason : null,
      severity: severity.isNotEmpty ? severity : null,
    );
  }
}

class CommentTextModerationResult {
  const CommentTextModerationResult({
    required this.isViolation,
    required this.reason,
    required this.severity,
  });

  const CommentTextModerationResult.allowed()
    : isViolation = false,
      reason = null,
      severity = null;

  final bool isViolation;
  final String? reason;
  final String? severity;
}
