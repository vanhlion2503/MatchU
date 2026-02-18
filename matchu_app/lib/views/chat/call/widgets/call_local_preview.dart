import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/call_controller.dart';

class CallLocalPreview extends StatelessWidget {
  const CallLocalPreview({super.key, required this.controller});

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
