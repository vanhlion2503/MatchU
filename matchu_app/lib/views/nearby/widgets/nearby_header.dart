import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/nearby/nearby_controller.dart';

class NearbyHeader extends GetView<NearbyController> {
  const NearbyHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Kết nối",
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Obx(() {
            final isLocationVisible = controller.isLocationVisible.value;
            final isUpdatingVisibility = controller.isUpdatingVisibility.value;

            return Row(
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: isUpdatingVisibility
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : IconButton(
                            tooltip: isLocationVisible
                                ? "Tắt hiển thị vị trí"
                                : "Bật hiển thị vị trí",
                            icon: Icon(
                              isLocationVisible
                                  ? Icons.location_on_rounded
                                  : Icons.location_off_rounded,
                              color: isLocationVisible
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.error,
                            ),
                            onPressed: () =>
                                controller.setLocationVisibility(!isLocationVisible),
                          ),
                  ),
                ),
                IconButton(
                  tooltip: "Làm mới",
                  icon: const Icon(Icons.refresh),
                  onPressed: controller.refresh,
                ),
              ],
            );
          }),

        ],
      ),
    );
  }
}
