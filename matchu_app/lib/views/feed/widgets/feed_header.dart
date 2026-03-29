import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:matchu_app/views/feed/widgets/feed_palette.dart';

class FeedHeader extends StatelessWidget {
  const FeedHeader({
    super.key,
    required this.isRefreshing,
    required this.onRefresh,
    required this.onCreatePost,
  });

  final bool isRefreshing;
  final Future<void> Function() onRefresh;
  final VoidCallback onCreatePost;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = FeedPalette.of(context);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.headerBackground,
            border: Border(bottom: BorderSide(color: palette.border)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child:
                        isRefreshing
                            ? Padding(
                              key: const ValueKey('refreshing'),
                              padding: const EdgeInsets.all(10),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: theme.colorScheme.primary,
                              ),
                            )
                            : IconButton(
                              key: const ValueKey('refresh-button'),
                              tooltip: 'Lam moi bang tin',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => onRefresh(),
                              icon: Icon(
                                Icons.refresh_rounded,
                                color: palette.iconMuted,
                              ),
                            ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'Feed',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                ),
                _HeaderActionButton(
                  icon: Icons.edit_outlined,
                  onTap: onCreatePost,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = FeedPalette.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: palette.surfaceMuted,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.border),
          ),
          child: Icon(icon, size: 20, color: palette.iconPrimary),
        ),
      ),
    );
  }
}
