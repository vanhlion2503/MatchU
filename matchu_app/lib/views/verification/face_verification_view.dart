import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/verification/face_verification_controller.dart';
import 'package:matchu_app/models/verification/verification_state.dart';
import 'package:matchu_app/views/verification/widgets/face_capture_overlay.dart';

class FaceVerificationView extends GetView<FaceVerificationController> {
  const FaceVerificationView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final currentState = controller.state.value;
      final isCaptureStage =
          currentState == VerificationState.idle ||
          currentState == VerificationState.capturingSelfie ||
          currentState == VerificationState.liveness;

      return Scaffold(
        backgroundColor: const Color(0xFFF2F3F5),
        appBar: _buildTopBar(),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child:
                isCaptureStage
                    ? _buildCaptureStage(
                      context,
                      isLiveness: currentState == VerificationState.liveness,
                    )
                    : switch (currentState) {
                      VerificationState.processing => _buildProcessingState(
                        context,
                      ),
                      VerificationState.success => _buildResultState(
                        context,
                        true,
                      ),
                      VerificationState.failed => _buildResultState(
                        context,
                        false,
                      ),
                      _ => const SizedBox.shrink(),
                    },
          ),
        ),
      );
    });
  }

  PreferredSizeWidget _buildTopBar() {
    return AppBar(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: const Color(0xFFF2F3F5),
      title: const Text(
        'Xac thuc khuon mat',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      leading: IconButton(
        onPressed: Get.back,
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
      ),
    );
  }

  Widget _buildCaptureStage(BuildContext context, {required bool isLiveness}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SizedBox(
              height: constraints.maxHeight,
              child: _buildCameraCard(context, isLiveness: isLiveness),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCameraCard(BuildContext context, {required bool isLiveness}) {
    final helperText =
        isLiveness
            ? 'Nhay mat va quay dau de tiep tuc'
            : 'Giu moi truong du sang';

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1A3A),
        borderRadius: BorderRadius.circular(38),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildCameraLayer(context),
            FaceCaptureOverlay(
              title: isLiveness ? 'Kiem tra song' : 'Anh chan dung',
              subtitle:
                  isLiveness
                      ? 'Nhay mat va quay dau theo huong dan'
                      : 'Dat khuon mat vao khung va nhin thang',
              helperText: helperText,
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 22,
              child:
                  isLiveness
                      ? _buildLivenessBottomPanel(context)
                      : _buildCaptureBottomPanel(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraLayer(BuildContext context) {
    if (!controller.hasCameraPermission.value &&
        controller.errorText.value.isNotEmpty) {
      return _buildPermissionPlaceholder(context);
    }

    final CameraController? camera = controller.cameraController;
    if (!controller.isCameraReady.value ||
        camera == null ||
        !camera.value.isInitialized) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(
          strokeWidth: 2.8,
          color: Colors.white,
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

  Widget _buildCaptureBottomPanel(BuildContext context) {
    final canCapture =
        controller.isCameraReady.value && !controller.isCaptureLocked.value;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ShutterButton(
          enabled: canCapture,
          isLoading: controller.isCaptureLocked.value,
          onTap: controller.captureSelfie,
        ),
        const SizedBox(height: 10),
        Text(
          'Anh chi dung de xac minh',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLivenessBottomPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _LivenessTag(
                  label: 'Nhay mat',
                  done: controller.blinkDetected.value,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _LivenessTag(
                  label: 'Quay dau',
                  done: controller.headTurnDetected.value,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            controller.instructionText.value,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingState(BuildContext context) {
    return Center(
      child: Container(
        width: 260,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            SizedBox(height: 12),
            Text(
              'Dang xu ly du lieu khuon mat...',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultState(BuildContext context, bool isSuccess) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = isSuccess ? 'Xac thuc thanh cong' : 'Xac thuc that bai';
    final subtitle =
        isSuccess
            ? 'Tai khoan da duoc kich hoat xac minh khuon mat.'
            : controller.errorText.value.isEmpty
            ? 'Vui long thu lai voi anh sang ro va giu khuon mat trong khung.'
            : controller.errorText.value;

    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSuccess
                    ? Icons.verified_rounded
                    : Icons.error_outline_rounded,
                size: 86,
                color: isSuccess ? Colors.green : colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: controller.retryVerification,
                  child: Text(isSuccess ? 'Xac thuc lai' : 'Thu lai'),
                ),
              ),
              if (!controller.hasCameraPermission.value)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: controller.openPermissionSettings,
                      child: const Text('Mo cai dat quyen camera'),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: Get.back,
                  child: const Text('Dong'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionPlaceholder(BuildContext context) {
    return Container(
      color: const Color(0xFF141414),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.no_photography_outlined,
            size: 58,
            color: Colors.white.withValues(alpha: 0.9),
          ),
          const SizedBox(height: 12),
          Text(
            controller.errorText.value,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: controller.openPermissionSettings,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Mo cai dat'),
          ),
        ],
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({
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
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
          ),
          child: Center(
            child: Container(
              width: 74,
              height: 74,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child:
                  isLoading
                      ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Color(0xFF0F1A3A),
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

class _LivenessTag extends StatelessWidget {
  const _LivenessTag({required this.label, required this.done});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color:
            done
                ? Colors.green.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              done
                  ? Colors.greenAccent.withValues(alpha: 0.82)
                  : Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: done ? Colors.greenAccent : Colors.white70,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
