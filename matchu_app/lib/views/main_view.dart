import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/chat_list_controller.dart';
import 'package:matchu_app/controllers/chat/unread_controller.dart';
import 'package:matchu_app/controllers/main/main_controller.dart';
import 'package:matchu_app/controllers/system/notification_controller.dart';
import 'package:matchu_app/services/security/passcode_backup_service.dart';
import 'package:matchu_app/services/security/session_key_service.dart';
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

class _MainViewState extends State<MainView> {
  final MainController c = Get.find<MainController>();
  final UnreadController unreadController = Get.find<UnreadController>();

  Worker? _tabIndexWorker;
  bool _passcodeChecked = false;

  late final List<Widget> pages = const [
    HomeView(),
    NearbyView(),
    RandomChatView(),
    ChatListView(embedInMainNavigation: true),
    ProfileView(),
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensurePasscodeFlow();
    });

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
    if (_passcodeChecked) return;
    _passcodeChecked = true;

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
        if (!confirm) return;

        await PasscodeBackupService.resetPasscode();
        if (Get.isRegistered<ChatListController>()) {
          Get.find<ChatListController>().clearPreviewCache();
        }

        if (!mounted) return;
        final newPasscode = await showPasscodeSetupDialog(context);
        if (newPasscode == null || newPasscode.isEmpty) return;
        await PasscodeBackupService.setPasscode(newPasscode, lockHistory: true);
        return;
      }

      final passcode = result.passcode ?? '';
      final unlocked = await PasscodeBackupService.unlockPasscode(passcode);
      if (!unlocked) {
        errorText = 'Mã pin không đúng';
        continue;
      }

      final restoredRooms = await PasscodeBackupService.restoreAllSessionKeys();
      for (final roomId in restoredRooms) {
        SessionKeyService.notifyUpdated(roomId);
      }
      if (restoredRooms.isNotEmpty && Get.isRegistered<ChatListController>()) {
        await Get.find<ChatListController>().refreshLastMessagePreviews();
      }
      return;
    }
  }

  @override
  void dispose() {
    _tabIndexWorker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final int unreadCount = unreadController.totalUnread.value;

      return Scaffold(
        body: IndexedStack(index: c.currentIndex.value, children: pages),
        extendBody: true,
        bottomNavigationBar: MainBottomNavigationBar(
          currentIndex: c.currentIndex.value,
          unreadCount: unreadCount,
          onTabSelected: c.changePage,
          onCenterTap: () => c.changePage(2),
        ),
      );
    });
  }
}
