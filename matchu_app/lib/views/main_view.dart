import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/unread_controller.dart';
import 'package:matchu_app/controllers/main/main_controller.dart';
import 'package:matchu_app/controllers/system/notification_controller.dart';
import 'package:matchu_app/views/chat/list_chat/chat_list_view.dart';
import 'package:matchu_app/views/chat/random_chat_view.dart';
import 'package:matchu_app/views/home_view.dart';
import 'package:matchu_app/views/main/widgets/main_bottom_navigation_bar.dart';
import 'package:matchu_app/views/nearby/nearby_view.dart';
import 'package:matchu_app/views/profile/profile_view.dart';

class MainView extends StatefulWidget {
  const MainView({super.key});

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  final MainController c = Get.find<MainController>();
  final UnreadController unreadController = Get.find<UnreadController>();

  Worker? _tabIndexWorker;
  Worker? _pageIndexWorker;
  int _lastTabIndex = 0;
  final ValueNotifier<bool> _isHomeBottomNavigationVisible =
      ValueNotifier<bool>(true);

  late final List<Widget> pages = [
    HomeView(
      onBottomNavigationVisibilityChanged:
          _handleHomeBottomNavigationVisibilityChanged,
    ),
    const NearbyView(),
    const RandomChatView(),
    const ChatListView(embedInMainNavigation: true),
    const ProfileView(),
  ];

  @override
  void initState() {
    super.initState();
    _lastTabIndex = c.currentIndex.value;

    _pageIndexWorker = ever<int>(c.currentIndex, _handlePageIndexChanged);

    if (Get.isRegistered<NotificationController>()) {
      final notificationController = Get.find<NotificationController>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !Get.isRegistered<NotificationController>()) return;
        notificationController.flushPendingNavigation(allowMainRedirect: true);
      });
      _tabIndexWorker = ever<int>(
        c.currentIndex,
        notificationController.setMainTabIndex,
      );
      notificationController.setMainTabIndex(c.currentIndex.value);
    }
  }

  void _handlePageIndexChanged(int index) {
    if (_lastTabIndex == index) return;

    _lastTabIndex = index;
    if (_isHomeBottomNavigationVisible.value) return;

    _isHomeBottomNavigationVisible.value = true;
  }

  void _handleHomeBottomNavigationVisibilityChanged(bool isVisible) {
    if (c.currentIndex.value != 0) return;
    if (_isHomeBottomNavigationVisible.value == isVisible) return;

    _isHomeBottomNavigationVisible.value = isVisible;
  }

  @override
  void dispose() {
    _tabIndexWorker?.dispose();
    _pageIndexWorker?.dispose();
    _isHomeBottomNavigationVisible.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Obx(() {
            final int currentIndex = c.currentIndex.value;
            return IndexedStack(index: currentIndex, children: pages);
          }),
          Align(
            alignment: Alignment.bottomCenter,
            child: ValueListenableBuilder<bool>(
              valueListenable: _isHomeBottomNavigationVisible,
              builder: (context, isHomeBottomNavigationVisible, _) {
                return Obx(() {
                  final int currentIndex = c.currentIndex.value;
                  final int unreadCount = unreadController.totalUnread.value;
                  final bool isBottomNavigationVisible =
                      currentIndex == 0 ? isHomeBottomNavigationVisible : true;

                  return MainBottomNavigationBar(
                    currentIndex: currentIndex,
                    isVisible: isBottomNavigationVisible,
                    unreadCount: unreadCount,
                    onTabSelected: c.changePage,
                    onCenterTap: () => c.changePage(2),
                  );
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
