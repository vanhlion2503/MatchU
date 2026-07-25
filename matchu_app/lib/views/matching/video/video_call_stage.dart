import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/matching/video_matching_controller.dart';
import 'package:matchu_app/models/chat_peer_summary.dart';
import 'package:matchu_app/translations/chat_safety_translations.dart';
import 'package:matchu_app/translations/localized_material.dart';
import 'package:matchu_app/translations/video_matching_translations.dart';
import 'package:matchu_app/widgets/chat_rating_safety_notice.dart';
import 'package:matchu_app/widgets/temp_room_extension_overlay.dart';

enum _ExitChoice { stay, leave }

enum _LeaveChoice { exitRoom, findNext }

class VideoCallStage extends StatelessWidget {
  const VideoCallStage({super.key, required this.controller});

  final VideoMatchingController controller;

  Future<void> _showExitChoices(BuildContext context) async {
    final choice = await showDialog<_ExitChoice>(
      context: context,
      builder:
          (dialogContext) => _ExitDialog(
            title: 'Rời phòng video?'.tr,
            description: 'Bạn muốn ở lại hay rời khỏi phòng hiện tại?'.tr,
            actions: [
              _ExitDialogAction(
                icon: Icons.logout_rounded,
                label: 'Rời đi'.tr,
                kind: _ExitButtonKind.leave,
                onTap: () => Navigator.of(dialogContext).pop(_ExitChoice.leave),
              ),
              _ExitDialogAction(
                icon: Icons.pause_rounded,
                label: 'Ở lại'.tr,
                kind: _ExitButtonKind.primary,
                onTap: () => Navigator.of(dialogContext).pop(_ExitChoice.stay),
              ),
            ],
          ),
    );

    if (choice != _ExitChoice.leave || !context.mounted) return;
    await _showLeaveChoices(context);
  }

  Future<void> _showLeaveChoices(BuildContext context) async {
    final choice = await showDialog<_LeaveChoice>(
      context: context,
      builder:
          (dialogContext) => _ExitDialog(
            title: 'Bạn muốn làm gì tiếp theo?'.tr,
            description: 'Thoát khỏi phòng hoặc tiếp tục tìm một người mới.'.tr,
            actions: [
              _ExitDialogAction(
                icon: Icons.logout_rounded,
                label: 'Thoát khỏi phòng'.tr,
                kind: _ExitButtonKind.leave,
                onTap:
                    () =>
                        Navigator.of(dialogContext).pop(_LeaveChoice.exitRoom),
              ),
              _ExitDialogAction(
                icon: Iconsax.user_add,
                label: 'Tiếp tục tìm'.tr,
                kind: _ExitButtonKind.primary,
                onTap:
                    () =>
                        Navigator.of(dialogContext).pop(_LeaveChoice.findNext),
              ),
            ],
          ),
    );

    switch (choice) {
      case _LeaveChoice.exitRoom:
        await controller.leaveRoom(findNext: false);
        return;
      case _LeaveChoice.findNext:
        await controller.leaveRoom(findNext: true);
        return;
      case null:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _VideoCanvas(controller: controller, lockText: _cameraLockText),
          const _CallRevealOverlay(),
          _CallTopBar(
            controller: controller,
            onExit: () => _showExitChoices(context),
          ),
          _VideoExtensionPrompt(controller: controller),
          _ConnectionStatus(controller: controller, lockText: _cameraLockText),
          _CallBottomControls(controller: controller),
          Obx(
            () =>
                controller.phase.value == VideoMatchingPhase.ending
                    ? ColoredBox(
                      color: Colors.black.withValues(alpha: 0.36),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    )
                    : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  String _cameraLockText(int seconds) {
    if (seconds <= 0) return 'Camera đã sẵn sàng'.tr;
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainder = (seconds % 60).toString().padLeft(2, '0');
    return videoMatchingTr('Có thể mở camera sau $minutes:$remainder');
  }
}

class _VideoExtensionPrompt extends StatelessWidget {
  const _VideoExtensionPrompt({required this.controller});

  final VideoMatchingController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => TempRoomExtensionOverlay(
        isVisible: controller.canExtendRoom,
        remainingSeconds: controller.roomRemainingSeconds.value,
        extensionCount: controller.extensionCount.value,
        isLoading: controller.isExtendingRoom.value,
        onExtend: controller.extendRoom,
        topInset: MediaQuery.paddingOf(context).top + 82,
      ),
    );
  }
}

enum _ExitButtonKind { leave, primary }

class _ExitDialogAction {
  const _ExitDialogAction({
    required this.icon,
    required this.label,
    required this.kind,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final _ExitButtonKind kind;
  final VoidCallback onTap;
}

class _ExitDialog extends StatelessWidget {
  const _ExitDialog({
    required this.title,
    required this.description,
    required this.actions,
  });

  final String title;
  final String description;
  final List<_ExitDialogAction> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(description, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 22),
              SizedBox(
                height: 54,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < actions.length; index++) ...[
                      if (index > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _ExitChoiceButton(
                          icon: actions[index].icon,
                          label: actions[index].label,
                          kind: actions[index].kind,
                          onTap: actions[index].onTap,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExitChoiceButton extends StatelessWidget {
  const _ExitChoiceButton({
    required this.icon,
    required this.label,
    required this.kind,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final _ExitButtonKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLeave = kind == _ExitButtonKind.leave;
    final foreground = isLeave ? scheme.onError : scheme.onPrimary;

    return Material(
      color: isLeave ? scheme.error : scheme.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isLeave ? scheme.error : scheme.primary),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: foreground),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoCanvas extends StatelessWidget {
  const _VideoCanvas({required this.controller, required this.lockText});

  final VideoMatchingController controller;
  final String Function(int seconds) lockText;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Obx(() {
            final seconds = controller.cameraUnlockRemainingSeconds.value;
            final cameraEnabled = controller.localCameraEnabled.value;
            return RepaintBoundary(
              child: _VideoTile(
                renderer: controller.localRenderer,
                label: 'Bạn'.tr,
                avatarAsset:
                    'assets/anonymous/${controller.anonymousAvatar}.png',
                cameraEnabled: cameraEnabled,
                cameraUnlocked: controller.cameraUnlocked.value,
                cameraOffText: 'Camera đang tắt'.tr,
                cameraLockText: lockText(seconds),
                mirror: true,
                muted: controller.isMuted.value,
                voiceLevel:
                    cameraEnabled ? 0 : controller.localVoiceLevel.value,
              ),
            );
          }),
        ),
        Container(height: 1, color: Colors.white24),
        Expanded(
          child: Obx(() {
            final seconds = controller.cameraUnlockRemainingSeconds.value;
            final cameraEnabled = controller.remoteCameraEnabled.value;
            return RepaintBoundary(
              child: _VideoTile(
                renderer: controller.remoteRenderer,
                label: 'Người lạ'.tr,
                rating: controller.otherAvgRating.value,
                peerSummary: controller.otherPeerSummary.value,
                labelAtTop: true,
                avatarAsset:
                    'assets/anonymous/${controller.otherAnonymousAvatar.value}.png',
                cameraEnabled: cameraEnabled,
                cameraUnlocked: controller.cameraUnlocked.value,
                cameraOffText: 'Camera của đối phương đang tắt'.tr,
                cameraLockText: lockText(seconds),
                mirror: false,
                muted: controller.remoteMuted.value,
                voiceLevel:
                    cameraEnabled ? 0 : controller.remoteVoiceLevel.value,
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _CallRevealOverlay extends StatelessWidget {
  const _CallRevealOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1, end: 0),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        builder:
            (_, value, __) =>
                ColoredBox(color: Colors.black.withValues(alpha: value * 0.52)),
      ),
    );
  }
}

class _CallTopBar extends StatelessWidget {
  const _CallTopBar({required this.controller, required this.onExit});

  final VideoMatchingController controller;
  final Future<void> Function() onExit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
        child: Align(
          alignment: Alignment.topCenter,
          child: Obx(() {
            final ending = controller.phase.value == VideoMatchingPhase.ending;
            final liked = controller.hasLiked.value;
            return Row(
              children: [
                _GlassIconButton(
                  tooltip: 'Kết thúc'.tr,
                  icon: Icons.close_rounded,
                  onTap: ending ? null : onExit,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.48),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    controller.formattedRoomTime,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const Spacer(),
                _GlassIconButton(
                  tooltip: liked ? 'Đã thả tim'.tr : 'Thả tim'.tr,
                  icon: liked ? Iconsax.heart5 : Iconsax.heart,
                  foreground: liked ? const Color(0xFFFF3B4E) : Colors.white,
                  disabledForeground: liked ? const Color(0xFFFF3B4E) : null,
                  onTap: liked || ending ? null : controller.like,
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus({required this.controller, required this.lockText});

  final VideoMatchingController controller;
  final String Function(int seconds) lockText;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Obx(() {
        final connecting =
            controller.phase.value == VideoMatchingPhase.connecting;
        final text =
            connecting
                ? 'Đang kết nối âm thanh...'.tr
                : lockText(controller.cameraUnlockRemainingSeconds.value);
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          child: Container(
            key: ValueKey(text),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.64),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _CallBottomControls extends StatelessWidget {
  const _CallBottomControls({required this.controller});

  final VideoMatchingController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
          child: Obx(() {
            final ending = controller.phase.value == VideoMatchingPhase.ending;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _CompactAction(
                      icon: Iconsax.refresh,
                      label: 'Tìm người mới'.tr,
                      onTap:
                          ending
                              ? null
                              : () => controller.leaveRoom(findNext: true),
                    ),
                    if (controller.otherLiked.value) const _PeerLikedBadge(),
                  ],
                ),
                const SizedBox(height: 10),
                _CallControlDock(controller: controller, disabled: ending),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _VideoTile extends StatelessWidget {
  const _VideoTile({
    required this.renderer,
    required this.label,
    required this.avatarAsset,
    required this.cameraEnabled,
    required this.cameraUnlocked,
    required this.cameraOffText,
    required this.cameraLockText,
    required this.mirror,
    required this.muted,
    required this.voiceLevel,
    this.rating,
    this.peerSummary,
    this.labelAtTop = false,
  });

  final RTCVideoRenderer renderer;
  final String label;
  final String avatarAsset;
  final bool cameraEnabled;
  final bool cameraUnlocked;
  final String cameraOffText;
  final String cameraLockText;
  final bool mirror;
  final bool muted;
  final double voiceLevel;
  final double? rating;
  final ChatPeerSummary? peerSummary;
  final bool labelAtTop;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RTCVideoValue>(
      valueListenable: renderer,
      builder: (context, rendererValue, _) {
        final frameReady =
            cameraEnabled &&
            rendererValue.renderVideo &&
            rendererValue.width > 0 &&
            rendererValue.height > 0;
        final statusText =
            cameraEnabled
                ? 'Đang kết nối camera...'.tr
                : cameraUnlocked
                ? cameraOffText
                : cameraLockText;

        return Stack(
          fit: StackFit.expand,
          children: [
            if (cameraEnabled)
              RTCVideoView(
                renderer,
                mirror: mirror,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            if (!frameReady)
              _VideoAvatarPlaceholder(
                avatarAsset: avatarAsset,
                statusText: statusText,
                muted: muted,
                voiceLevel: voiceLevel,
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.28),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.4),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 14,
              top: labelAtTop ? 12 : null,
              bottom: labelAtTop ? null : 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (labelAtTop && rating != null) ...[
                      const SizedBox(width: 7),
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFFC857),
                        size: 15,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        rating!.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ] else if (labelAtTop && peerSummary != null) ...[
                      const SizedBox(width: 7),
                      const Icon(
                        Icons.person_outline_rounded,
                        color: Colors.white70,
                        size: 15,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        ChatSafetyTranslationKeys.newcomer.tr,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (muted) ...[
                      const SizedBox(width: 7),
                      const Icon(
                        Icons.mic_off_rounded,
                        color: Color(0xFFFF667A),
                        size: 16,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (labelAtTop && peerSummary?.shouldShowSafetyCaution == true)
              Positioned(
                left: 14,
                top: 49,
                child: ChatRatingSafetyNotice(
                  summary: peerSummary,
                  compact: true,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _VideoAvatarPlaceholder extends StatelessWidget {
  const _VideoAvatarPlaceholder({
    required this.avatarAsset,
    required this.statusText,
    required this.muted,
    required this.voiceLevel,
  });

  final String avatarAsset;
  final String statusText;
  final bool muted;
  final double voiceLevel;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Transform.scale(
              scale: 1.12,
              child: Image.asset(avatarAsset, fit: BoxFit.cover),
            ),
          ),
        ),
        ColoredBox(color: const Color(0xFF080B14).withValues(alpha: 0.66)),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _VoiceReactiveAvatar(
                avatarAsset: avatarAsset,
                level: muted ? 0 : voiceLevel,
              ),
              const SizedBox(height: 12),
              Text(
                statusText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VoiceReactiveAvatar extends StatefulWidget {
  const _VoiceReactiveAvatar({required this.avatarAsset, required this.level});

  final String avatarAsset;
  final double level;

  @override
  State<_VoiceReactiveAvatar> createState() => _VoiceReactiveAvatarState();
}

class _VoiceReactiveAvatarState extends State<_VoiceReactiveAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool get _isSpeaking => widget.level > 0.04;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _VoiceReactiveAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.level > 0.04) != _isSpeaking) _syncAnimation();
  }

  void _syncAnimation() {
    if (_isSpeaking) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: Container(
          width: 88,
          height: 88,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.18),
            border: Border.all(color: Colors.white38, width: 2),
          ),
          child: ClipOval(
            child: Image.asset(widget.avatarAsset, fit: BoxFit.cover),
          ),
        ),
        builder: (_, avatar) {
          final phase = _controller.value;
          final strength = widget.level.clamp(0.0, 1.0);
          final shake = math.sin(phase * math.pi * 6) * 2.2 * strength;
          return SizedBox.square(
            dimension: 126,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_isSpeaking) ...[
                  _VoiceRing(phase: phase, strength: strength),
                  _VoiceRing(
                    phase: (phase + 0.5) % 1,
                    strength: strength * 0.72,
                  ),
                ],
                Transform.translate(
                  offset: Offset(shake, -shake * 0.35),
                  child: Transform.scale(
                    scale: 1 + strength * 0.035,
                    child: avatar,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _VoiceRing extends StatelessWidget {
  const _VoiceRing({required this.phase, required this.strength});

  final double phase;
  final double strength;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: ((1 - phase) * strength * 0.72).clamp(0.0, 1.0),
      child: Transform.scale(
        scale: 0.82 + phase * (0.34 + strength * 0.18),
        child: Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 2.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _CallControlDock extends StatelessWidget {
  const _CallControlDock({required this.controller, required this.disabled});

  final VideoMatchingController controller;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    // This dock owns its reactive boundary. Reading these values only from
    // the parent widget left the buttons with their initial disabled state.
    return Obx(() {
      final cameraUnlocked = controller.cameraUnlocked.value;
      final cameraEnabled = controller.localCameraEnabled.value;
      final cameraBusy = controller.cameraToggleInProgress.value;
      final isMuted = controller.isMuted.value;
      final unlockRemaining = controller.cameraUnlockRemainingSeconds.value;

      return Container(
        constraints: const BoxConstraints(maxWidth: 350),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFF111827).withValues(alpha: 0.48),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _DockButton(
              tooltip: isMuted ? 'Bật micro'.tr : 'Tắt micro'.tr,
              icon: isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              onTap: disabled ? null : controller.toggleMute,
            ),
            _DockButton(
              tooltip:
                  cameraUnlocked
                      ? (cameraEnabled ? 'Tắt camera'.tr : 'Bật camera'.tr)
                      : videoMatchingTr(
                        'Có thể mở camera sau ${_shortDuration(unlockRemaining)}',
                      ),
              icon:
                  cameraUnlocked
                      ? (cameraEnabled
                          ? Icons.videocam_rounded
                          : Icons.videocam_off_rounded)
                      : Icons.lock_clock_rounded,
              onTap:
                  disabled || !cameraUnlocked || cameraBusy
                      ? null
                      : controller.toggleCamera,
            ),
            _DockButton(
              tooltip: 'Đổi camera'.tr,
              icon: Icons.cameraswitch_rounded,
              onTap:
                  disabled || !cameraUnlocked || !cameraEnabled || cameraBusy
                      ? null
                      : controller.switchCamera,
            ),
          ],
        ),
      );
    });
  }

  static String _shortDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainder = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainder';
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: Material(
          color:
              enabled
                  ? const Color(0xFF2A3342).withValues(alpha: 0.46)
                  : const Color(0xFF2A3342).withValues(alpha: 0.22),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap:
                enabled
                    ? () {
                      HapticFeedback.lightImpact();
                      onTap!();
                    }
                    : null,
            child: SizedBox.square(
              dimension: 52,
              child: Icon(icon, color: enabled ? Colors.white : Colors.white38),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.foreground = Colors.white,
    this.disabledForeground,
  });

  final String tooltip;
  final IconData icon;
  final Future<void> Function()? onTap;
  final Color foreground;
  final Color? disabledForeground;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.28),
        shape: const CircleBorder(),
        child: IconButton(
          onPressed: onTap == null ? null : () => onTap!(),
          icon: Icon(
            icon,
            color:
                onTap == null
                    ? disabledForeground ?? Colors.white38
                    : foreground,
          ),
        ),
      ),
    );
  }
}

class _CompactAction extends StatelessWidget {
  const _CompactAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onTap == null ? null : () => onTap!(),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.32),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      ),
      icon: Icon(icon, size: 17),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _PeerLikedBadge extends StatelessWidget {
  const _PeerLikedBadge();

  @override
  Widget build(BuildContext context) {
    final maxWidth =
        (MediaQuery.sizeOf(context).width * 0.82).clamp(0.0, 280.0).toDouble();
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFBE185D).withValues(alpha: 0.84),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.heart5, color: Colors.white, size: 16),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                'Đối phương đã thích bạn',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
