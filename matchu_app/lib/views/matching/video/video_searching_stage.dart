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
          const _FloatingProfileBackdrop(),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.18),
                radius: 1.08,
                colors: [Color(0x18071521), Color(0xA607111C)],
                stops: [0.18, 1],
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

class _FloatingProfileBackdrop extends StatefulWidget {
  const _FloatingProfileBackdrop();

  @override
  State<_FloatingProfileBackdrop> createState() =>
      _FloatingProfileBackdropState();
}

class _FloatingProfileBackdropState extends State<_FloatingProfileBackdrop>
    with TickerProviderStateMixin {
  static const _cards = <_FloatingProfileCardSpec>[
    _FloatingProfileCardSpec(
      asset: 'assets/anonymous/avt_02.png',
      alignment: Alignment(-1.08, -0.72),
      width: 62,
      height: 86,
      blur: 14,
      opacity: 0.13,
      scale: 0.87,
      rotationDegrees: -1.8,
      driftX: 5,
      driftY: 12,
      duration: Duration(milliseconds: 7200),
      phase: 0.12,
    ),
    _FloatingProfileCardSpec(
      asset: 'assets/anonymous/avt_07.png',
      alignment: Alignment(1.04, -0.7),
      width: 70,
      height: 96,
      blur: 12,
      opacity: 0.16,
      scale: 0.92,
      rotationDegrees: 1.6,
      driftX: -7,
      driftY: 10,
      duration: Duration(milliseconds: 5800),
      phase: 0.64,
    ),
    _FloatingProfileCardSpec(
      asset: 'assets/anonymous/avt_11.png',
      alignment: Alignment(-0.78, -0.02),
      width: 78,
      height: 106,
      blur: 8,
      opacity: 0.22,
      scale: 1,
      rotationDegrees: -1.2,
      driftX: 8,
      driftY: 14,
      duration: Duration(milliseconds: 4600),
      phase: 0.38,
    ),
    _FloatingProfileCardSpec(
      asset: 'assets/anonymous/avt_15.png',
      alignment: Alignment(0.04, -0.3),
      width: 92,
      height: 122,
      blur: 6,
      opacity: 0.28,
      scale: 1.08,
      rotationDegrees: 0.8,
      driftX: -5,
      driftY: 9,
      duration: Duration(milliseconds: 6400),
      phase: 0.82,
    ),
    _FloatingProfileCardSpec(
      asset: 'assets/anonymous/avt_19.png',
      alignment: Alignment(0.84, 0.04),
      width: 80,
      height: 110,
      blur: 8,
      opacity: 0.22,
      scale: 1.02,
      rotationDegrees: 1.4,
      driftX: 7,
      driftY: 13,
      duration: Duration(milliseconds: 5200),
      phase: 0.24,
    ),
    _FloatingProfileCardSpec(
      asset: 'assets/anonymous/avt_22.png',
      alignment: Alignment(-1.1, 0.74),
      width: 64,
      height: 90,
      blur: 13,
      opacity: 0.12,
      scale: 0.89,
      rotationDegrees: 1.9,
      driftX: -6,
      driftY: 15,
      duration: Duration(milliseconds: 7800),
      phase: 0.52,
    ),
    _FloatingProfileCardSpec(
      asset: 'assets/anonymous/avt_24.png',
      alignment: Alignment(1.08, 0.72),
      width: 68,
      height: 94,
      blur: 11,
      opacity: 0.15,
      scale: 0.93,
      rotationDegrees: -1.7,
      driftX: 9,
      driftY: 11,
      duration: Duration(milliseconds: 6900),
      phase: 0.7,
    ),
  ];

  late final List<AnimationController> _controllers;
  late final List<CurvedAnimation> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = [
      for (final card in _cards)
        AnimationController(vsync: this, duration: card.duration)
          ..value = card.phase
          ..repeat(reverse: true),
    ];
    _animations = [
      for (final controller in _controllers)
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOut,
          reverseCurve: Curves.easeInOut,
        ),
    ];
  }

  @override
  void dispose() {
    for (final animation in _animations) {
      animation.dispose();
    }
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (var index = 0; index < _cards.length; index++)
            _AnimatedFloatingProfileCard(
              spec: _cards[index],
              animation: _animations[index],
            ),
        ],
      ),
    );
  }
}

class _AnimatedFloatingProfileCard extends StatelessWidget {
  const _AnimatedFloatingProfileCard({
    required this.spec,
    required this.animation,
  });

  final _FloatingProfileCardSpec spec;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: spec.alignment,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: animation,
          child: SizedBox(
            width: spec.width,
            height: spec.height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: spec.blur,
                  sigmaY: spec.blur,
                ),
                child: Image.asset(
                  spec.asset,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  cacheWidth: 220,
                ),
              ),
            ),
          ),
          builder: (context, child) {
            final value = animation.value;
            final direction = (value * 2) - 1;
            final animatedScale = spec.scale * (0.985 + (value * 0.03));
            final opacity = spec.opacity * (0.86 + (value * 0.14));
            final rotation =
                (spec.rotationDegrees + (direction * 0.1)) * math.pi / 180;

            return Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(
                  direction * spec.driftX,
                  direction * spec.driftY,
                ),
                child: Transform.rotate(
                  angle: rotation,
                  child: Transform.scale(scale: animatedScale, child: child),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FloatingProfileCardSpec {
  const _FloatingProfileCardSpec({
    required this.asset,
    required this.alignment,
    required this.width,
    required this.height,
    required this.blur,
    required this.opacity,
    required this.scale,
    required this.rotationDegrees,
    required this.driftX,
    required this.driftY,
    required this.duration,
    required this.phase,
  });

  final String asset;
  final Alignment alignment;
  final double width;
  final double height;
  final double blur;
  final double opacity;
  final double scale;
  final double rotationDegrees;
  final double driftX;
  final double driftY;
  final Duration duration;
  final double phase;
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
