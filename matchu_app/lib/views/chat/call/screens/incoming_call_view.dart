import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/chat/call_controller.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/chat/call/widgets/incoming_call_action_button.dart';
import 'package:simple_ripple_animation/simple_ripple_animation.dart';

class IncomingCallView extends GetView<CallController> {
  const IncomingCallView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Obx(() {
        final callId =
            controller.currentCallId.value ??
            ((Get.arguments as Map?)?['callId'] as String?);
        final isVideo = controller.callType.value == 'video';
        final avatarUrl = controller.peerAvatarUrl.value;

        return Stack(
          children: [
            Positioned.fill(
              child:
                  avatarUrl.isNotEmpty
                      ? ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) =>
                                  const ColoredBox(color: Color(0xFF0D1117)),
                        ),
                      )
                      : const ColoredBox(color: Color(0xFF0D1117)),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.38),
                      Colors.black.withValues(alpha: 0.58),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child:
                  callId == null || callId.isEmpty
                      ? Center(
                        child: Text(
                          'Cuộc gọi hiện tại không có sẵn',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                      : Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 70),
                            RippleAnimation(
                              color: Colors.white.withValues(alpha: 0.22),
                              minRadius: 40,
                              ripplesCount: 2,
                              duration: const Duration(seconds: 3),
                              repeat: true,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    width: 2,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 60,
                                  backgroundColor: AppTheme.darkBorder,
                                  backgroundImage:
                                      avatarUrl.isNotEmpty
                                          ? NetworkImage(avatarUrl)
                                          : null,
                                  child:
                                      avatarUrl.isEmpty
                                          ? const Icon(
                                            Icons.person,
                                            size: 60,
                                            color: Colors.white70,
                                          )
                                          : null,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              controller.peerName.value,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isVideo
                                  ? 'Cuộc gọi video đến ...'
                                  : 'Cuộc gọi thoại đến ...',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IncomingCallActionButton(
                                  icon: Iconsax.call_slash,
                                  label: 'Từ chối',
                                  color: const Color(0xFFDC3545),
                                  onTap: () => controller.rejectCall(callId),
                                ),
                                const SizedBox(width: 12),
                                IncomingCallActionButton(
                                  icon: isVideo ? Iconsax.video : Iconsax.call_calling,
                                  label: 'Chập nhận',
                                  color: const Color(0xFF28A745),
                                  onTap: () => controller.acceptCall(callId),
                                ),
                              ],
                            ),
                            const SizedBox(height: 44),
                          ],
                        ),
                      ),
            ),
          ],
        );
      }),
    );
  }
}
