import 'dart:ui';

import 'package:matchu_app/translations/localized_material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/routes/app_router.dart';
import 'package:matchu_app/services/notification/notification_repository.dart';
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
                tabs: [
                  Tab(text: 'Nổi bật'.tr),
                  Tab(text: 'Mới nhất'.tr),
                  Tab(text: 'Đã theo dõi'.tr),
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
          child: _NotificationActionButton(palette: palette),
        ),
      ],
    );
  }
}

class _NotificationActionButton extends StatelessWidget {
  _NotificationActionButton({required this.palette});

  final FeedPalette palette;
  final NotificationRepository _repository = NotificationRepository();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<int>(
      stream: _repository.watchUnreadCount(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(
                Iconsax.notification,
                size: 22,
                color: palette.textPrimary,
              ),
              onPressed: () => Get.toNamed(AppRouter.notifications),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 5,
                top: 8,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 17),
                  height: 17,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorScheme.error,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: palette.headerBackground,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
