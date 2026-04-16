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

    return PopupMenuButton<CommentSortMode>(
      tooltip: 'Sắp xếp bình luận',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 3),
      splashRadius: 20,
      color: palette.surface,
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      constraints: const BoxConstraints(minWidth: 80),
      onSelected: (mode) => onChanged(mode),
      itemBuilder:
          (context) => CommentSortMode.values
              .map(
                (mode) => PopupMenuItem<CommentSortMode>(
                  value: mode,
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 18,
                        child:
                            mode == value
                                ? Icon(
                                  Iconsax.tick_circle5,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                )
                                : null,
                      ),
                      const SizedBox(width: 16),
                      Text(
                        mode.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: palette.textPrimary,
                          fontWeight:
                              mode == value ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(growable: false),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                value.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Iconsax.arrow_down_1, size: 16, color: palette.iconMuted),
          ],
        ),
      ),
    );
  }
}
