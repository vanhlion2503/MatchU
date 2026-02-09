import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/verification/face_verification_controller.dart';
import 'package:matchu_app/models/verification/verification_state.dart';
import 'package:matchu_app/theme/app_theme.dart';

class FaceVerificationView extends GetView<FaceVerificationController> {
  const FaceVerificationView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isCheckingVerificationStatus.value) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: const Center(child: CircularProgressIndicator()),
        );
      }

      final currentState = controller.state.value;
      final showIntro =
          !controller.hasStartedVerificationFlow.value &&
          (currentState == VerificationState.idle ||
              currentState == VerificationState.capturingSelfie);

      if (showIntro) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(bottom: false, child: _buildIntroStage(context)),
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
            VerificationState.idle || VerificationState.capturingSelfie =>
              _buildSelfieCaptureStage(context),
            VerificationState.liveness => _buildLivenessStage(context),
            VerificationState.processing => _buildProcessingStage(context),
            VerificationState.success => _buildSuccessStage(context),
            VerificationState.failed => _buildFailedStage(context),
          },
        ),
      );
    });
  }

  bool _isDarkStage(VerificationState state) {
    return state == VerificationState.capturingSelfie ||
        state == VerificationState.liveness ||
        state == VerificationState.processing ||
        state == VerificationState.idle;
  }

  Widget _buildIntroStage(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -80,
          child: _SoftCircle(
            size: 260,
            color: colorScheme.primary.withValues(alpha: 0.1),
          ),
        ),
        Positioned(
          bottom: 90,
          left: -60,
          child: _SoftCircle(
            size: 220,
            color: AppTheme.secondaryColor.withValues(alpha: 0.16),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            children: [
              Row(
                children: [
                  _GlassIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: Get.back,
                    dark: false,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary.withValues(alpha: 0.18),
                      Colors.white,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    const Center(
                      child: Icon(
                        Icons.face_retouching_natural,
                        size: 62,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.grey.withValues(alpha: 0.2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.verified_user_outlined,
                          size: 18,
                          color: Colors.teal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              Text(
                'Xac thuc khuon mat',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Giup cong dong an toan va dang tin cay hon. Qua trinh nay hoan toan rieng tu.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
              ),
              const SizedBox(height: 26),
              const _IntroStepTile(
                icon: Icons.camera_alt_outlined,
                label: 'Chup anh selfie chan dung',
              ),
              const SizedBox(height: 12),
              const _IntroStepTile(
                icon: Icons.face_6_outlined,
                label: 'Xac thuc chuyen dong khuon mat',
              ),
              const SizedBox(height: 12),
              const _IntroStepTile(
                icon: Icons.timer_outlined,
                label: 'Hoan tat trong khoang 30 giay',
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: controller.startVerificationFlow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Bat dau xac thuc'),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 13,
                    color: Color(0xFF9CA3AF),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Chi dung cho xac minh, khong hien thi cong khai',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const _PhoneHomeIndicator(dark: false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelfieCaptureStage(BuildContext context) {
    if (!controller.hasCameraPermission.value &&
        controller.errorText.value.isNotEmpty) {
      return _buildPermissionCaptureState(context);
    }

    return _buildCameraStage(context, isLiveness: false);
  }

  Widget _buildLivenessStage(BuildContext context) {
    if (!controller.hasCameraPermission.value &&
        controller.errorText.value.isNotEmpty) {
      return _buildPermissionCaptureState(context);
    }

    return _buildCameraStage(context, isLiveness: true);
  }

  Widget _buildCameraStage(BuildContext context, {required bool isLiveness}) {
    final title = isLiveness ? 'Kiem tra song' : 'Anh chan dung';
    final subtitle =
        isLiveness
            ? 'Nhin thang, chop mat, quay trai, quay phai'
            : 'Dat khuon mat vao khung va nhin thang';

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildCameraFeed(context),
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
            child: _FaceMaskOverlay(
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
              child: _LivenessRingOverlay(
                stepDone: controller.livenessStepDone.toList(),
                activeStep: controller.currentLivenessStep.value,
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
                  _GlassIconButton(
                    icon: Icons.close_rounded,
                    onTap: Get.back,
                    dark: true,
                  ),
                  _GlassIconButton(
                    icon: Icons.flash_on_outlined,
                    onTap: () {},
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
                _buildLivenessInstructionCard(context)
              else
                _buildSelfieCaptureControls(context),
              const SizedBox(height: 18),
              const _PhoneHomeIndicator(dark: true),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLivenessInstructionCard(BuildContext context) {
    final steps = controller.livenessStepLabels;
    final active = controller.currentLivenessStep.value.clamp(
      0,
      steps.length - 1,
    );
    final doneCount = controller.livenessStepDone.where((done) => done).length;
    final progressText =
        '${math.min(doneCount + 1, steps.length)}/${steps.length}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Chi xac minh chuyen dong - khong luu video',
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
                      controller.instructionText.value,
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

  Widget _buildSelfieCaptureControls(BuildContext context) {
    final canCapture =
        controller.isCameraReady.value && !controller.isCaptureLocked.value;

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
                'Giu moi truong du sang',
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
          isLoading: controller.isCaptureLocked.value,
          onTap: controller.captureSelfie,
        ),
        const SizedBox(height: 12),
        Text(
          'Anh chi dung de xac minh',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.52),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCameraFeed(BuildContext context) {
    final camera = controller.cameraController;
    if (!controller.isCameraReady.value ||
        camera == null ||
        !camera.value.isInitialized) {
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

  Widget _buildProcessingStage(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0F172A), Color(0xFF020617)],
            ),
          ),
        ),
        Positioned(
          top: -100,
          left: -80,
          child: _SoftCircle(
            size: 260,
            color: AppTheme.primaryColor.withValues(alpha: 0.14),
          ),
        ),
        Positioned(
          bottom: -90,
          right: -80,
          child: _SoftCircle(
            size: 240,
            color: AppTheme.secondaryColor.withValues(alpha: 0.14),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ScanningAvatar(size: 188, lineColor: AppTheme.primaryColor),
                const SizedBox(height: 22),
                const Text(
                  'Dang xac minh...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Qua trinh nay chi mat vai giay',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: SizedBox(
                    width: 220,
                    child: LinearProgressIndicator(
                      minHeight: 5,
                      backgroundColor: Colors.white.withValues(alpha: 0.16),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 18,
          child: _PhoneHomeIndicator(dark: true),
        ),
      ],
    );
  }

  Widget _buildSuccessStage(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.successColor.withValues(alpha: 0.12),
                  theme.scaffoldBackgroundColor,
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              children: [
                const SizedBox(height: 14),
                Container(
                  width: 98,
                  height: 98,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.successColor.withValues(alpha: 0.14),
                  ),
                  child: Center(
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.successColor,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.successColor.withValues(
                              alpha: 0.34,
                            ),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.22),
                    ),
                  ),
                  child: const Text(
                    'DA XAC THUC',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Xac thuc thanh cong!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  controller.wasAlreadyVerifiedAtEntry.value
                      ? 'Tai khoan cua ban da xac thuc truoc do. Ban khong can xac thuc lai.'
                      : 'Ho so cua ban da duoc xac minh danh tinh an toan.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 26),
                const _BenefitTile(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Khong gioi han chat',
                  subtitle: 'Ket noi voi moi nguoi khong rao can',
                ),
                const SizedBox(height: 10),
                const _BenefitTile(
                  icon: Icons.workspace_premium_outlined,
                  title: 'Huy hieu tin cay',
                  subtitle: 'Ho so hien thi trang thai da xac minh',
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: Get.back,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Tiep tuc trai nghiem'),
                  ),
                ),
                if (!controller.wasAlreadyVerifiedAtEntry.value) ...[
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () {
                      controller.hasStartedVerificationFlow.value = true;
                      controller.retryVerification();
                    },
                    child: const Text('Xac thuc lai'),
                  ),
                ],
                const SizedBox(height: 10),
                const _PhoneHomeIndicator(dark: false),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFailedStage(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
        child: Column(
          children: [
            Row(
              children: [
                _GlassIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: Get.back,
                  dark: false,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFDEBD8),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFF97316),
                size: 52,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Chua xac thuc duoc',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              controller.errorText.value.isEmpty
                  ? 'He thong chua the xac nhan khuon mat cua ban khop voi ho so.'
                  : controller.errorText.value,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 26),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Ly do thuong gap',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF0F172A),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const _ReasonTile(
              icon: Icons.blur_on_outlined,
              label: 'Khuon mat bi mo hoac qua toi',
            ),
            const SizedBox(height: 8),
            const _ReasonTile(
              icon: Icons.visibility_off_outlined,
              label: 'Dang deo kinh ram hoac khau trang',
            ),
            const SizedBox(height: 8),
            const _ReasonTile(
              icon: Icons.screen_rotation_alt_outlined,
              label: 'Chuyen dong chua dung huong dan',
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  controller.hasStartedVerificationFlow.value = true;
                  controller.retryVerification();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Thu lai ngay'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: Get.back,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Xac thuc sau'),
              ),
            ),
            if (!controller.hasCameraPermission.value)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton(
                  onPressed: controller.openPermissionSettings,
                  child: const Text('Mo cai dat quyen camera'),
                ),
              ),
            const SizedBox(height: 10),
            const _PhoneHomeIndicator(dark: false),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCaptureState(BuildContext context) {
    return Container(
      color: const Color(0xFF0B1220),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.no_photography_outlined,
            color: Colors.white,
            size: 62,
          ),
          const SizedBox(height: 12),
          Text(
            controller.errorText.value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: controller.openPermissionSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Mo cai dat'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: Get.back, child: const Text('Dong')),
          const SizedBox(height: 16),
          const _PhoneHomeIndicator(dark: true),
        ],
      ),
    );
  }
}

class _IntroStepTile extends StatelessWidget {
  const _IntroStepTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF334155),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    required this.dark,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Ink(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
              dark
                  ? Colors.white.withValues(alpha: 0.14)
                  : const Color(0xFFF8FAFC),
          border: Border.all(
            color:
                dark
                    ? Colors.white.withValues(alpha: 0.2)
                    : const Color(0xFFE2E8F0),
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: dark ? Colors.white : const Color(0xFF0F172A),
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

class _BenefitTile extends StatelessWidget {
  const _BenefitTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFFF8FAFC),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF475569),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneHomeIndicator extends StatelessWidget {
  const _PhoneHomeIndicator({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 128,
        height: 4,
        decoration: BoxDecoration(
          color:
              dark
                  ? Colors.white.withValues(alpha: 0.24)
                  : Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _SoftCircle extends StatelessWidget {
  const _SoftCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

class _FaceMaskOverlay extends StatelessWidget {
  const _FaceMaskOverlay({
    required this.isLiveness,
    required this.maskColor,
    required this.borderColor,
  });

  final bool isLiveness;
  final Color maskColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FaceMaskPainter(
        isLiveness: isLiveness,
        maskColor: maskColor,
        borderColor: borderColor,
      ),
    );
  }
}

class _FaceMaskPainter extends CustomPainter {
  _FaceMaskPainter({
    required this.isLiveness,
    required this.maskColor,
    required this.borderColor,
  });

  final bool isLiveness;
  final Color maskColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.45),
      width: size.width * (isLiveness ? 0.75 : 0.72),
      height: size.height * (isLiveness ? 0.5 : 0.48),
    );

    final maskPath =
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
          ..addOval(ovalRect);

    canvas.drawPath(maskPath, Paint()..color = maskColor);

    canvas.drawOval(
      ovalRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isLiveness ? 2.6 : 2.2
        ..color = borderColor,
    );
  }

  @override
  bool shouldRepaint(covariant _FaceMaskPainter oldDelegate) {
    return oldDelegate.isLiveness != isLiveness ||
        oldDelegate.maskColor != maskColor ||
        oldDelegate.borderColor != borderColor;
  }
}

class _LivenessRingOverlay extends StatelessWidget {
  const _LivenessRingOverlay({
    required this.stepDone,
    required this.activeStep,
    required this.activeColor,
  });

  final List<bool> stepDone;
  final int activeStep;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LivenessRingPainter(
        stepDone: stepDone,
        activeStep: activeStep,
        activeColor: activeColor,
      ),
    );
  }
}

class _LivenessRingPainter extends CustomPainter {
  _LivenessRingPainter({
    required this.stepDone,
    required this.activeStep,
    required this.activeColor,
  });

  final List<bool> stepDone;
  final int activeStep;
  final Color activeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.45),
      width: size.width * 0.8,
      height: size.height * 0.56,
    );

    final trackPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = Colors.white.withValues(alpha: 0.14);
    canvas.drawOval(ovalRect, trackPaint);

    const stepCount = 4;
    const section = math.pi / 2;
    const gap = 0.2;

    for (int i = 0; i < stepCount; i++) {
      final done = i < stepDone.length && stepDone[i];
      final active = i == activeStep && !done;
      final color =
          done
              ? const Color(0xFF2DD4BF)
              : active
              ? activeColor
              : Colors.white.withValues(alpha: 0.22);

      canvas.drawArc(
        ovalRect,
        -math.pi / 2 + (i * section) + (gap / 2),
        section - gap,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = done || active ? 5 : 4
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LivenessRingPainter oldDelegate) {
    if (oldDelegate.activeStep != activeStep ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.stepDone.length != stepDone.length) {
      return true;
    }

    for (int i = 0; i < stepDone.length; i++) {
      if (oldDelegate.stepDone[i] != stepDone[i]) {
        return true;
      }
    }
    return false;
  }
}

class _ScanningAvatar extends StatefulWidget {
  const _ScanningAvatar({required this.size, required this.lineColor});

  final double size;
  final Color lineColor;

  @override
  State<_ScanningAvatar> createState() => _ScanningAvatarState();
}

class _ScanningAvatarState extends State<_ScanningAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Icon(
              Icons.account_circle_outlined,
              color: Colors.white.withValues(alpha: 0.24),
              size: widget.size * 0.78,
            ),
          ),
          ClipOval(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final travel = widget.size - 28;
                final top = (_controller.value * travel) - 14;
                return Stack(
                  children: [
                    Positioned(
                      left: 16,
                      right: 16,
                      top: top,
                      child: Container(
                        height: 24,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              widget.lineColor.withValues(alpha: 0),
                              widget.lineColor.withValues(alpha: 0.82),
                              widget.lineColor.withValues(alpha: 0),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: widget.lineColor.withValues(alpha: 0.5),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
