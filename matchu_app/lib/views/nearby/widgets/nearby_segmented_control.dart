import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/nearby/nearby_controller.dart';

class NearbySegmentedControl extends StatelessWidget {
  final NearbyController controller;

  const NearbySegmentedControl({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Obx(() {
      final selected = controller.selectedTab.value;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final highlightWidth = (constraints.maxWidth - 8) / 2;

              return Stack(
                children: [
                  AnimatedAlign(
                    alignment: selected == 0
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: Container(
                      width: highlightWidth,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
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
      padding: const EdgeInsets.all(2), // khoảng cách giữa các tab
      child: Container(
        height: 32,
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).brightness == Brightness.dark
                ? Colors.black
                : Colors.white// tab được chọn để highlight phía sau lo
              : colorScheme.surface.withOpacity(0.6), // 👈 nền trắng cho tab chưa chọn
          borderRadius: BorderRadius.circular(10),
        ),
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: isSelected
                ? colorScheme.onSurface
                : colorScheme.onSurface.withOpacity(0.6),
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

