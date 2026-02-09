import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/verification/widgets/verification_camera_overlay.dart';
import 'package:matchu_app/views/verification/widgets/verification_common_widgets.dart';

class FaceVerificationCameraScreen extends StatelessWidget {
  const FaceVerificationCameraScreen({
    super.key,
    required this.isLiveness,
    required this.cameraController,
    required this.isCameraReady,
    required this.isCaptureLocked,
    required this.livenessStepLabels,
    required this.livenessStepDone,
    required this.currentLivenessStep,
    required this.instructionText,
    required this.onClose,
    required this.onFlashTap,
    required this.onCaptureSelfie,
  });

  final bool isLiveness;
  final CameraController? cameraController;
  final bool isCameraReady;
  final bool isCaptureLocked;
  final List<String> livenessStepLabels;
  final List<bool> livenessStepDone;
  final int currentLivenessStep;
  final String instructionText;
  final VoidCallback onClose;
  final VoidCallback onFlashTap;
  final VoidCallback onCaptureSelfie;

  @override
  Widget build(BuildContext context) {
    final title = isLiveness ? 'Kiểm tra sống' : 'Ảnh chân dung';
    final subtitle =
        isLiveness
            ? 'Nhìn thẳng, chớp mắt, quay trái, quay phải'
            : 'Đặt khuôn mặt vào khung và nhìn thẳng';

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildCameraFeed(),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.22),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.32),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: FaceVerificationMaskOverlay(
              isLiveness: isLiveness,
              maskColor: Colors.black.withValues(
                alpha: isLiveness ? 0.5 : 0.58,
              ),
              borderColor: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ),
        if (isLiveness)
          Positioned.fill(
            child: IgnorePointer(
              child: FaceVerificationLivenessRingOverlay(
                stepDone: livenessStepDone,
                activeStep: currentLivenessStep,
                activeColor: AppTheme.primaryColor,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FaceVerificationGlassIconButton(
                    icon: Icons.close_rounded,
                    onTap: onClose,
                    dark: true,
                  ),
                  FaceVerificationGlassIconButton(
                    icon: Icons.flash_on_outlined,
                    onTap: onFlashTap,
                    dark: true,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.84),
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              if (isLiveness)
                _buildLivenessInstructionCard()
              else
                _buildSelfieCaptureControls(),
              const SizedBox(height: 18),
              const FaceVerificationPhoneHomeIndicator(dark: true),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLivenessInstructionCard() {
    final steps = livenessStepLabels;
    if (steps.isEmpty) {
      return const SizedBox.shrink();
    }

    final active = currentLivenessStep.clamp(0, steps.length - 1).toInt();
    final doneCount = livenessStepDone.where((done) => done).length;
    final progressText =
        '${math.min(doneCount + 1, steps.length)}/${steps.length}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Chỉ xác minh chuyển động, không lưu video',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.42),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                ),
                child: Icon(_stepIcon(active), color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      steps[active],
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      instructionText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Text(
                    progressText,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _stepIcon(int stepIndex) {
    switch (stepIndex) {
      case 0:
        return Icons.center_focus_strong_rounded;
      case 1:
        return Icons.remove_red_eye_outlined;
      case 2:
        return Icons.turn_left_rounded;
      case 3:
        return Icons.turn_right_rounded;
      default:
        return Icons.face_retouching_natural;
    }
  }

  Widget _buildSelfieCaptureControls() {
    final canCapture = isCameraReady && !isCaptureLocked;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.light_mode_outlined,
                color: Color(0xFFFCD34D),
                size: 15,
              ),
              const SizedBox(width: 6),
              Text(
                'Giữ môi trường đủ sáng',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _CaptureButton(
          enabled: canCapture,
          isLoading: isCaptureLocked,
          onTap: onCaptureSelfie,
        ),
        const SizedBox(height: 12),
        Text(
          'Ảnh chỉ dùng để xác minh',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.52),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCameraFeed() {
    final camera = cameraController;
    if (!isCameraReady || camera == null || !camera.value.isInitialized) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 2.8,
            color: Colors.white,
          ),
        ),
      );
    }

    final previewSize = camera.value.previewSize;
    final previewWidth = previewSize?.height ?? 720;
    final previewHeight = previewSize?.width ?? 1280;

    return ColoredBox(
      color: Colors.black,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewWidth,
          height: previewHeight,
          child: CameraPreview(camera),
        ),
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({
    required this.enabled,
    required this.isLoading,
    required this.onTap,
  });

  final bool enabled;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: enabled ? 1 : 0.55,
        child: Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            color: Colors.white.withValues(alpha: 0.18),
          ),
          child: Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child:
                  isLoading
                      ? const Padding(
                        padding: EdgeInsets.all(18),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFF0F172A),
                        ),
                      )
                      : null,
            ),
          ),
        ),
      ),
    );
  }
}
