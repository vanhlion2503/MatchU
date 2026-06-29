import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/nearby/nearby_controller.dart';
import 'package:matchu_app/views/nearby/widgets/nearby_empty_state.dart';
import 'package:matchu_app/views/nearby/widgets/nearby_user_list_item.dart';
import 'package:matchu_app/views/nearby/widgets/nearby_user_list_shimmer.dart';

class NearbyUserList extends StatelessWidget {
  final NearbyController controller;

  const NearbyUserList({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Obx(() {
      if (controller.isLoading.value) {
        return const NearbyUserListShimmer();
      }

      if (!controller.isLocationVisible.value) {
        return NearbyEmptyState(
          icon: Icons.visibility_off_rounded,
          title: "Bạn đang tắt hiển thị vị trí",
          subtitle: "Bật vị trí để xem những người ở quanh bạn",
          actionLabel: "Bật vị trí",
          actionIcon: Icons.location_on_rounded,
          onActionPressed: () => controller.setLocationVisibility(true),
        );
      }

      final locationError = controller.locationErrorMessage.value;
      if (locationError != null) {
        final canOpenLocationSettings =
            controller.canOpenLocationSettings.value;
        final canOpenAppSettings = controller.canOpenAppSettings.value;

        return NearbyEmptyState(
          icon: Icons.my_location_rounded,
          title: "Không lấy được vị trí",
          subtitle: locationError,
          actionLabel:
              canOpenLocationSettings
                  ? "Bật GPS"
                  : canOpenAppSettings
                  ? "Mở cài đặt"
                  : "Thử lại",
          actionIcon:
              canOpenLocationSettings
                  ? Icons.location_on_rounded
                  : canOpenAppSettings
                  ? Icons.settings_rounded
                  : Icons.refresh_rounded,
          onActionPressed:
              canOpenLocationSettings
                  ? controller.openLocationSettings
                  : canOpenAppSettings
                  ? controller.openAppSettings
                  : controller.retryLocation,
        );
      }

      final items = controller.users;
      if (items.isEmpty) {
        return const NearbyEmptyState();
      }

      final dividerColor = colorScheme.outlineVariant.withValues(alpha: 0.45);

      return CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
            sliver: SliverToBoxAdapter(
              child: Text(
                "Tìm thấy ${items.length} người gần bạn",
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(
              child: Material(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: dividerColor),
                  ),
                  child: Column(
                    children: [
                      for (var index = 0; index < items.length; index++) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: NearbyUserListItem(user: items[index]),
                        ),
                        if (index != items.length - 1)
                          Divider(
                            height: 1,
                            thickness: 1,
                            indent: 82,
                            color: dividerColor,
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      );
    });
  }
}
