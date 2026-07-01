import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

class PostTextModerationService {
  PostTextModerationService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  static const Duration timeout = Duration(seconds: 6);

  final FirebaseFunctions _functions;

  Future<PostTextModerationResult> moderate(String content) async {
    final normalizedContent = content.trim();
    if (normalizedContent.isEmpty) {
      return const PostTextModerationResult.allowed();
    }

    final callable = _functions.httpsCallable('moderatePostText');
    final result = await callable
        .call<Map<String, dynamic>>({'content': normalizedContent})
        .timeout(timeout);

    final data = Map<String, dynamic>.from(result.data);
    final isViolation = data['isViolation'] == true;
    final reason = (data['reason'] ?? '').toString().trim();

    return PostTextModerationResult(
      isViolation: isViolation,
      reason: reason.isNotEmpty ? reason : null,
    );
  }
}

class PostTextModerationResult {
  const PostTextModerationResult({
    required this.isViolation,
    required this.reason,
  });

  const PostTextModerationResult.allowed() : isViolation = false, reason = null;

  final bool isViolation;
  final String? reason;
}
