import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/theme/app_theme.dart';

class MainBottomNavigationBar extends StatefulWidget {
  const MainBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.unreadCount,
    required this.onTabSelected,
    required this.onCenterTap,
  });

  final int currentIndex;
  final int unreadCount;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onCenterTap;

  @override
  State<MainBottomNavigationBar> createState() =>
      _MainBottomNavigationBarState();
}

class _MainBottomNavigationBarState extends State<MainBottomNavigationBar>
    with TickerProviderStateMixin {
  late final AnimationController _centerTapController;
  late final AnimationController _centerIdleController;
  late final Animation<double> _tapScaleAnimation;
  late final Animation<double> _idleScaleAnimation;
  late final Animation<double> _boltSlideAnimation;
  late final Animation<double> _boltRotateAnimation;
  late final Animation<double> _glowOpacityAnimation;

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

  Future<void> _handleCenterTap() async {
    widget.onCenterTap();
    await _centerTapController.forward(from: 0);
    if (mounted) {
      await _centerTapController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final isCenterSelected = widget.currentIndex == 2;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: isDark ? 0.96 : 0.98),
          borderRadius: BorderRadius.circular(36),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: isDark ? 0.02 : 0.72),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _MainNavBarItem(
                icon: Iconsax.home_2,
                isSelected: widget.currentIndex == 0,
                onTap: () => widget.onTabSelected(0),
              ),
            ),
            Expanded(
              child: _MainNavBarItem(
                icon: Iconsax.location,
                isSelected: widget.currentIndex == 1,
                onTap: () => widget.onTabSelected(1),
              ),
            ),
            SizedBox(
              width: 72,
              child: Center(
                child: AnimatedBuilder(
                  animation: _centerIdleController,
                  builder: (context, _) {
                    final glowOpacity =
                        (isDark
                                ? _glowOpacityAnimation.value + 0.10
                                : _glowOpacityAnimation.value)
                            .clamp(0.0, 0.8)
                            .toDouble();

                    return Transform.scale(
                      scale: _idleScaleAnimation.value,
                      child: ScaleTransition(
                        scale: _tapScaleAnimation,
                        child: GestureDetector(
                          onTap: _handleCenterTap,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: 54,
                            height: 54,
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: scheme.surface,
                              border: Border.all(color: borderColor, width: 1),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [scheme.primary, scheme.secondary],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: scheme.primary.withValues(
                                      alpha:
                                          isCenterSelected
                                              ? glowOpacity + 0.08
                                              : glowOpacity * 0.72,
                                    ),
                                    blurRadius:
                                        14 + (_glowOpacityAnimation.value * 14),
                                    spreadRadius: isCenterSelected ? 0.8 : 0.2,
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
                                      color: scheme.onPrimary,
                                      size: 28,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Expanded(
              child: _MainNavBarItem(
                icon: Iconsax.messages,
                isSelected: widget.currentIndex == 3,
                badgeCount: widget.unreadCount,
                onTap: () => widget.onTabSelected(3),
              ),
            ),
            Expanded(
              child: _MainNavBarItem(
                icon: Iconsax.profile_circle,
                isSelected: widget.currentIndex == 4,
                onTap: () => widget.onTabSelected(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MainNavBarItem extends StatelessWidget {
  const _MainNavBarItem({
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final unselectedColor = Theme.of(context).colorScheme.onSurface;
    final selectedColor = AppTheme.primaryColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      icon,
                      size: isSelected ? 24 : 22,
                      color: isSelected ? selectedColor : unselectedColor,
                    ),
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -8,
                    child: _UnreadBadge(count: badgeCount),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
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
}
