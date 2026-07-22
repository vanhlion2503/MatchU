import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/matching/video_matching_controller.dart';
import 'package:matchu_app/translations/localized_material.dart';
import 'package:matchu_app/translations/video_matching_translations.dart';

enum _ExitChoice { stay, next, leave }

class VideoCallStage extends StatelessWidget {
  const VideoCallStage({super.key, required this.controller});

  final VideoMatchingController controller;

  Future<void> _showExitChoices(BuildContext context) async {
    final choice = await showDialog<_ExitChoice>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rời phòng video?',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Bạn muốn tìm người mới hay kết thúc phiên làm quen?',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 54,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 9,
                          child: _ExitChoiceButton(
                            icon: Icons.pause_rounded,
                            label: 'Ở lại'.tr,
                            kind: _ExitButtonKind.stay,
                            onTap:
                                () => Navigator.of(
                                  dialogContext,
                                ).pop(_ExitChoice.stay),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 10,
                          child: _ExitChoiceButton(
                            icon: Icons.logout_rounded,
                            label: 'Thoát'.tr,
                            kind: _ExitButtonKind.leave,
                            alignLeft: true,
                            onTap:
                                () => Navigator.of(
                                  dialogContext,
                                ).pop(_ExitChoice.leave),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 15,
                          child: _ExitChoiceButton(
                            icon: Iconsax.user_add,
                            label: 'Tìm người mới'.tr,
                            kind: _ExitButtonKind.primary,
                            onTap:
                                () => Navigator.of(
                                  dialogContext,
                                ).pop(_ExitChoice.next),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    switch (choice) {
      case _ExitChoice.next:
        await controller.leaveRoom(findNext: true);
        break;
      case _ExitChoice.leave:
        await controller.leaveRoom(findNext: false);
        break;
      case _ExitChoice.stay:
      case null:
        break;
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
          _ConnectionStatus(controller: controller, lockText: _cameraLockText),
          _CallBottomControls(
            controller: controller,
            onExit: () => _showExitChoices(context),
          ),
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

enum _ExitButtonKind { stay, leave, primary }

class _ExitChoiceButton extends StatelessWidget {
  const _ExitChoiceButton({
    required this.icon,
    required this.label,
    required this.kind,
    required this.onTap,
    this.alignLeft = false,
  });

  final IconData icon;
  final String label;
  final _ExitButtonKind kind;
  final VoidCallback onTap;
  final bool alignLeft;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPrimary = kind == _ExitButtonKind.primary;
    final isLeave = kind == _ExitButtonKind.leave;
    final foreground =
        isPrimary
            ? scheme.onPrimary
            : isLeave
            ? scheme.error
            : scheme.primary;

    return Material(
      color:
          isPrimary
              ? scheme.primary
              : isLeave
              ? scheme.surfaceContainerLow
              : scheme.primary.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color:
              isPrimary
                  ? scheme.primary
                  : isLeave
                  ? scheme.outlineVariant.withValues(alpha: 0.7)
                  : scheme.primary.withValues(alpha: 0.42),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.only(
            left: alignLeft ? 9 : 6,
            right: alignLeft ? 4 : 6,
          ),
          child: Row(
            mainAxisAlignment:
                alignLeft ? MainAxisAlignment.start : MainAxisAlignment.center,
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
            return RepaintBoundary(
              child: _VideoTile(
                renderer: controller.localRenderer,
                label: 'Bạn'.tr,
                avatarAsset:
                    'assets/anonymous/${controller.anonymousAvatar}.png',
                cameraEnabled: controller.localCameraEnabled.value,
                cameraUnlocked: controller.cameraUnlocked.value,
                cameraOffText: 'Camera đang tắt'.tr,
                cameraLockText: lockText(seconds),
                mirror: true,
              ),
            );
          }),
        ),
        Container(height: 1, color: Colors.white24),
        Expanded(
          child: Obx(() {
            final seconds = controller.cameraUnlockRemainingSeconds.value;
            return RepaintBoundary(
              child: _VideoTile(
                renderer: controller.remoteRenderer,
                label: 'Người lạ'.tr,
                rating: controller.otherAvgRating.value,
                labelAtTop: true,
                avatarAsset:
                    'assets/anonymous/${controller.otherAnonymousAvatar.value}.png',
                cameraEnabled: controller.remoteCameraEnabled.value,
                cameraUnlocked: controller.cameraUnlocked.value,
                cameraOffText: 'Camera của đối phương đang tắt'.tr,
                cameraLockText: lockText(seconds),
                mirror: false,
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
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.48),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        controller.formattedRoomTime,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        'Phòng video ẩn danh • tối đa 8 phút'.tr,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.68),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                _GlassIconButton(
                  tooltip: liked ? 'Đã thả tim'.tr : 'Thả tim'.tr,
                  icon: liked ? Iconsax.heart5 : Iconsax.heart,
                  foreground: liked ? const Color(0xFFFF5A83) : Colors.white,
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
  const _CallBottomControls({required this.controller, required this.onExit});

  final VideoMatchingController controller;
  final Future<void> Function() onExit;

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
                _CallControlDock(
                  controller: controller,
                  disabled: ending,
                  onEnd: onExit,
                ),
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
    this.rating,
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
  final double? rating;
  final bool labelAtTop;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (cameraEnabled)
          RTCVideoView(
            renderer,
            mirror: mirror,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          )
        else
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF171925), Color(0xFF111827)],
              ),
            ),
          ),
        if (!cameraEnabled)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                  child: ClipOval(
                    child: Image.asset(avatarAsset, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  cameraUnlocked ? cameraOffText : cameraLockText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                if (labelAtTop) ...[
                  const SizedBox(width: 7),
                  const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFFFC857),
                    size: 15,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    rating?.toStringAsFixed(1) ?? '—',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CallControlDock extends StatelessWidget {
  const _CallControlDock({
    required this.controller,
    required this.disabled,
    required this.onEnd,
  });

  final VideoMatchingController controller;
  final bool disabled;
  final Future<void> Function() onEnd;

  @override
  Widget build(BuildContext context) {
    final cameraUnlocked = controller.cameraUnlocked.value;
    return Container(
      constraints: const BoxConstraints(maxWidth: 350),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _DockButton(
            tooltip: controller.isMuted.value ? 'Bật micro'.tr : 'Tắt micro'.tr,
            icon:
                controller.isMuted.value
                    ? Icons.mic_off_rounded
                    : Icons.mic_rounded,
            onTap: disabled ? null : controller.toggleMute,
          ),
          _DockButton(
            tooltip:
                cameraUnlocked
                    ? (controller.localCameraEnabled.value
                        ? 'Tắt camera'.tr
                        : 'Bật camera'.tr)
                    : videoMatchingTr(
                      'Có thể mở camera sau ${_shortDuration(controller.cameraUnlockRemainingSeconds.value)}',
                    ),
            icon:
                cameraUnlocked
                    ? (controller.localCameraEnabled.value
                        ? Icons.videocam_rounded
                        : Icons.videocam_off_rounded)
                    : Icons.lock_clock_rounded,
            onTap: disabled || !cameraUnlocked ? null : controller.toggleCamera,
          ),
          _DockButton(
            tooltip: 'Kết thúc'.tr,
            icon: Icons.call_end_rounded,
            backgroundColor: const Color(0xFFE33D55),
            onTap: disabled ? null : onEnd,
          ),
          _DockButton(
            tooltip: 'Đổi camera'.tr,
            icon: Icons.cameraswitch_rounded,
            onTap:
                disabled ||
                        !cameraUnlocked ||
                        !controller.localCameraEnabled.value
                    ? null
                    : controller.switchCamera,
          ),
        ],
      ),
    );
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
    this.backgroundColor = const Color(0xFF2A3342),
  });

  final String tooltip;
  final IconData icon;
  final Future<void> Function()? onTap;
  final Color backgroundColor;

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
                  ? backgroundColor
                  : backgroundColor.withValues(alpha: 0.45),
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
  });

  final String tooltip;
  final IconData icon;
  final Future<void> Function()? onTap;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.48),
        shape: const CircleBorder(),
        child: IconButton(
          onPressed: onTap == null ? null : () => onTap!(),
          icon: Icon(icon, color: onTap == null ? Colors.white38 : foreground),
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
        backgroundColor: Colors.black.withValues(alpha: 0.58),
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
