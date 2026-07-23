import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:matchu_app/repositories/verification/face_verification_repository.dart';
import 'package:matchu_app/services/security/device_service.dart';

export 'package:matchu_app/repositories/verification/face_verification_repository.dart';

class FaceVerificationService implements FaceVerificationRepository {
  FaceVerificationService({
    http.Client? client,
    String? baseUrl,
    FirebaseFunctions? functions,
  }) : _client = client ?? http.Client(),
       _baseUrl = _normalizeBaseUrl(baseUrl ?? _defaultBaseUrl),
       _functions = functions ?? FirebaseFunctions.instance;

  static const String _cloudRunBaseUrl =
      'https://face-verification-40953934947.asia-southeast1.run.app';
  static const String _defaultBaseUrl = String.fromEnvironment(
    'FACE_VERIFY_BASE_URL',
    defaultValue: _cloudRunBaseUrl,
  );
  static const Duration _requestTimeout = Duration(seconds: 25);

  final http.Client _client;
  final String _baseUrl;
  final FirebaseFunctions _functions;

  static String _normalizeBaseUrl(String baseUrl) {
    final raw = baseUrl.trim();
    if (raw.isNotEmpty) {
      return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
    }

    // Safety fallback if an empty value is passed explicitly.
    if (kIsWeb) return _cloudRunBaseUrl;
    if (Platform.isAndroid) return _cloudRunBaseUrl;
    return _cloudRunBaseUrl;
  }

  Uri _enrollUri() => Uri.parse('$_baseUrl/v1/face/enroll');
  Uri _reauthUri() => Uri.parse('$_baseUrl/v1/face/reauth');
  Uri _challengeUri() => Uri.parse('$_baseUrl/v1/face/challenge');

  @override
  Future<FaceLivenessChallenge?> createLivenessChallenge({
    required String purpose,
  }) async {
    final headers = await _buildAuthenticatedHeaders();
    if (headers == null) return null;
    try {
      final response = await _client
          .post(
            _challengeUri(),
            headers: headers,
            body: {
              'purpose': purpose,
              'device_id': await DeviceService.getDeviceId(),
              // v2 adds the blink action. Older app versions omit this field
              // and continue receiving the legacy three-step challenge.
              'liveness_version': '2',
            },
          )
          .timeout(_requestTimeout);
      if (response.statusCode != 200) {
        debugPrint(
          'createLivenessChallenge failed: status=${response.statusCode}',
        );
        return null;
      }
      final payload = jsonDecode(utf8.decode(response.bodyBytes));
      if (payload is! Map) return null;
      final actions =
          (payload['actions'] as List?)
              ?.map((value) => value.toString())
              .toList(growable: false) ??
          const <String>[];
      final challenge = FaceLivenessChallenge(
        id: payload['challengeId']?.toString() ?? '',
        actions: actions,
        expiresAt:
            DateTime.tryParse(
              payload['expiresAt']?.toString() ?? '',
            )?.toUtc() ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
      return challenge.isValid ? challenge : null;
    } catch (error) {
      debugPrint('createLivenessChallenge error: $error');
      return null;
    }
  }

  @override
  Future<FaceTemplateUpdateAuthorization> authorizeTemplateUpdateWithPin({
    required String passcode,
  }) async {
    final deviceId = await DeviceService.getDeviceId();
    final callable = _functions.httpsCallable(
      'authorizeFaceTemplateUpdateWithPin',
    );
    final response = await callable.call(<String, dynamic>{
      'passcode': passcode.trim(),
      'deviceId': deviceId,
    });
    final data = response.data;
    if (data is! Map) {
      throw const FormatException('Invalid update authorization response.');
    }
    final authorization = FaceTemplateUpdateAuthorization(
      id: data['authorizationId']?.toString() ?? '',
      expiresAt:
          DateTime.tryParse(data['expiresAt']?.toString() ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
    if (!authorization.isValid) {
      throw const FormatException('Invalid update authorization response.');
    }
    return authorization;
  }

  Future<bool> uploadVerification({
    required File selfieFile,
    required File liveFrameFile,
    required FaceLivenessChallenge challenge,
    required List<File> evidenceFrames,
  }) async {
    final result = await enrollVerification(
      selfieFile: selfieFile,
      liveFrameFile: liveFrameFile,
      challenge: challenge,
      evidenceFrames: evidenceFrames,
    );
    return result.success;
  }

  @override
  Future<FaceVerificationResult> enrollVerification({
    required File selfieFile,
    required File liveFrameFile,
    required FaceLivenessChallenge challenge,
    required List<File> evidenceFrames,
    String purpose = 'face_reauth',
    String? templateUpdateAuthorizationId,
  }) async {
    if (!await selfieFile.exists() || !await liveFrameFile.exists()) {
      debugPrint('uploadVerification: selfie/live frame file does not exist.');
      return FaceVerificationResult.failed;
    }

    final headers = await _buildAuthenticatedHeaders();
    if (headers == null) {
      return FaceVerificationResult.failed;
    }

    final request =
        http.MultipartRequest('POST', _enrollUri())
          ..headers.addAll(headers)
          ..fields['purpose'] = purpose
          ..fields['device_id'] = await DeviceService.getDeviceId()
          ..fields['challenge_id'] = challenge.id
          ..fields['challenge_response'] = jsonEncode(challenge.actions)
          ..files.add(await _buildImagePart('selfie', selfieFile))
          ..files.add(await _buildImagePart('live_frame', liveFrameFile));
    final updateAuthorization = templateUpdateAuthorizationId?.trim() ?? '';
    if (updateAuthorization.isNotEmpty) {
      request.fields['template_update_authorization'] = updateAuthorization;
    }
    await _addEvidenceParts(request, evidenceFrames);

    return _sendMultipart(request, operation: 'enrollVerification');
  }

  @override
  Future<FaceVerificationResult> reauthenticate({
    required File liveFrameFile,
    required FaceLivenessChallenge challenge,
    required List<File> evidenceFrames,
    String purpose = 'face_reauth',
  }) async {
    if (!await liveFrameFile.exists()) {
      debugPrint('reauthenticate: live frame file does not exist.');
      return FaceVerificationResult.failed;
    }

    final headers = await _buildAuthenticatedHeaders();
    if (headers == null) {
      return FaceVerificationResult.failed;
    }

    final request =
        http.MultipartRequest('POST', _reauthUri())
          ..headers.addAll(headers)
          ..fields['purpose'] = purpose
          ..fields['device_id'] = await DeviceService.getDeviceId()
          ..fields['challenge_id'] = challenge.id
          ..fields['challenge_response'] = jsonEncode(challenge.actions)
          ..files.add(await _buildImagePart('live_frame', liveFrameFile));
    await _addEvidenceParts(request, evidenceFrames);

    return _sendMultipart(request, operation: 'reauthenticate');
  }

  Future<FaceVerificationResult> _sendMultipart(
    http.MultipartRequest request, {
    required String operation,
  }) async {
    try {
      final streamedResponse = await _client
          .send(request)
          .timeout(_requestTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      Map<String, dynamic>? payload;
      if (response.bodyBytes.isNotEmpty) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          payload = decoded;
        }
      }

      final result = FaceVerificationResult.fromPayload(payload);
      if (response.statusCode == 200 && result.success) {
        return result;
      }

      final reason = result.reason;
      final detail = payload?['detail']?.toString();
      debugPrint(
        '$operation failed: status=${response.statusCode}, reason=$reason, detail=$detail',
      );
      return result;
    } on TimeoutException {
      debugPrint('$operation timeout after ${_requestTimeout.inSeconds}s');
      return FaceVerificationResult.failed;
    } on SocketException catch (e) {
      debugPrint('$operation network error: $e');
      return FaceVerificationResult.failed;
    } on FormatException catch (e) {
      debugPrint('$operation invalid response JSON: $e');
      return FaceVerificationResult.failed;
    } catch (e) {
      debugPrint('$operation unexpected error: $e');
      return FaceVerificationResult.failed;
    }
  }

  Future<Map<String, String>?> _buildAuthenticatedHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    final idToken = await user?.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      debugPrint('Face verification requires an authenticated Firebase user.');
      return null;
    }

    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $idToken',
    };

    return headers;
  }

  Future<http.MultipartFile> _buildImagePart(String fieldName, File file) {
    return http.MultipartFile.fromPath(
      fieldName,
      file.path,
      contentType: MediaType('image', 'jpeg'),
    );
  }

  Future<void> _addEvidenceParts(
    http.MultipartRequest request,
    List<File> evidenceFrames,
  ) async {
    for (final frame in evidenceFrames) {
      request.files.add(await _buildImagePart('evidence_frames', frame));
    }
  }

  @override
  void dispose() {
    _client.close();
  }
}
