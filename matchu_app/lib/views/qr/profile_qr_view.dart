import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/qr/profile_qr_controller.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/qr/my_qr_tab.dart';
import 'package:matchu_app/views/qr/scan_qr_tab.dart';
import 'package:matchu_app/widgets/back_circle_button.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ProfileQrView extends GetView<ProfileQrController> {
  const ProfileQrView({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 56,
        leading: const Align(
          alignment: Alignment.centerLeft,
          child: BackCircleButton(
            offset: Offset(10, 0),
            size: 44,
            iconSize: 20,
          ),
        ),
        title: Text(
          'Mã QR của tôi',
          style: textTheme.headlineSmall?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Obx(() {
            if (controller.selectedTabIndex.value == 0) {
              return ValueListenableBuilder<MobileScannerState>(
                valueListenable: controller.scannerController,
                builder: (context, scannerState, _) {
                  final isTorchOn = scannerState.torchState == TorchState.on;
                  return IconButton(
                    onPressed: controller.toggleTorch,
                    icon: Icon(
                      Iconsax.flash_1,
                      color:
                          isTorchOn
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface,
                    ),
                  );
                },
              );
            }

            return IconButton(
              onPressed: controller.copyQrPayload,
              icon: const Icon(Iconsax.copy),
            );
          }),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: QrSegmentedTabs(controller: controller),
            ),
            Expanded(
              child: Obx(() {
                final selectedIndex = controller.selectedTabIndex.value;
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child:
                      selectedIndex == 0
                          ? ScanQrTab(
                            key: const ValueKey('scan-tab'),
                            controller: controller,
                          )
                          : MyQrTab(
                            key: const ValueKey('my-qr-tab'),
                            controller: controller,
                          ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class QrSegmentedTabs extends StatelessWidget {
  const QrSegmentedTabs({super.key, required this.controller});

  final ProfileQrController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final backgroundColor = borderColor.withValues(alpha: isDark ? 0.64 : 0.62);

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Obx(() {
        return Row(
          children: [
            Expanded(
              child: _QrSegmentButton(
                label: 'Quét mã',
                isSelected: controller.selectedTabIndex.value == 0,
                onTap: () => controller.changeTab(0),
              ),
            ),
            Expanded(
              child: _QrSegmentButton(
                label: 'Mã của tôi',
                isSelected: controller.selectedTabIndex.value == 1,
                onTap: () => controller.changeTab(1),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _QrSegmentButton extends StatelessWidget {
  const _QrSegmentButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                isSelected ? theme.scaffoldBackgroundColor : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow:
                isSelected
                    ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                    : null,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color:
                  isSelected
                      ? theme.colorScheme.primary
                      : theme.textTheme.bodySmall?.color,
            ),
          ),
        ),
      ),
    );
  }
}
