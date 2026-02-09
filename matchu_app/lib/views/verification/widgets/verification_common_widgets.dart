import 'package:flutter/material.dart';

class FaceVerificationGlassIconButton extends StatelessWidget {
  const FaceVerificationGlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.dark,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Ink(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
              dark
                  ? Colors.white.withValues(alpha: 0.14)
                  : const Color(0xFFF8FAFC),
          border: Border.all(
            color:
                dark
                    ? Colors.white.withValues(alpha: 0.2)
                    : const Color(0xFFE2E8F0),
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: dark ? Colors.white : const Color(0xFF0F172A),
        ),
      ),
    );
  }
}

class FaceVerificationPhoneHomeIndicator extends StatelessWidget {
  const FaceVerificationPhoneHomeIndicator({super.key, required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 128,
        height: 4,
        decoration: BoxDecoration(
          color:
              dark
                  ? Colors.white.withValues(alpha: 0.24)
                  : Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class FaceVerificationSoftCircle extends StatelessWidget {
  const FaceVerificationSoftCircle({
    super.key,
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
