import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/nearby/nearby_controller.dart';
import 'package:matchu_app/theme/app_theme.dart';

class NearbySegmentedControl extends StatelessWidget {
  final NearbyController controller;

  const NearbySegmentedControl({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selected = controller.selectedTab.value;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? AppTheme.darkBorder
                : AppTheme.lightBorder,
          ),
          boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  AnimatedAlign(
                    alignment: selected == 0
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _TabItem(
                          title: "Tim quanh đây",
                          isSelected: selected == 0,
                          onTap: () => controller.changeTab(0),
                        ),
                      ),
                      Expanded(
                        child: _TabItem(
                          title: "Vị trí bạn bè",
                          isSelected: selected == 1,
                          onTap: () => controller.changeTab(1),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      );
    });
  }
}

class _TabItem extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabItem({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(4), // khoảng cách giữa các tab
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).brightness == Brightness.dark
                ? Colors.black
                : Colors.white// tab được chọn để highlight phía sau lo
              : Theme.of(context).colorScheme.surface, // 👈 nền trắng cho tab chưa chọn
          borderRadius: BorderRadius.circular(10),
        ),
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: isSelected
                ? colorScheme.onSurface
                : colorScheme.onSurface.withOpacity(0.7),
            textStyle: textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            overlayColor: Colors.transparent,   
            splashFactory: NoSplash.splashFactory,
          ),
          child: Text(title),
        ),
      ),
    );
  }
}

