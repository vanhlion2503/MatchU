import 'package:flutter/material.dart';

class LivenessCheckpoint extends StatelessWidget {
  const LivenessCheckpoint({
    super.key,
    required this.blinkDetected,
    required this.headTurnDetected,
  });

  final bool blinkDetected;
  final bool headTurnDetected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _CheckpointTile(
            label: "Nháy mắt",
            icon: Icons.remove_red_eye_outlined,
            done: blinkDetected,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _CheckpointTile(
            label: "Quay đầu",
            icon: Icons.threesixty,
            done: headTurnDetected,
          ),
        ),
      ],
    );
  }
}

class _CheckpointTile extends StatelessWidget {
  const _CheckpointTile({
    required this.label,
    required this.icon,
    required this.done,
  });

  final String label;
  final IconData icon;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color:
            done
                ? colorScheme.primary.withValues(alpha: 0.12)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: done ? colorScheme.primary : colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : icon,
            size: 19,
            color: done ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
