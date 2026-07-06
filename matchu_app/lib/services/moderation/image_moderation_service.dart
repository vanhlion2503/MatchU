import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';

class ImageModerationService {
  ImageModerationService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  static const Duration timeout = Duration(seconds: 25);

  final FirebaseFunctions _functions;

  Future<ImageModerationResult> moderate(
    File imageFile, {
    String? context,
  }) async {
    final bytes = await imageFile.readAsBytes();
    if (bytes.isEmpty) {
      throw StateError('Hình ảnh không hợp lệ.');
    }

    final normalizedContext = context?.trim();
    final callable = _functions.httpsCallable('moderateImageContent');
    final result = await callable
        .call<Map<String, dynamic>>({
          'base64Image': base64Encode(bytes),
          if (normalizedContext != null && normalizedContext.isNotEmpty)
            'context': normalizedContext,
        })
        .timeout(timeout);

    final data = Map<String, dynamic>.from(result.data);
    final isViolation = data['isViolation'] == true;
    final reason = (data['reason'] ?? '').toString().trim();
    final severity = (data['severity'] ?? '').toString().trim();
    final penalty = (data['penalty'] as num?)?.toInt() ?? 0;
    final reputationBefore = (data['reputationBefore'] as num?)?.toInt();
    final reputationAfter = (data['reputationAfter'] as num?)?.toInt();

    return ImageModerationResult(
      isViolation: isViolation,
      reason: reason.isNotEmpty ? reason : null,
      severity: severity.isNotEmpty ? severity : null,
      penalty: penalty,
      reputationBefore: reputationBefore,
      reputationAfter: reputationAfter,
    );
  }
}

class ImageModerationResult {
  const ImageModerationResult({
    required this.isViolation,
    required this.reason,
    required this.severity,
    required this.penalty,
    required this.reputationBefore,
    required this.reputationAfter,
  });

  final bool isViolation;
  final String? reason;
  final String? severity;
  final int penalty;
  final int? reputationBefore;
  final int? reputationAfter;
}
