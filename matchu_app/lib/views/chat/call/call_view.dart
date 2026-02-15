import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/call_controller.dart';
import 'package:matchu_app/theme/app_theme.dart';

class CallView extends GetView<CallController> {
  const CallView({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await controller.endCall();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Obx(() {
            final isVideo = controller.isVideoCall;

            return Stack(
              children: [
                Positioned.fill(
                  child:
                      isVideo
                          ? _VideoLayer(controller: controller)
                          : _AudioLayer(controller: controller),
                ),

                Positioned(
                  left: 20,
                  right: 20,
                  top: 16,
                  child: _HeaderInfo(
                    title: controller.peerName.value,
                    subtitle: controller.callStatusText,
                  ),
                ),

                if (isVideo)
                  Positioned(
                    top: 96,
                    right: 16,
                    child: _LocalPreview(controller: controller),
                  ),

                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 24,
                  child: _CallControls(controller: controller),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _VideoLayer extends StatelessWidget {
  const _VideoLayer({required this.controller});

  final CallController controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RTCVideoView(
          controller.remoteRenderer,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.24),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AudioLayer extends StatelessWidget {
  const _AudioLayer({required this.controller});

  final CallController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF111827), Color(0xFF0F172A), Color(0xFF111827)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 62,
              backgroundColor: AppTheme.darkBorder,
              backgroundImage:
                  controller.peerAvatarUrl.value.isNotEmpty
                      ? NetworkImage(controller.peerAvatarUrl.value)
                      : null,
              child:
                  controller.peerAvatarUrl.value.isEmpty
                      ? const Icon(
                        Icons.person,
                        size: 58,
                        color: Colors.white70,
                      )
                      : null,
            ),
            const SizedBox(height: 20),
            Text(
              controller.peerName.value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalPreview extends StatelessWidget {
  const _LocalPreview({required this.controller});

  final CallController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final showCamera = controller.isCameraEnabled.value;

      return AnimatedOpacity(
        opacity: showCamera ? 1 : 0.45,
        duration: const Duration(milliseconds: 180),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 122,
            height: 172,
            color: Colors.black.withValues(alpha: 0.45),
            child:
                showCamera
                    ? RTCVideoView(
                      controller.localRenderer,
                      mirror: true,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    )
                    : const Icon(
                      Icons.videocam_off,
                      color: Colors.white70,
                      size: 34,
                    ),
          ),
        ),
      );
    });
  }
}

class _HeaderInfo extends StatelessWidget {
  const _HeaderInfo({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: textTheme.bodyMedium?.copyWith(
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _CallControls extends StatelessWidget {
  const _CallControls({required this.controller});

  final CallController controller;

  @override
  Widget build(BuildContext context) {
    final isVideo = controller.isVideoCall;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Obx(() {
            final muted = controller.isMuted.value;
            return _ControlButton(
              icon: muted ? Icons.mic_off : Icons.mic,
              backgroundColor:
                  muted ? const Color(0xFF4B5563) : const Color(0xFF1F2937),
              onTap: controller.toggleMute,
            );
          }),
          Obx(() {
            final enabled = controller.isCameraEnabled.value;
            return _ControlButton(
              icon: enabled ? Icons.videocam : Icons.videocam_off,
              backgroundColor:
                  enabled ? const Color(0xFF1F2937) : const Color(0xFF4B5563),
              onTap: isVideo ? controller.toggleCamera : null,
            );
          }),
          if (isVideo)
            _ControlButton(
              icon: Icons.cameraswitch,
              backgroundColor: const Color(0xFF1F2937),
              onTap: controller.switchCamera,
            ),
          _ControlButton(
            icon: Icons.call_end,
            backgroundColor: const Color(0xFFDC2626),
            onTap: controller.endCall,
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.backgroundColor,
    required this.onTap,
  });

  final IconData icon;
  final Color backgroundColor;
  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap:
          enabled
              ? () async {
                await onTap!.call();
              }
              : null,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color:
              enabled
                  ? backgroundColor
                  : backgroundColor.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}
