import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

class HeartRainOverlay {
  static void show(BuildContext context, {int count = 12}) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _HeartRain(
        count: count,
        onFinish: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }
}

class _HeartRain extends StatefulWidget {
  final int count;
  final VoidCallback onFinish;

  const _HeartRain({
    required this.count,
    required this.onFinish,
  });

  @override
  State<_HeartRain> createState() => _HeartRainState();
}

class _HeartRainState extends State<_HeartRain>
    with TickerProviderStateMixin {
  final _rng = Random();
  late final List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();

    _controllers = List.generate(widget.count, (i) {
      final ctrl = AnimationController(
        vsync: this,
        duration: Duration(
          milliseconds: 1200 + _rng.nextInt(800),
        ),
      );

      Future.delayed(Duration(milliseconds: i * 80), () {
        if (mounted) ctrl.forward();
      });

      return ctrl;
    });

    Future.delayed(const Duration(milliseconds: 2400), widget.onFinish);
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return IgnorePointer(
      child: Stack(
        children: List.generate(widget.count, (i) {
          final startX = _rng.nextDouble() * size.width;
          final endX = startX + _rng.nextDouble() * 120 - 60;

          final startY = size.height + 40;
          final endY = _rng.nextDouble() * size.height * 0.3;

          final scale = 0.6 + _rng.nextDouble() * 0.6;

          return AnimatedBuilder(
            animation: _controllers[i],
            builder: (_, __) {
              final t = Curves.easeOutCubic.transform(
                _controllers[i].value,
              );

              return Positioned(
                left: lerpDouble(startX, endX, t)!,
                top: lerpDouble(startY, endY, t)!,
                child: Opacity(
                  opacity: (1 - t).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: scale * (1 + 0.3 * sin(t * pi)),
                    child: const Icon(
                      Icons.favorite,
                      color: Color(0xFFFF5B89),
                      size: 36,
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
