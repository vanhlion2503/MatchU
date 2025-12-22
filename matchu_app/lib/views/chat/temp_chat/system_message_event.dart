import 'package:flutter/material.dart';

class SystemMessageEvent extends StatelessWidget {
  final String text;

  const SystemMessageEvent({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ===== KHOẢNG THỞ PHÍA TRÊN =====
        const SizedBox(height: 12),

        // ===== KHỐI SỰ KIỆN =====
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.error.withOpacity(0.25),
            borderRadius: BorderRadius.circular(18),
            // border: Border.all(
            //   color: theme.colorScheme.primary.withOpacity(0.25),
            // ),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.error.withOpacity(0.8),
            ),
          ),
        ),

        // ===== KHOẢNG THỞ PHÍA DƯỚI =====
        const SizedBox(height: 12),
      ],
    );
  }
}
