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

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkBorder : Color.fromARGB(255, 240, 240, 241),
            borderRadius: BorderRadius.circular(14),
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
              : Theme.of(context).brightness == Brightness.dark ? AppTheme.darkBorder : Color.fromARGB(255, 240, 240, 241), // 👈 nền trắng cho tab chưa chọn
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

