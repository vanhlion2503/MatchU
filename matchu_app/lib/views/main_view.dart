import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/chat/chat_list_controller.dart';
import 'package:matchu_app/controllers/chat/unread_controller.dart';
import 'package:matchu_app/controllers/main/main_controller.dart';
import 'package:matchu_app/services/security/passcode_backup_service.dart';
import 'package:matchu_app/services/security/session_key_service.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/chat/list_chat/chat_list_view.dart';
import 'package:matchu_app/views/chat/list_chat/passcode_prompt_dialog.dart';
import 'package:matchu_app/views/chat/random_chat_view.dart';
import 'package:matchu_app/views/home_view.dart';
import 'package:matchu_app/views/nearby/nearby_view.dart';
import 'package:matchu_app/views/profile/profile_view.dart';
import 'package:matchu_app/widgets/main_widget/bottom_half_border_painter.dart';

class MainView extends StatefulWidget {
  const MainView({super.key});

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> with TickerProviderStateMixin {
  final MainController c = Get.find<MainController>();
  final UnreadController unreadController = Get.find<UnreadController>();

  late AnimationController _centerTapController;
  late AnimationController _centerIdleController;
  late Animation<double> _tapScaleAnimation;
  late Animation<double> _idleScaleAnimation;
  late Animation<double> _boltSlideAnimation;
  late Animation<double> _boltRotateAnimation;
  late Animation<double> _glowOpacityAnimation;
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

    _centerTapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );

    _tapScaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _centerTapController, curve: Curves.easeOutBack),
    );

    _centerIdleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    final idleCurve = CurvedAnimation(
      parent: _centerIdleController,
      curve: Curves.easeInOut,
    );

    _idleScaleAnimation = Tween<double>(
      begin: 0.98,
      end: 1.04,
    ).animate(idleCurve);
    _boltSlideAnimation = Tween<double>(begin: -1.2, end: 1.6).animate(
      CurvedAnimation(
        parent: _centerIdleController,
        curve: Curves.easeInOutSine,
      ),
    );
    _boltRotateAnimation = Tween<double>(
      begin: -0.08,
      end: 0.08,
    ).animate(idleCurve);
    _glowOpacityAnimation = Tween<double>(
      begin: 0.18,
      end: 0.34,
    ).animate(idleCurve);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensurePasscodeFlow();
    });
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
    _centerTapController.dispose();
    _centerIdleController.dispose();
    super.dispose();
  }

  Widget _buildUnreadBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildNavIcon(
    IconData icon, {
    required bool selected,
    int badgeCount = 0,
  }) {
    final iconWidget = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: Icon(icon, size: selected ? 26 : 24),
    );

    if (badgeCount <= 0) {
      return iconWidget;
    }

    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(child: iconWidget),
          Positioned(top: -4, right: -8, child: _buildUnreadBadge(badgeCount)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bool isDark = Theme.of(context).brightness == Brightness.dark;
      final int unreadCount = unreadController.totalUnread.value;
      final Color borderColor =
          isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
      final Color ringColor =
          isDark ? AppTheme.darkSurface : AppTheme.lightSurface;

      return Scaffold(
        body: IndexedStack(index: c.currentIndex.value, children: pages),
        extendBody: true,
        bottomNavigationBar: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 85,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color:
                        isDark
                            ? Colors.black.withValues(alpha: 0.32)
                            : Colors.black.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withValues(
                      alpha: isDark ? 0.95 : 0.92,
                    ),
                    border: Border(
                      top: BorderSide(color: borderColor, width: 0.9),
                    ),
                  ),
                  child: BottomNavigationBar(
                    enableFeedback: false,
                    type: BottomNavigationBarType.fixed,
                    currentIndex: c.currentIndex.value,
                    onTap: (index) {
                      if (index != 2) c.changePage(index);
                    },
                    selectedItemColor: AppTheme.primaryColor,
                    unselectedItemColor:
                        Theme.of(context).colorScheme.onSurface,
                    showSelectedLabels: false,
                    showUnselectedLabels: false,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    items: [
                      BottomNavigationBarItem(
                        icon: _buildNavIcon(
                          Iconsax.home_2,
                          selected: c.currentIndex.value == 0,
                        ),
                        label: 'Home',
                      ),
                      BottomNavigationBarItem(
                        icon: _buildNavIcon(
                          Iconsax.location,
                          selected: c.currentIndex.value == 1,
                        ),
                        label: 'Nearby',
                      ),
                      const BottomNavigationBarItem(
                        icon: SizedBox.shrink(),
                        label: 'Center',
                      ),
                      BottomNavigationBarItem(
                        icon: _buildNavIcon(
                          Iconsax.messages,
                          selected: c.currentIndex.value == 3,
                          badgeCount: unreadCount,
                        ),
                        label: 'Chat',
                      ),
                      BottomNavigationBarItem(
                        icon: _buildNavIcon(
                          Iconsax.profile_circle,
                          selected: c.currentIndex.value == 4,
                        ),
                        label: 'Profile',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -35,
              left: 0,
              right: 0,
              child: GestureDetector(
                onTap: () {
                  _centerTapController.forward(from: 0).then((_) {
                    if (mounted) {
                      _centerTapController.reverse();
                    }
                  });
                  c.changePage(2);
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(80, 80),
                      painter: BottomHalfBorderPainter(
                        color: borderColor,
                        strokeWidth: 2,
                      ),
                      child: Container(
                        width: 75,
                        height: 75,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ringColor,
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _centerIdleController,
                      builder: (context, _) {
                        final double glowOpacity =
                            (isDark
                                    ? _glowOpacityAnimation.value + 0.10
                                    : _glowOpacityAnimation.value)
                                .clamp(0.0, 0.8)
                                .toDouble();

                        return Transform.scale(
                          scale: _idleScaleAnimation.value,
                          child: ScaleTransition(
                            scale: _tapScaleAnimation,
                            child: Container(
                              width: 65,
                              height: 65,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Theme.of(context).colorScheme.primary,
                                    Theme.of(context).colorScheme.secondary,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: glowOpacity),
                                    blurRadius:
                                        14 + (_glowOpacityAnimation.value * 24),
                                    spreadRadius: 0.8,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Transform.translate(
                                  offset: Offset(0, _boltSlideAnimation.value),
                                  child: Transform.rotate(
                                    angle: _boltRotateAnimation.value,
                                    child: Icon(
                                      Icons.bolt,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
                                      size: 35,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
