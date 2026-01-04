import 'package:flutter/material.dart';

class FloatingAvatar extends StatefulWidget {
  final String image;
  final double offsetX;
  final double size; // 👈 responsive size
  final int delay;
  final IconData badge;
  final Color badgeColor;

  const FloatingAvatar({
    super.key,
    required this.image,
    required this.offsetX,
    required this.size,
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
    );

    // delay animation cho avatar thứ 2
    Future.delayed(Duration(milliseconds: widget.delay * 300), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatarRadius = widget.size / 2;
    final innerRadius = avatarRadius * 0.92;
    final badgeRadius = avatarRadius * 0.28;
    final badgeIconSize = badgeRadius * 1.2;

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final baseDy = (_controller.value - 0.5) * (widget.size * 0.18);
        final dy = widget.offsetX < 0 ? baseDy : -baseDy;

        return Transform.translate(
          offset: Offset(widget.offsetX, dy),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              /// ===== AVATAR =====
              CircleAvatar(
                radius: avatarRadius,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: innerRadius,
                  backgroundImage: AssetImage(widget.image),
                ),
              ),

              /// ===== BADGE =====
              Positioned(
                bottom: avatarRadius * 0.05,
                right: widget.offsetX < 0 ? avatarRadius * 0.05 : null,
                left: widget.offsetX > 0 ? avatarRadius * 0.05 : null,
                child: CircleAvatar(
                  radius: badgeRadius,
                  backgroundColor: Colors.white,
                  child: Icon(
                    widget.badge,
                    size: badgeIconSize,
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
