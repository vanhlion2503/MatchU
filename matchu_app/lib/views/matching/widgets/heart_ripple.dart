import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class HeartRipple extends StatefulWidget {
  const HeartRipple();

  @override
  State<HeartRipple> createState() => _HeartRippleState();
}

class _HeartRippleState extends State<HeartRipple>
    with SingleTickerProviderStateMixin {

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 0.9, end: 1.1)
          .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        width: 55,
        height: 55,
        decoration: BoxDecoration(
          color: Colors.pink,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              blurRadius: 20,
              color: Colors.pink.withOpacity(0.4),
            )
          ],
        ),
        child: const Icon(Iconsax.heart5, color: Colors.white),
      ),
    );
  }
}
