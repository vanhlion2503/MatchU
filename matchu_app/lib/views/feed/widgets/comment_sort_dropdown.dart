import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/feed/post_comments_controller.dart';
import 'package:matchu_app/views/feed/widgets/feed_palette.dart';

class CommentSortDropdown extends StatelessWidget {
  const CommentSortDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final CommentSortMode value;
  final ValueChanged<CommentSortMode?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = FeedPalette.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: palette.surfaceMuted.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<CommentSortMode>(
          value: value,
          onChanged: onChanged,
          isDense: true,
          icon: Icon(Iconsax.arrow_down_1, size: 16, color: palette.iconMuted),
          borderRadius: BorderRadius.circular(16),
          dropdownColor: palette.surface,
          style: theme.textTheme.bodySmall?.copyWith(
            color: palette.textPrimary,
            fontWeight: FontWeight.w700,
          ),
          items: CommentSortMode.values
              .map(
                (mode) => DropdownMenuItem<CommentSortMode>(
                  value: mode,
                  child: Text(mode.label),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}
