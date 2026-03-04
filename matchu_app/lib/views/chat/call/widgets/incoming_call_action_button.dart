import 'package:flutter/material.dart';

class IncomingCallActionButton extends StatelessWidget {
  const IncomingCallActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.isLoading = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !isLoading;

    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(36),
          onTap: enabled ? onTap : null,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: enabled ? color : color.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
            child: Center(
              child:
                  isLoading
                      ? const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.6,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                      : Icon(icon, color: Colors.white, size: 34),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
