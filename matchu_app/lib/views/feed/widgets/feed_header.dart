import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/views/feed/widgets/feed_palette.dart';

class FeedAppBar extends StatelessWidget implements PreferredSizeWidget {
  static const double _separatorHeight = 6;
  static const double _tabBarHeight = 46;

  const FeedAppBar({
    super.key,
    required this.isRefreshing,
    required this.onRefresh,
    required this.tabController,
    required this.onTabTap,
  });

  final bool isRefreshing;
  final Future<void> Function() onRefresh;
  final TabController tabController;
  final ValueChanged<int> onTabTap;

  @override
  Size get preferredSize =>
      const Size.fromHeight(kToolbarHeight + _tabBarHeight + _separatorHeight);

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
            // TODO: xu ly khi bam icon trai
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
        preferredSize: const Size.fromHeight(_tabBarHeight + _separatorHeight),
        child: Column(
          children: [
            SizedBox(
              height: _separatorHeight,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  height: 1,
                  color: palette.border.withValues(alpha: 0.8),
                ),
              ),
            ),
            SizedBox(
              height: _tabBarHeight,
              child: TabBar(
                controller: tabController,
                onTap: onTabTap,
                dividerColor: palette.border.withValues(alpha: 0.8),
                splashFactory: NoSplash.splashFactory,
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorWeight: 2.4,
                indicatorColor: theme.colorScheme.primary,
                labelColor: palette.textPrimary,
                unselectedLabelColor: palette.textTertiary,
                labelStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(text: 'Nổi bật'),
                  Tab(text: 'Mới nhất'),
                  Tab(text: 'Đã theo dõi'),
                ],
              ),
            ),
          ],
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
              // TODO: xu ly khi bam chuong
            },
          ),
        ),
      ],
    );
  }
}
