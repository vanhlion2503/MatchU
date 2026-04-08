import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/theme/app_theme.dart';

class MainBottomNavigationBar extends StatefulWidget {
  const MainBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.isVisible,
    required this.unreadCount,
    required this.onTabSelected,
    required this.onCenterTap,
  });

  final int currentIndex;
  final bool isVisible;
  final int unreadCount;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onCenterTap;

  @override
  State<MainBottomNavigationBar> createState() =>
      _MainBottomNavigationBarState();
}

class _MainBottomNavigationBarState extends State<MainBottomNavigationBar>
    with TickerProviderStateMixin {
  late final AnimationController _centerSweepController;
  late final AnimationController _visibilityController;
  late final Animation<double> _centerSweepOffset;
  late final Animation<double> _centerIconWiggleAngle;
  late final Animation<double> _visibilityAnimation;
  late final Animation<Offset> _visibilityOffset;

  @override
  void initState() {
    super.initState();

    _centerSweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..repeat();

    _centerSweepOffset = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(-64.0), weight: 18),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -64.0,
          end: 64.0,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 44,
      ),
      TweenSequenceItem(tween: ConstantTween(64.0), weight: 38),
    ]).animate(_centerSweepController);

    _centerIconWiggleAngle = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0), weight: 16),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: -0.12,
        ).chain(CurveTween(curve: Curves.easeOutSine)),
        weight: 8,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -0.12,
          end: 0.10,
        ).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.10,
          end: -0.07,
        ).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -0.07,
          end: 0.04,
        ).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 8,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.04,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeOutSine)),
        weight: 8,
      ),
      TweenSequenceItem(tween: ConstantTween(0), weight: 40),
    ]).animate(_centerSweepController);

    _visibilityController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: widget.isVisible ? 1 : 0,
    );

    _visibilityAnimation = CurvedAnimation(
      parent: _visibilityController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _visibilityOffset = Tween<Offset>(
      begin: const Offset(0, 0.24),
      end: Offset.zero,
    ).animate(_visibilityAnimation);
  }

  @override
  void didUpdateWidget(covariant MainBottomNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isVisible == widget.isVisible) return;

    if (widget.isVisible) {
      if (!_centerSweepController.isAnimating) {
        _centerSweepController.repeat();
      }
      _visibilityController.forward();
      return;
    }

    _centerSweepController.stop(canceled: false);
    _visibilityController.reverse();
  }

  @override
  void dispose() {
    _centerSweepController.dispose();
    _visibilityController.dispose();
    super.dispose();
  }

  void _handleCenterTap() {
    widget.onCenterTap();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: IgnorePointer(
        ignoring: !widget.isVisible,
        child: FadeTransition(
          opacity: _visibilityAnimation,
          child: SlideTransition(
            position: _visibilityOffset,
            child: _buildNavigationBar(context),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationBar(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final isCenterSelected = widget.currentIndex == 2;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      child: Container(
        height: 70,
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
                child: _CenterActionButton(
                  isSelected: isCenterSelected,
                  scheme: scheme,
                  borderColor: borderColor,
                  sweepOffset: _centerSweepOffset,
                  iconWiggleAngle: _centerIconWiggleAngle,
                  onTap: _handleCenterTap,
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

class _CenterActionButton extends StatelessWidget {
  const _CenterActionButton({
    required this.isSelected,
    required this.scheme,
    required this.borderColor,
    required this.sweepOffset,
    required this.iconWiggleAngle,
    required this.onTap,
  });

  final bool isSelected;
  final ColorScheme scheme;
  final Color borderColor;
  final Animation<double> sweepOffset;
  final Animation<double> iconWiggleAngle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 56,
        height: 56,
        padding: const EdgeInsets.all(3.2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.surface,
          border: Border.all(
            color: borderColor.withValues(alpha: 0.72),
            width: 0.4,
          ),
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
                  alpha: isSelected ? 0.32 : 0.20,
                ),
                blurRadius: isSelected ? 16 : 12,
                spreadRadius: isSelected ? 0.6 : 0.1,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipOval(
                    child: AnimatedBuilder(
                      animation: sweepOffset,
                      builder: (context, _) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Transform.translate(
                              offset: Offset(sweepOffset.value, 0),
                              child: Transform.rotate(
                                angle: -0.42,
                                child: Container(
                                  width: 18,
                                  height: 92,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Colors.white.withValues(alpha: 0),
                                        Colors.white.withValues(alpha: 0.10),
                                        Colors.white.withValues(alpha: 0.34),
                                        Colors.white.withValues(alpha: 0.10),
                                        Colors.white.withValues(alpha: 0),
                                      ],
                                      stops: const [0, 0.22, 0.5, 0.78, 1],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: iconWiggleAngle,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: iconWiggleAngle.value,
                    child: child,
                  );
                },
                child: Icon(
                  Iconsax.flash_1,
                  size: 22,
                  color: scheme.onPrimary,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 8,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
