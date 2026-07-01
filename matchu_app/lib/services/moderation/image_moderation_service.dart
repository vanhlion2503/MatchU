import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';

class ImageModerationService {
  ImageModerationService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  static const Duration timeout = Duration(seconds: 18);

  final FirebaseFunctions _functions;

  Future<ImageModerationResult> moderate(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    if (bytes.isEmpty) {
      throw StateError('Hinh anh khong hop le.');
    }

    final callable = _functions.httpsCallable('moderateImageContent');
    final result = await callable
        .call<Map<String, dynamic>>({'base64Image': base64Encode(bytes)})
        .timeout(timeout);

    final data = Map<String, dynamic>.from(result.data);
    final isViolation = data['isViolation'] == true;
    final reason = (data['reason'] ?? '').toString().trim();

    return ImageModerationResult(
      isViolation: isViolation,
      reason: reason.isNotEmpty ? reason : null,
    );
  }
}

class ImageModerationResult {
  const ImageModerationResult({
    required this.isViolation,
    required this.reason,
  });

  final bool isViolation;
  final String? reason;
}
