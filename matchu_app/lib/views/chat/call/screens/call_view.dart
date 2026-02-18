import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/call_controller.dart';
import 'package:matchu_app/views/chat/call/screens/call_outgoing_waiting_view.dart';
import 'package:matchu_app/views/chat/call/widgets/call_audio_layer.dart';
import 'package:matchu_app/views/chat/call/widgets/call_controls.dart';
import 'package:matchu_app/views/chat/call/widgets/call_header_info.dart';
import 'package:matchu_app/views/chat/call/widgets/call_local_preview.dart';
import 'package:matchu_app/views/chat/call/widgets/call_video_layer.dart';

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
        body: Obx(() {
          final callState = controller.callState.value;
          final isCaller = controller.isCaller.value;
          final isVideo = controller.isVideoCall;
          final peerName = controller.peerName.value;
          final avatarUrl = controller.peerAvatarUrl.value;
          final statusText = controller.callStatusText;
          final isOutgoingWaiting =
              isCaller &&
              (callState == CallUiState.creating ||
                  callState == CallUiState.ringing);
          final safePadding = MediaQuery.paddingOf(context);

          return Stack(
            children: [
              Positioned.fill(
                child:
                    isOutgoingWaiting
                        ? CallOutgoingWaitingView(
                          avatarUrl: avatarUrl,
                          title: peerName,
                          subtitle: statusText,
                        )
                        : (isVideo
                            ? CallVideoLayer(controller: controller)
                            : CallAudioLayer(
                              avatarUrl: avatarUrl,
                              title: peerName,
                              subtitle: statusText,
                            )),
              ),
              if (!isOutgoingWaiting && isVideo)
                Positioned(
                  left: 20,
                  right: 20,
                  top: safePadding.top + 16,
                  child: CallHeaderInfo(title: peerName, subtitle: statusText),
                ),
              if (isVideo && !isOutgoingWaiting)
                Positioned(
                  top: safePadding.top + 96,
                  right: 16,
                  child: CallLocalPreview(controller: controller),
                ),
              Positioned(
                left: 12,
                right: 12,
                bottom: safePadding.bottom + 24,
                child: CallControls(controller: controller),
              ),
            ],
          );
        }),
      ),
    );
  }
}
