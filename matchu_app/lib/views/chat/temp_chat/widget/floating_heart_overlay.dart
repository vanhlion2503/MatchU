import 'dart:math';
import 'package:flutter/material.dart';

class FloatingHeartOverlay {
  static void show(BuildContext context) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _FloatingHeart(
        onFinish: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }
}

class _FloatingHeart extends StatefulWidget {
  final VoidCallback onFinish;
  const _FloatingHeart({required this.onFinish});

  @override
  State<_FloatingHeart> createState() => _FloatingHeartState();
}

class _FloatingHeartState extends State<_FloatingHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _y;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _y = Tween(begin: 0.0, end: -200.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.6, end: 1.2), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 60),
    ]).animate(_controller);

    _opacity = Tween(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0),
      ),
    );

    _controller.forward().whenComplete(widget.onFinish);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          return Positioned(
            left: size.width / 2 - 24,
            bottom: 120 + _y.value,
            child: Opacity(
              opacity: _opacity.value,
              child: Transform.scale(
                scale: _scale.value,
                child: const Icon(
                  Icons.favorite,
                  color: Color(0xFFFF5B89),
                  size: 48,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
