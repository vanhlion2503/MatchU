import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/views/feed/widgets/feed_palette.dart';

class FeedAppBar extends StatelessWidget implements PreferredSizeWidget {
  static const double _separatorHeight = 6;

  const FeedAppBar({
    super.key,
    required this.isRefreshing,
    required this.onRefresh,
  });

  final bool isRefreshing;
  final Future<void> Function() onRefresh;

  @override
  Size get preferredSize =>
      const Size.fromHeight(kToolbarHeight + _separatorHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = FeedPalette.of(context);

    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 20,
      leading: Container(
        margin: const EdgeInsets.only(left: 12),
        child: IconButton(
          icon: Icon(
            Iconsax.search_normal,
            size: 22,
            color: palette.textPrimary,
          ),
          onPressed: () {
            // TODO: xử lý khi bấm icon trái
          },
        ),
      ),
      title: Text(
        'Bảng tin',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: palette.textPrimary,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(_separatorHeight),
        child: SizedBox(
          height: _separatorHeight,
          child: Padding(
            padding: EdgeInsets.zero,
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                height: 1,
                color: palette.border.withOpacity(0.6),
              ),
            ),
          ),
        ),
      ),
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(color: palette.headerBackground),
          ),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 12),
          child: IconButton(
            icon: Icon(
              Iconsax.notification,
              size: 22,
              color: palette.textPrimary,
            ),
            onPressed: () {
              // TODO: xử lý khi bấm chuông
            },
          ),
        ),
      ],
    );
  }
}
