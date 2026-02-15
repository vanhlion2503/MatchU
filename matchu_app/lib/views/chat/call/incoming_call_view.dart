import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/call_controller.dart';
import 'package:matchu_app/theme/app_theme.dart';

class IncomingCallView extends GetView<CallController> {
  const IncomingCallView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Obx(() {
          final callId =
              controller.currentCallId.value ??
              ((Get.arguments as Map?)?['callId'] as String?);
          final isVideo = controller.callType.value == 'video';

          if (callId == null || callId.isEmpty) {
            return const Center(
              child: Text(
                'Incoming call is no longer available.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                const SizedBox(height: 40),
                Text(
                  isVideo ? 'Incoming video call' : 'Incoming voice call',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),
                CircleAvatar(
                  radius: 52,
                  backgroundColor: AppTheme.darkBorder,
                  backgroundImage:
                      controller.peerAvatarUrl.value.isNotEmpty
                          ? NetworkImage(controller.peerAvatarUrl.value)
                          : null,
                  child:
                      controller.peerAvatarUrl.value.isEmpty
                          ? const Icon(
                            Icons.person,
                            size: 52,
                            color: Colors.white70,
                          )
                          : null,
                ),
                const SizedBox(height: 20),
                Text(
                  controller.peerName.value,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CallActionButton(
                      icon: Icons.call_end,
                      label: 'Decline',
                      color: const Color(0xFFDC3545),
                      onTap: () => controller.rejectCall(callId),
                    ),
                    _CallActionButton(
                      icon: isVideo ? Icons.videocam : Icons.call,
                      label: 'Accept',
                      color: const Color(0xFF28A745),
                      onTap: () => controller.acceptCall(callId),
                    ),
                  ],
                ),
                const SizedBox(height: 44),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(36),
          onTap: onTap,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 34),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
