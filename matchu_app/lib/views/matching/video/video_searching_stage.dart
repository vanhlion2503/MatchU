import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/matching/video_matching_controller.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/translations/localized_material.dart';

class VideoSearchingStage extends StatefulWidget {
  const VideoSearchingStage({super.key, required this.controller});

  final VideoMatchingController controller;

  @override
  State<VideoSearchingStage> createState() => _VideoSearchingStageState();
}

class _VideoSearchingStageState extends State<VideoSearchingStage>
    with TickerProviderStateMixin {
  late final AnimationController _motionController;
  late final AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _motionController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final controller = widget.controller;
      final preparing =
          controller.phase.value == VideoMatchingPhase.preparing ||
          !controller.previewReady.value;

      return ColoredBox(
        color: const Color(0xFF090A12),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: _SelfPreview(
                    controller: controller,
                    preparing: preparing,
                    scanAnimation: _scanController,
                  ),
                ),
                Container(height: 1, color: Colors.white12),
                Expanded(
                  child: _DiscoveryField(
                    animation: _motionController,
                    elapsed: controller.formattedSearchTime,
                    onCancel: controller.cancelSearch,
                  ),
                ),
              ],
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _SearchingHeader(animation: _motionController),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _SelfPreview extends StatelessWidget {
  const _SelfPreview({
    required this.controller,
    required this.preparing,
    required this.scanAnimation,
  });

  final VideoMatchingController controller;
  final bool preparing;
  final Animation<double> scanAnimation;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (!preparing)
          RTCVideoView(
            controller.localRenderer,
            mirror: true,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          )
        else
          _BlurredAnonymousPreview(
            avatarAsset: 'assets/anonymous/${controller.anonymousAvatar}.png',
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.34),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.5),
              ],
            ),
          ),
        ),
        // The scan remains visible after the preview is ready to reinforce the
        // active matching state without touching the WebRTC camera lifecycle.
        _CameraScanOverlay(animation: scanAnimation),
        Positioned(
          left: 14,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'Bạn',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BlurredAnonymousPreview extends StatelessWidget {
  const _BlurredAnonymousPreview({required this.avatarAsset});

  final String avatarAsset;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Transform.scale(
            scale: 1.1,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Image.asset(
                avatarAsset,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          ColoredBox(color: const Color(0xFF111320).withValues(alpha: 0.42)),
        ],
      ),
    );
  }
}

class _CameraScanOverlay extends StatelessWidget {
  const _CameraScanOverlay({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            return CustomPaint(
              painter: _CameraScanPainter(animation.value),
              size: Size.infinite,
            );
          },
        ),
      ),
    );
  }
}

class _CameraScanPainter extends CustomPainter {
  const _CameraScanPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final y = progress * size.height;
    final trailTop = math.max(0.0, y - 52);
    final trailHeight = y - trailTop;

    if (trailHeight > 0) {
      final trailRect = Rect.fromLTWH(0, trailTop, size.width, trailHeight);
      canvas.drawRect(
        trailRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0x246FE6FC)],
          ).createShader(trailRect),
      );
    }

    final lineRect = Rect.fromLTWH(12, y - 1, size.width - 24, 2);
    final lineShader = const LinearGradient(
      colors: [
        Colors.transparent,
        Color(0xCC6FE6FC),
        Colors.white,
        Color(0xCC6FE6FC),
        Colors.transparent,
      ],
      stops: [0, 0.16, 0.5, 0.84, 1],
    ).createShader(lineRect);

    canvas.drawLine(
      Offset(12, y),
      Offset(size.width - 12, y),
      Paint()
        ..shader = lineShader
        ..strokeWidth = 5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawLine(
      Offset(12, y),
      Offset(size.width - 12, y),
      Paint()
        ..shader = lineShader
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _CameraScanPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _DiscoveryField extends StatelessWidget {
  const _DiscoveryField({
    required this.animation,
    required this.elapsed,
    required this.onCancel,
  });

  final Animation<double> animation;
  final String elapsed;
  final Future<void> Function() onCancel;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF071521),
                  Color(0xFF0B2A3D),
                  Color(0xFF08121F),
                ],
              ),
            ),
          ),
          Center(
            child: Transform.translate(
              offset: const Offset(0, -30),
              child: AnimatedBuilder(
                animation: animation,
                builder: (context, _) {
                  return CustomPaint(
                    size: const Size.square(260),
                    painter: _PulsePainter(animation.value),
                  );
                },
              ),
            ),
          ),
          _FloatingBlurCard(
            animation: animation,
            phase: 0.0,
            alignment: const Alignment(-0.82, -0.48),
            asset: 'assets/anonymous/avt_04.png',
          ),
          _FloatingBlurCard(
            animation: animation,
            phase: 1.7,
            alignment: const Alignment(0.78, -0.58),
            asset: 'assets/anonymous/avt_12.png',
          ),
          _FloatingBlurCard(
            animation: animation,
            phase: 3.1,
            alignment: const Alignment(-0.68, 0.68),
            asset: 'assets/anonymous/avt_18.png',
          ),
          _FloatingBlurCard(
            animation: animation,
            phase: 4.2,
            alignment: const Alignment(0.72, 0.62),
            asset: 'assets/anonymous/avt_23.png',
          ),
          Center(
            child: Transform.translate(
              offset: const Offset(0, -30),
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.secondaryColor, AppTheme.primaryColor],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.48),
                      blurRadius: 34,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Iconsax.radar_1,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 20,
            child: Column(
              children: [
                const Text(
                  'Đang tìm kiếm...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  elapsed,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 15,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                _CancelSearchButton(onTap: onCancel),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingBlurCard extends StatelessWidget {
  const _FloatingBlurCard({
    required this.animation,
    required this.phase,
    required this.alignment,
    required this.asset,
  });

  final Animation<double> animation;
  final double phase;
  final Alignment alignment;
  final String asset;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final angle = (animation.value * math.pi * 2) + phase;
          return Transform.translate(
            offset: Offset(math.sin(angle) * 9, math.cos(angle) * 7),
            child: Transform.rotate(
              angle: math.sin(angle) * 0.045,
              child: child,
            ),
          );
        },
        child: Opacity(
          opacity: 0.38,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
            child: Container(
              width: 58,
              height: 72,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppTheme.secondaryColor.withValues(alpha: 0.28),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(asset, fit: BoxFit.cover),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  const _PulsePainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    for (var index = 0; index < 4; index++) {
      final wave = (progress + (index / 4)) % 1;
      final radius = 38 + (wave * 92);
      final opacity = (1 - wave) * 0.28;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppTheme.secondaryColor.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PulsePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _SearchingHeader extends StatelessWidget {
  const _SearchingHeader({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF071521).withValues(alpha: 0.64),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.secondaryColor.withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.16),
                blurRadius: 18,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: animation,
                builder: (context, _) {
                  final pulse =
                      0.88 + (math.sin(animation.value * math.pi * 2) * 0.12);
                  return Transform.scale(
                    scale: pulse,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.secondaryColor,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.secondaryColor.withValues(
                              alpha: 0.7,
                            ),
                            blurRadius: 9,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 10),
              const Text(
                'Đang tìm bạn',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CancelSearchButton extends StatelessWidget {
  const _CancelSearchButton({required this.onTap});

  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 46,
      child: FilledButton(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: AppTheme.errorColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
          shape: const StadiumBorder(),
        ),
        onPressed: () => onTap(),
        child: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Hủy tìm kiếm',
            maxLines: 1,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
