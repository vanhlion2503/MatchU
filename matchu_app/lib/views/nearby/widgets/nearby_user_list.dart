import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/nearby/nearby_controller.dart';
import 'package:matchu_app/views/nearby/widgets/nearby_empty_state.dart';
import 'package:matchu_app/views/nearby/widgets/nearby_user_card.dart';

class NearbyUserList extends StatelessWidget {
  final NearbyController controller;

  const NearbyUserList({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      if (!controller.isLocationVisible.value) {
        return const NearbyEmptyState(
          icon: Icons.visibility_off_rounded,
          title: "Ban dang tat hien thi vi tri",
          subtitle: "Bat lai nut vi tri tren header de xem nguoi gan ban",
        );
      }

      final items = controller.users;
      if (items.isEmpty) {
        return const NearbyEmptyState();
      }

      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        physics: const BouncingScrollPhysics(),
        itemCount: items.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                "Tim thay ${items.length} nguoi gan ban",
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            );
          }

          final user = items[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: NearbyUserCard(user: user),
          );
        },
      );
    });
  }
}
