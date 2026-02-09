import 'package:flutter/material.dart';

class FaceVerificationScanningAvatar extends StatefulWidget {
  const FaceVerificationScanningAvatar({
    super.key,
    required this.size,
    required this.lineColor,
  });

  final double size;
  final Color lineColor;

  @override
  State<FaceVerificationScanningAvatar> createState() =>
      _FaceVerificationScanningAvatarState();
}

class _FaceVerificationScanningAvatarState
    extends State<FaceVerificationScanningAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Icon(
              Icons.account_circle_outlined,
              color: Colors.white.withValues(alpha: 0.24),
              size: widget.size * 0.78,
            ),
          ),
          ClipOval(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final travel = widget.size - 28;
                final top = (_controller.value * travel) - 14;
                return Stack(
                  children: [
                    Positioned(
                      left: 16,
                      right: 16,
                      top: top,
                      child: Container(
                        height: 24,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              widget.lineColor.withValues(alpha: 0),
                              widget.lineColor.withValues(alpha: 0.82),
                              widget.lineColor.withValues(alpha: 0),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: widget.lineColor.withValues(alpha: 0.5),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
