import 'dart:io';

class FaceVerificationResult {
  const FaceVerificationResult({
    required this.success,
    this.reason,
    this.similarity,
    this.threshold,
    this.sessionId,
    this.expiresAt,
  });

  final bool success;
  final String? reason;
  final double? similarity;
  final double? threshold;
  final String? sessionId;
  final DateTime? expiresAt;

  factory FaceVerificationResult.fromPayload(Map<String, dynamic>? payload) {
    DateTime? parseDate(dynamic value) {
      if (value is String && value.trim().isNotEmpty) {
        return DateTime.tryParse(value.trim());
      }
      return null;
    }

    double? parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    return FaceVerificationResult(
      success: payload?['success'] == true,
      reason: payload?['reason']?.toString(),
      similarity: parseDouble(payload?['similarity']),
      threshold: parseDouble(payload?['threshold']),
      sessionId: payload?['sessionId']?.toString(),
      expiresAt: parseDate(payload?['expiresAt']),
    );
  }

  static const failed = FaceVerificationResult(success: false);
}

class FaceLivenessChallenge {
  const FaceLivenessChallenge({
    required this.id,
    required this.actions,
    required this.expiresAt,
  });

  final String id;
  final List<String> actions;
  final DateTime expiresAt;

  bool get isValid =>
      id.isNotEmpty &&
      actions.length == 3 &&
      expiresAt.isAfter(DateTime.now().toUtc());
}

class FaceTemplateUpdateAuthorization {
  const FaceTemplateUpdateAuthorization({
    required this.id,
    required this.expiresAt,
  });

  final String id;
  final DateTime expiresAt;

  bool get isValid =>
      id.isNotEmpty && expiresAt.isAfter(DateTime.now().toUtc());
}

abstract class FaceVerificationRepository {
  Future<FaceLivenessChallenge?> createLivenessChallenge({
    required String purpose,
  });

  Future<FaceTemplateUpdateAuthorization> authorizeTemplateUpdateWithPin({
    required String passcode,
  });

  Future<FaceVerificationResult> enrollVerification({
    required File selfieFile,
    required File liveFrameFile,
    required FaceLivenessChallenge challenge,
    required List<File> evidenceFrames,
    String purpose = 'face_reauth',
    String? templateUpdateAuthorizationId,
  });

  Future<FaceVerificationResult> reauthenticate({
    required File liveFrameFile,
    required FaceLivenessChallenge challenge,
    required List<File> evidenceFrames,
    String purpose = 'face_reauth',
  });

  void dispose();
}
