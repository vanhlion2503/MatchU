import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

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

class FaceVerificationService {
  FaceVerificationService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = _normalizeBaseUrl(baseUrl ?? _defaultBaseUrl);

  static const String _cloudRunBaseUrl =
      'https://face-verification-40953934947.asia-southeast1.run.app';
  static const String _defaultBaseUrl = String.fromEnvironment(
    'FACE_VERIFY_BASE_URL',
    defaultValue: _cloudRunBaseUrl,
  );
  static const Duration _requestTimeout = Duration(seconds: 25);

  final http.Client _client;
  final String _baseUrl;

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

  Future<bool> uploadVerification({
    required File selfieFile,
    required File liveFrameFile,
  }) async {
    final result = await enrollVerification(
      selfieFile: selfieFile,
      liveFrameFile: liveFrameFile,
    );
    return result.success;
  }

  Future<FaceVerificationResult> enrollVerification({
    required File selfieFile,
    required File liveFrameFile,
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
          ..files.add(await _buildImagePart('selfie', selfieFile))
          ..files.add(await _buildImagePart('live_frame', liveFrameFile));

    return _sendMultipart(request, operation: 'enrollVerification');
  }

  Future<FaceVerificationResult> reauthenticate({
    required File liveFrameFile,
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
          ..files.add(await _buildImagePart('live_frame', liveFrameFile));

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

    try {
      final appCheckToken = await FirebaseAppCheck.instance.getToken();
      if (appCheckToken != null && appCheckToken.isNotEmpty) {
        headers['X-Firebase-AppCheck'] = appCheckToken;
      }
    } catch (e) {
      debugPrint('Firebase App Check token unavailable: $e');
    }

    return headers;
  }

  Future<http.MultipartFile> _buildImagePart(String fieldName, File file) {
    return http.MultipartFile.fromPath(
      fieldName,
      file.path,
      contentType: MediaType('image', 'jpeg'),
    );
  }

  void dispose() {
    _client.close();
  }
}
