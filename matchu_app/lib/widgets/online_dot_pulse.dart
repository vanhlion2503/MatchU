import 'package:flutter/material.dart';

class OnlineDotPulse extends StatefulWidget {
  final bool online;
  final double size;

  const OnlineDotPulse({
    super.key,
    required this.online,
    this.size = 10,
  });

  @override
  State<OnlineDotPulse> createState() => _OnlineDotPulseState();
}

class _OnlineDotPulseState extends State<OnlineDotPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.online) {
      return _dot(color: Colors.grey);
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        /// Pulse vòng ngoài
        AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            return Container(
              width: widget.size + _controller.value * 8,
              height: widget.size + _controller.value * 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.withOpacity(
                  0.4 * (1 - _controller.value),
                ),
              ),
            );
          },
        ),

        /// Dot chính
        _dot(color: Colors.green),
      ],
    );
  }

  Widget _dot({required Color color}) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: 1.5,
        ),
      ),
    );
  }
}
