import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/main/main_controller.dart';
import 'package:matchu_app/views/game/game_view.dart';
import 'package:matchu_app/views/home_view.dart';
import 'package:matchu_app/views/nearby/nearby_view.dart';
import 'package:matchu_app/views/profile/profile_view.dart';
import 'package:matchu_app/views/chat/random_chat_view.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/widgets/main_widget/bottom_half_border_painter.dart';

class MainView extends StatefulWidget {
  const MainView({super.key});

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView>
    with SingleTickerProviderStateMixin {
  final MainController c = Get.put(MainController());

  late AnimationController _centerButtonController;
  late Animation<double> _scaleAnimation;

  final List<Widget> pages = [
    HomeView(),
    NearbyView(),
    RandomChatView(),
    GameView(),
    ProfileView()
  ];

  @override
  void initState() {
    super.initState();

    _centerButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(
        parent: _centerButtonController,
        curve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _centerButtonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Scaffold(
        body: IndexedStack(
          index: c.currentIndex.value,
          children: pages,
        ),

        extendBody: true, // allow floating overlap

        bottomNavigationBar: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 95,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? AppTheme.darkBorder 
                        : AppTheme.lightBorder,
                    width: 1,
                  ),
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
                unselectedItemColor: Theme.of(context).colorScheme.onSurface,
                showSelectedLabels: false,
                showUnselectedLabels: false,

                items: [
                  BottomNavigationBarItem(
                    icon: AnimatedContainer(
                      duration: Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      child: Icon(
                        Iconsax.home_2,
                        size: c.currentIndex.value == 0 ? 32 : 27,
                      ),
                    ),
                    label: "Home",
                  ),

                  BottomNavigationBarItem(
                    icon: AnimatedContainer(
                      duration: Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      child: Icon(
                        Iconsax.location,
                        size: c.currentIndex.value == 1 ? 32 : 27,
                      ),
                    ),
                    label: "Nearby",
                  ),

                  // giữa (giữ chỗ)
                  const BottomNavigationBarItem(
                    icon: SizedBox.shrink(),
                    label: "Center",
                  ),

                  BottomNavigationBarItem(
                    icon: AnimatedContainer(
                      duration: Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      child: Icon(
                        Iconsax.game,
                        size: c.currentIndex.value == 3 ? 32 : 27,
                      ),
                    ),
                    label: "Game",
                  ),

                  BottomNavigationBarItem(
                    icon: AnimatedContainer(
                      duration: Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      child: Icon(
                        Iconsax.profile_circle,
                        size: c.currentIndex.value == 4 ? 32 : 27,
                      ),
                    ),
                    label: "Profile",
                  ),
                ],
              ),
            ),
            // 🔥 FLOATING CENTER BUTTON + WHITE CIRCLE BACKGROUND
            // -----------------------------
            Positioned(
              top: -38,
              left: 0,
              right: 0,
              child: GestureDetector(
                onTap: () {
                  _centerButtonController.forward().then((_) {
                    _centerButtonController.reverse();
                  });
                  c.changePage(2);
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // ◯ Vòng tròn trắng phía sau (KHÔNG ĐỔ BÓNG)
                    CustomPaint(
                      size: const Size(80, 80),
                      painter: BottomHalfBorderPainter(
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? AppTheme.darkBorder 
                            : AppTheme.lightBorder,   // màu viền
                        strokeWidth: 2,       // độ dày viền
                      ),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).brightness == Brightness.dark 
                                ? AppTheme.darkSurface 
                                : AppTheme.lightSurface,
                        ),
                      ),
                    ),

                    // 🔵 Nút xanh (KHÔNG ĐỔ BÓNG)
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.bolt,
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: 35,
                        ),
                      ),
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
