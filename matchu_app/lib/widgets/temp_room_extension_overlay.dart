import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/models/temp_room_extension.dart';
import 'package:matchu_app/theme/app_theme.dart';

const _extensionGradient = LinearGradient(
  colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Urgent room-extension affordance shown above temporary-room content.
///
/// It follows the visual language of temp-chat game invites. Users can
/// minimize it into a draggable bubble without dismissing it permanently.
class TempRoomExtensionOverlay extends StatefulWidget {
  const TempRoomExtensionOverlay({
    super.key,
    required this.isVisible,
    required this.remainingSeconds,
    required this.extensionCount,
    required this.isLoading,
    required this.onExtend,
    this.topInset = 8,
  });

  final bool isVisible;
  final int remainingSeconds;
  final int extensionCount;
  final bool isLoading;
  final Future<void> Function() onExtend;
  final double topInset;

  @override
  State<TempRoomExtensionOverlay> createState() =>
      _TempRoomExtensionOverlayState();
}

class _TempRoomExtensionOverlayState extends State<TempRoomExtensionOverlay> {
  static const double _bubbleSize = 68;
  static const double _edgePadding = 8;

  bool _collapsed = false;
  bool _dragging = false;
  Offset? _bubbleOffset;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (!widget.isVisible) {
            return const SizedBox.shrink();
          }

          if (_collapsed) {
            return _buildCollapsed(context, constraints.biggest);
          }
          return _buildExpanded(context);
        },
      ),
    );
  }

  Widget _buildExpanded(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: widget.topInset,
          left: 8,
          right: 8,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: _ExtensionInviteCard(
                extensionCount: widget.extensionCount,
                isLoading: widget.isLoading,
                onHide: () => setState(() => _collapsed = true),
                onExtend: () => _confirmExtension(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCollapsed(BuildContext context, Size availableSize) {
    final offset = _resolvedBubbleOffset(availableSize);
    return Stack(
      children: [
        AnimatedPositioned(
          duration:
              _dragging ? Duration.zero : const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          left: offset.dx,
          top: offset.dy,
          child: Semantics(
            button: true,
            label: 'Mở đề xuất gia hạn'.tr,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _collapsed = false),
              onPanStart: (_) => setState(() => _dragging = true),
              onPanUpdate: (details) {
                setState(() {
                  _bubbleOffset = _clampOffset(
                    offset + details.delta,
                    availableSize,
                  );
                });
              },
              onPanEnd: (_) {
                final current = _resolvedBubbleOffset(availableSize);
                final snapLeft =
                    current.dx + (_bubbleSize / 2) < availableSize.width / 2;
                setState(() {
                  _dragging = false;
                  _bubbleOffset = Offset(
                    snapLeft
                        ? _edgePadding
                        : availableSize.width - _bubbleSize - _edgePadding,
                    current.dy,
                  );
                });
              },
              child: _ExtensionBubble(
                remainingSeconds: widget.remainingSeconds,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Offset _resolvedBubbleOffset(Size availableSize) {
    final current =
        _bubbleOffset ??
        Offset(
          availableSize.width - _bubbleSize - _edgePadding,
          availableSize.height * 0.56,
        );
    final clamped = _clampOffset(current, availableSize);
    _bubbleOffset = clamped;
    return clamped;
  }

  Offset _clampOffset(Offset offset, Size availableSize) {
    final maxX =
        (availableSize.width - _bubbleSize - _edgePadding)
            .clamp(_edgePadding, double.infinity)
            .toDouble();
    final maxY =
        (availableSize.height - _bubbleSize - _edgePadding)
            .clamp(_edgePadding, double.infinity)
            .toDouble();
    return Offset(
      offset.dx.clamp(_edgePadding, maxX),
      offset.dy.clamp(_edgePadding, maxY),
    );
  }

  Future<void> _confirmExtension(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            icon: const Icon(Iconsax.clock, size: 30),
            title: Text('Thêm 5 phút?'.tr),
            content: Text(
              'Chỉ cần một người gia hạn. Phòng sẽ có thêm 5 phút và người gia hạn trả 1 gem.'
                  .tr,
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text('Để sau'.tr),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                icon: Image.asset('assets/icon/gem.png', width: 18, height: 18),
                label: Text('Dùng 1 gem'.tr),
              ),
            ],
          ),
    );
    if (confirmed == true && mounted) {
      await widget.onExtend();
    }
  }
}

class _ExtensionInviteCard extends StatelessWidget {
  const _ExtensionInviteCard({
    required this.extensionCount,
    required this.isLoading,
    required this.onHide,
    required this.onExtend,
  });

  final int extensionCount;
  final bool isLoading;
  final VoidCallback onHide;
  final VoidCallback onExtend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _extensionGradient,
                ),
                child: const Icon(
                  Icons.more_time_rounded,
                  size: 23,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Muốn trò chuyện thêm 5 phút?'.tr,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Chỉ cần một người dùng 1 gem. Phòng còn @remaining lượt gia hạn.'
                          .trParams({
                            'remaining':
                                '${TempRoomExtensionPolicy.maxExtensions - extensionCount}',
                          }),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _GhostButton(
                  label: 'Tạm ẩn'.tr,
                  onTap: isLoading ? null : onHide,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _GradientButton(
                  isLoading: isLoading,
                  onTap: isLoading ? null : onExtend,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color:
                theme.brightness == Brightness.dark
                    ? AppTheme.darkBorder
                    : AppTheme.lightBorder,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.isLoading, required this.onTap});

  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isLoading ? null : _extensionGradient,
            color: isLoading ? theme.colorScheme.surfaceContainerHighest : null,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child:
                isLoading
                    ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Gia hạn • 1 gem'.tr,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
          ),
        ),
      ),
    );
  }
}

class _ExtensionBubble extends StatelessWidget {
  const _ExtensionBubble({required this.remainingSeconds});

  final int remainingSeconds;

  @override
  Widget build(BuildContext context) {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    final time =
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';

    return Container(
      width: _TempRoomExtensionOverlayState._bubbleSize,
      height: _TempRoomExtensionOverlayState._bubbleSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: _extensionGradient,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.72),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.38),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.more_time_rounded, color: Colors.white, size: 21),
          const SizedBox(height: 2),
          Text(
            time,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
