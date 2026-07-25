import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/temp_chat_controller.dart';
import 'package:matchu_app/widgets/temp_room_extension_overlay.dart';

class TempChatExtensionOverlay extends StatelessWidget {
  const TempChatExtensionOverlay({super.key, required this.controller});

  final TempChatController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => TempRoomExtensionOverlay(
        isVisible: controller.canExtendRoom,
        remainingSeconds: controller.remainingSeconds.value,
        extensionCount: controller.extensionCount.value,
        isLoading: controller.isExtendingRoom.value,
        onExtend: controller.extendRoom,
      ),
    );
  }
}
