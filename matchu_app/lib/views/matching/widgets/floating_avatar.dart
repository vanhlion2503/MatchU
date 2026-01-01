import 'package:flutter/material.dart';

class FloatingAvatar extends StatefulWidget {
  final String image;
  final double offsetX;
  final int delay;
  final IconData badge;
  final Color badgeColor;

  const FloatingAvatar({
    required this.image,
    required this.offsetX,
    required this.delay,
    required this.badge,
    required this.badgeColor,
  });

  @override
  State<FloatingAvatar> createState() => _FloatingAvatarState();
}

class _FloatingAvatarState extends State<FloatingAvatar>
    with SingleTickerProviderStateMixin {

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose(); // 👈 RẤT QUAN TRỌNG
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final baseDy = (_controller.value - 0.5) * 12;
        final dy = widget.offsetX < 0 ? baseDy : -baseDy;

        return Transform.translate(
          offset: Offset(widget.offsetX, dy),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 56,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 52,
                  backgroundImage: AssetImage(widget.image),
                ),
              ),
              Positioned(
                bottom: 2,
                right: widget.offsetX < 0 ? 2 : null,
                left: widget.offsetX > 0 ? 2 : null,
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.white,
                  child: Icon(
                    widget.badge,
                    size: 18,
                    color: widget.badgeColor,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

}
