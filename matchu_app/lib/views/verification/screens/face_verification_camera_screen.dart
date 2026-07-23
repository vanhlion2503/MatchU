import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:matchu_app/translations/localized_material.dart';
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
  final VoidCallback onCaptureSelfie;

  @override
  Widget build(BuildContext context) {
    final title = isLiveness ? 'Kiểm tra sống' : 'Ảnh chân dung';
    final subtitle =
        isLiveness
            ? 'Nhìn thẳng và quay đầu theo thứ tự hướng dẫn'
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
              const SizedBox(height: 38),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FaceVerificationGlassIconButton(
                    icon: Icons.close_rounded,
                    onTap: onClose,
                  ),
                  const SizedBox(width: 44, height: 44),
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
                _buildLivenessInstructionCard(context)
              else
                _buildSelfieCaptureControls(context),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLivenessInstructionCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

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
        // 🔒 Privacy note
        Text(
          'Chỉ xác minh chuyển động, không lưu video',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
        ),

        const SizedBox(height: 12),

        // 📦 Instruction card
        Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            color:
                isDark
                    ? AppTheme.darkSurface.withValues(alpha: 0.92)
                    : AppTheme.lightSurface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color:
                  isDark
                      ? AppTheme.darkBorder.withValues(alpha: 0.8)
                      : AppTheme.lightBorder,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.18),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              // 🎯 Step icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                ),
                child: Icon(_stepIcon(active), color: AppTheme.primaryColor),
              ),

              const SizedBox(width: 12),

              // 📝 Instruction text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      steps[active],
                      style: textTheme.bodyMedium?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      instructionText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // 📊 Progress
              Column(
                children: [
                  Text(
                    progressText,
                    style: textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
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

  Widget _buildSelfieCaptureControls(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final canCapture = isCameraReady && !isCaptureLocked;

    return Column(
      children: [
        // 🔔 Tip ánh sáng
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45), // overlay OK
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.light_mode_outlined,
                size: 15,
                color: Color(0xFFFCD34D), // màu cảnh báo ánh sáng → giữ nguyên
              ),
              const SizedBox(width: 6),
              Text(
                'Giữ môi trường đủ sáng',
                style: textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 📸 Capture button
        _CaptureButton(
          enabled: canCapture,
          isLoading: isCaptureLocked,
          onTap: onCaptureSelfie,
        ),

        const SizedBox(height: 12),

        // 🔒 Privacy note
        Text(
          'Ảnh chỉ dùng để xác minh',
          style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
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
