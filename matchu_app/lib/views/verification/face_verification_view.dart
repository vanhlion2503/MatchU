import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/verification/face_verification_controller.dart';
import 'package:matchu_app/models/verification/verification_state.dart';
import 'package:matchu_app/views/verification/screens/face_verification_camera_screen.dart';
import 'package:matchu_app/views/verification/screens/face_verification_failed_screen.dart';
import 'package:matchu_app/views/verification/screens/face_verification_intro_screen.dart';
import 'package:matchu_app/views/verification/screens/face_verification_permission_screen.dart';
import 'package:matchu_app/views/verification/screens/face_verification_processing_screen.dart';
import 'package:matchu_app/views/verification/screens/face_verification_success_screen.dart';

class FaceVerificationView extends GetView<FaceVerificationController> {
  const FaceVerificationView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isCheckingVerificationStatus.value) {
        return _buildCheckingStatusStage(context);
      }

      final currentState = controller.state.value;
      final showIntro =
          !controller.hasStartedVerificationFlow.value &&
          (currentState == VerificationState.idle ||
              currentState == VerificationState.capturingSelfie);

      if (showIntro) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            bottom: false,
            child: FaceVerificationIntroScreen(
              onBack: Get.back,
              onStart: controller.startVerificationFlow,
            ),
          ),
        );
      }

      return Scaffold(
        backgroundColor:
            _isDarkStage(currentState)
                ? Colors.black
                : Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          bottom: false,
          child: switch (currentState) {
            VerificationState.idle ||
            VerificationState.capturingSelfie => _buildSelfieCaptureStage(),
            VerificationState.liveness => _buildLivenessStage(),
            VerificationState.processing =>
              const FaceVerificationProcessingScreen(),
            VerificationState.success => _buildSuccessStage(),
            VerificationState.failed => _buildFailedStage(),
          },
        ),
      );
    });
  }

  Widget _buildCheckingStatusStage(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: const Center(child: CircularProgressIndicator()),
    );
  }

  bool _isDarkStage(VerificationState state) {
    return state == VerificationState.capturingSelfie ||
        state == VerificationState.liveness ||
        state == VerificationState.processing ||
        state == VerificationState.idle;
  }

  Widget _buildSelfieCaptureStage() {
    if (!controller.hasCameraPermission.value &&
        controller.errorText.value.isNotEmpty) {
      return FaceVerificationPermissionScreen(
        message: controller.errorText.value,
        onClose: Get.back,
        onOpenSettings: controller.openPermissionSettings,
      );
    }

    return FaceVerificationCameraScreen(
      isLiveness: false,
      cameraController: controller.cameraController,
      isCameraReady: controller.isCameraReady.value,
      isCaptureLocked: controller.isCaptureLocked.value,
      livenessStepLabels: controller.livenessStepLabels,
      livenessStepDone: controller.livenessStepDone.toList(),
      currentLivenessStep: controller.currentLivenessStep.value,
      instructionText: controller.instructionText.value,
      onClose: Get.back,
      onFlashTap: () {},
      onCaptureSelfie: controller.captureSelfie,
    );
  }

  Widget _buildLivenessStage() {
    if (!controller.hasCameraPermission.value &&
        controller.errorText.value.isNotEmpty) {
      return FaceVerificationPermissionScreen(
        message: controller.errorText.value,
        onClose: Get.back,
        onOpenSettings: controller.openPermissionSettings,
      );
    }

    return FaceVerificationCameraScreen(
      isLiveness: true,
      cameraController: controller.cameraController,
      isCameraReady: controller.isCameraReady.value,
      isCaptureLocked: controller.isCaptureLocked.value,
      livenessStepLabels: controller.livenessStepLabels,
      livenessStepDone: controller.livenessStepDone.toList(),
      currentLivenessStep: controller.currentLivenessStep.value,
      instructionText: controller.instructionText.value,
      onClose: Get.back,
      onFlashTap: () {},
      onCaptureSelfie: controller.captureSelfie,
    );
  }

  Widget _buildSuccessStage() {
    return FaceVerificationSuccessScreen(
      wasAlreadyVerifiedAtEntry: controller.wasAlreadyVerifiedAtEntry.value,
      onContinue: Get.back,
      onRetry: () {
        controller.hasStartedVerificationFlow.value = true;
        controller.retryVerification();
      },
    );
  }

  Widget _buildFailedStage() {
    return FaceVerificationFailedScreen(
      errorText: controller.errorText.value,
      hasCameraPermission: controller.hasCameraPermission.value,
      onBack: Get.back,
      onRetry: () {
        controller.hasStartedVerificationFlow.value = true;
        controller.retryVerification();
      },
      onRetryLater: Get.back,
      onOpenPermissionSettings: controller.openPermissionSettings,
    );
  }
}
