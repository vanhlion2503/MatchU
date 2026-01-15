import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/nearby/nearby_controller.dart';
import 'package:matchu_app/views/nearby/widgets/nearby_discover_tab.dart';
import 'package:matchu_app/views/nearby/widgets/nearby_friends_placeholder.dart';
import 'package:matchu_app/views/nearby/widgets/nearby_header.dart';
import 'package:matchu_app/views/nearby/widgets/nearby_segmented_control.dart';

class NearbyView extends GetView<NearbyController> {
  const NearbyView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const NearbyHeader(),
            const SizedBox(height: 12),
            NearbySegmentedControl(controller: controller),
            const SizedBox(height: 12),
            Expanded(
              child: Obx(() {
                if (controller.selectedTab.value == 0) {
                  return NearbyDiscoverTab(controller: controller);
                }
                return const NearbyFriendsPlaceholder();
              }),
            ),
          ],
        ),
      ),
    );
  }
}
