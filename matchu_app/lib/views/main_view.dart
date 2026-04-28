import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/chat_list_controller.dart';
import 'package:matchu_app/controllers/chat/unread_controller.dart';
import 'package:matchu_app/controllers/main/main_controller.dart';
import 'package:matchu_app/controllers/system/notification_controller.dart';
import 'package:matchu_app/services/security/passcode_backup_service.dart';
import 'package:matchu_app/views/chat/list_chat/chat_list_view.dart';
import 'package:matchu_app/views/chat/list_chat/passcode_prompt_dialog.dart';
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

class _MainViewState extends State<MainView> with WidgetsBindingObserver {
  final MainController c = Get.find<MainController>();
  final UnreadController unreadController = Get.find<UnreadController>();

  Worker? _tabIndexWorker;
  Worker? _pageIndexWorker;
  bool _passcodeFlowRunning = false;
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
    WidgetsBinding.instance.addObserver(this);
    _lastTabIndex = c.currentIndex.value;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensurePasscodeFlow();
    });

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

  Future<void> _ensurePasscodeFlow() async {
    if (_passcodeFlowRunning) return;
    _passcodeFlowRunning = true;

    try {
      final historyLocked = await PasscodeBackupService.isHistoryLocked();
      if (historyLocked) return;

      final hasLocal = await PasscodeBackupService.hasLocalBackupKey();
      if (hasLocal) return;

      final hasBackup = await PasscodeBackupService.hasBackupOnServer();
      if (!mounted) return;

      if (!hasBackup) {
        final passcode = await showPasscodeSetupDialog(context);
        if (passcode == null || passcode.isEmpty) return;
        await PasscodeBackupService.setPasscode(passcode);
        return;
      }

      String? errorText;
      while (mounted) {
        if (!mounted) return;
        final result = await showPasscodeUnlockDialog(
          context,
          errorText: errorText,
        );

        if (result == null) return;

        if (result.action == PasscodePromptAction.skipped) {
          await PasscodeBackupService.setHistoryLocked(true);
          return;
        }

        if (result.action == PasscodePromptAction.reset) {
          if (!mounted) return;
          final confirm = await showPasscodeResetConfirmDialog(context);
          if (!confirm) continue;

          await PasscodeBackupService.resetPasscode();
          if (Get.isRegistered<ChatListController>()) {
            Get.find<ChatListController>().clearPreviewCache();
          }

          if (!mounted) return;
          final newPasscode = await showPasscodeSetupDialog(context);
          if (newPasscode == null || newPasscode.isEmpty) return;
          await PasscodeBackupService.setPasscode(
            newPasscode,
            lockHistory: true,
          );
          return;
        }

        final passcode = result.passcode ?? '';
        final unlocked = await PasscodeBackupService.unlockPasscode(passcode);
        if (!unlocked) {
          errorText = 'Mã pin không đúng';
          continue;
        }

        if (Get.isRegistered<ChatListController>()) {
          await Get.find<ChatListController>().refreshLastMessagePreviews();
        }
        return;
      }
    } finally {
      _passcodeFlowRunning = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ensurePasscodeFlow();
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
    WidgetsBinding.instance.removeObserver(this);
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
