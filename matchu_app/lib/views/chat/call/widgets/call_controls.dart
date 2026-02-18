import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/call_controller.dart';
import 'package:matchu_app/views/chat/call/widgets/call_control_button.dart';

class CallControls extends StatelessWidget {
  const CallControls({super.key, required this.controller});

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
            return CallControlButton(
              icon: muted ? Icons.mic_off : Icons.mic,
              backgroundColor:
                  muted ? const Color(0xFF4B5563) : const Color(0xFF1F2937),
              onTap: controller.toggleMute,
            );
          }),
          Obx(() {
            final enabled = controller.isCameraEnabled.value;
            return CallControlButton(
              icon: enabled ? Icons.videocam : Icons.videocam_off,
              backgroundColor:
                  enabled ? const Color(0xFF1F2937) : const Color(0xFF4B5563),
              onTap: isVideo ? controller.toggleCamera : null,
            );
          }),
          if (isVideo)
            CallControlButton(
              icon: Icons.cameraswitch,
              backgroundColor: const Color(0xFF1F2937),
              onTap: controller.switchCamera,
            ),
          CallControlButton(
            icon: Icons.call_end,
            backgroundColor: const Color(0xFFDC2626),
            onTap: controller.endCall,
          ),
        ],
      ),
    );
  }
}
