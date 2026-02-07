import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/main/main_controller.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/chat/random_chat_view.dart';
import 'package:matchu_app/views/game/game_view.dart';
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
  final MainController c = Get.put(MainController());

  late AnimationController _centerTapController;
  late AnimationController _centerIdleController;
  late Animation<double> _tapScaleAnimation;
  late Animation<double> _idleScaleAnimation;
  late Animation<double> _boltSlideAnimation;
  late Animation<double> _boltRotateAnimation;
  late Animation<double> _glowOpacityAnimation;

  final List<Widget> pages = [
    HomeView(),
    NearbyView(),
    RandomChatView(),
    GameView(),
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
  }

  @override
  void dispose() {
    _centerTapController.dispose();
    _centerIdleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bool isDark = Theme.of(context).brightness == Brightness.dark;
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
              height: 95,
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
                        icon: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                          child: Icon(
                            Iconsax.home_2,
                            size: c.currentIndex.value == 0 ? 32 : 27,
                          ),
                        ),
                        label: 'Home',
                      ),
                      BottomNavigationBarItem(
                        icon: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                          child: Icon(
                            Iconsax.location,
                            size: c.currentIndex.value == 1 ? 32 : 27,
                          ),
                        ),
                        label: 'Nearby',
                      ),
                      const BottomNavigationBarItem(
                        icon: SizedBox.shrink(),
                        label: 'Center',
                      ),
                      BottomNavigationBarItem(
                        icon: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                          child: Icon(
                            Iconsax.game,
                            size: c.currentIndex.value == 3 ? 32 : 27,
                          ),
                        ),
                        label: 'Game',
                      ),
                      BottomNavigationBarItem(
                        icon: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                          child: Icon(
                            Iconsax.profile_circle,
                            size: c.currentIndex.value == 4 ? 32 : 27,
                          ),
                        ),
                        label: 'Profile',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -38,
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
                        width: 80,
                        height: 80,
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
                              width: 68,
                              height: 68,
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
