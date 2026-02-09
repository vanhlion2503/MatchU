import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/nearby/nearby_controller.dart';
import 'package:matchu_app/theme/app_theme.dart';

class NearbyRangeFilter extends StatelessWidget {
  final NearbyController controller;

  const NearbyRangeFilter({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Obx(() {
      final value = controller.radiusKm.value;

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        decoration: BoxDecoration(
          color: colorScheme.surface,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Phạm vi quét",
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withValues(alpha: 0.9),
                  ),
                ),
                Text(
                  "${value.round()} km",
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,

                // ===== PHẦN ĐÃ KÉO =====
                activeTrackColor: Colors.blueAccent,

                // ===== PHẦN CHƯA KÉO TỚI =====
                inactiveTrackColor: Colors.blueAccent.withValues(alpha: 0.25),

                // ===== THUMB =====
                thumbColor: Colors.white,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 8,
                  elevation: 2,
                ),

                // ===== OVERLAY =====
                overlayColor: Colors.blueAccent.withValues(alpha: 0.08),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),

                trackShape: const RoundedRectSliderTrackShape(),
              ),
              child: Slider(
                min: 1,
                max: 40,
                value: value,
                onChanged: controller.changeRadius,
              ),
            ),
          ],
        ),
      );
    });
  }
}
