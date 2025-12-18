import 'package:flutter/material.dart';

class AnimatedMessageBubble extends StatefulWidget {
  final Widget child;
  const AnimatedMessageBubble({super.key, required this.child});

  @override
  State<AnimatedMessageBubble> createState() => _AnimatedMessageBubbleState();
}

class _AnimatedMessageBubbleState extends State<AnimatedMessageBubble> {

  double scale = 0.9;
  double opacity = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      setState(() {
        scale = 1;
        opacity = 1;
      });
    });
  }

  @override
   Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: opacity,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 200),
        scale: scale,
        child: widget.child,
      ),
    );
  }
}