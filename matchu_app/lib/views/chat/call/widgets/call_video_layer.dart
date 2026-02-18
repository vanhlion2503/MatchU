import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:matchu_app/controllers/chat/call_controller.dart';

class CallVideoLayer extends StatelessWidget {
  const CallVideoLayer({super.key, required this.controller});

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
