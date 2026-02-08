import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

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

  Uri _verifyUri() => Uri.parse('$_baseUrl/v1/face/verify');

  Future<bool> uploadVerification({
    required File selfieFile,
    required File liveFrameFile,
  }) async {
    if (!await selfieFile.exists() || !await liveFrameFile.exists()) {
      debugPrint('uploadVerification: selfie/live frame file does not exist.');
      return false;
    }

    final selfiePart = await http.MultipartFile.fromPath(
      'selfie',
      selfieFile.path,
      contentType: MediaType('image', 'jpeg'),
    );
    final liveFramePart = await http.MultipartFile.fromPath(
      'live_frame',
      liveFrameFile.path,
      contentType: MediaType('image', 'jpeg'),
    );

    final request =
        http.MultipartRequest('POST', _verifyUri())
          ..headers['Accept'] = 'application/json'
          ..files.add(selfiePart)
          ..files.add(liveFramePart);

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

      final success = payload?['success'] == true;
      if (response.statusCode == 200 && success) {
        return true;
      }

      final reason = payload?['reason']?.toString();
      final detail = payload?['detail']?.toString();
      debugPrint(
        'uploadVerification failed: status=${response.statusCode}, reason=$reason, detail=$detail',
      );
      return false;
    } on TimeoutException {
      debugPrint(
        'uploadVerification timeout after ${_requestTimeout.inSeconds}s',
      );
      return false;
    } on SocketException catch (e) {
      debugPrint('uploadVerification network error: $e');
      return false;
    } on FormatException catch (e) {
      debugPrint('uploadVerification invalid response JSON: $e');
      return false;
    } catch (e) {
      debugPrint('uploadVerification unexpected error: $e');
      return false;
    }
  }

  void dispose() {
    _client.close();
  }
}
