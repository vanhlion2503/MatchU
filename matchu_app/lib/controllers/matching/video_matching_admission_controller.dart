import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:matchu_app/models/matching/video_matching_access_proof.dart';
import 'package:matchu_app/repositories/matching/video_matching_admission_repository.dart';
import 'package:matchu_app/routes/app_router.dart';

class VideoMatchingAdmissionController extends GetxController
    with WidgetsBindingObserver {
  VideoMatchingAdmissionController({
    required VideoMatchingAdmissionRepository repository,
  }) : _repository = repository;

  static const Duration _backgroundProofTimeout = Duration(minutes: 2);

  final VideoMatchingAdmissionRepository _repository;
  VideoMatchingAccessProof? _proof;
  DateTime? _pausedAt;
  bool _requestInProgress = false;

  VideoMatchingAccessProof? get currentProof {
    final proof = _proof;
    if (proof == null || !proof.isUsableAt(DateTime.now().toUtc())) {
      _proof = null;
      return null;
    }
    return proof;
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  /// Returns a fresh, device-bound proof. Unverified accounts are routed
  /// through enrollment first; verified accounts use the shorter reauth flow.
  Future<VideoMatchingAccessProof?> ensureProof() async {
    final existing = currentProof;
    if (existing != null) return existing;
    if (_requestInProgress) return null;

    _requestInProgress = true;
    try {
      final isEnrolled = await _repository.isFaceEnrolled();
      final deviceId = await _repository.getDeviceId();
      final result = await Get.toNamed<dynamic>(
        AppRouter.faceVerification,
        arguments: {
          'mode': isEnrolled ? 'reauth' : 'enroll',
          'purpose': 'video_matching',
        },
      );
      if (result is! Map) return null;

      final proof = VideoMatchingAccessProof.fromRouteResult(
        result: result,
        deviceId: deviceId,
      );
      _proof = proof;
      return proof;
    } on FormatException {
      return null;
    } finally {
      _requestInProgress = false;
    }
  }

  void clearProof() {
    _proof = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _pausedAt = DateTime.now().toUtc();
        break;
      case AppLifecycleState.resumed:
        final pausedAt = _pausedAt;
        _pausedAt = null;
        if (pausedAt != null &&
            DateTime.now().toUtc().difference(pausedAt) >
                _backgroundProofTimeout) {
          final staleProof = _proof;
          clearProof();
          if (staleProof != null) {
            unawaited(
              _repository
                  .revokeProof(
                    proofId: staleProof.id,
                    deviceId: staleProof.deviceId,
                  )
                  .catchError((Object _) {
                    // The proof still has a short absolute TTL on the server.
                  }),
            );
          }
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }
}
