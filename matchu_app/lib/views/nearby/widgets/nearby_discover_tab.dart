import 'package:flutter/material.dart';
import 'package:matchu_app/controllers/nearby/nearby_controller.dart';
import 'package:matchu_app/views/nearby/widgets/nearby_range_filter.dart';
import 'package:matchu_app/views/nearby/widgets/nearby_user_list.dart';

class NearbyDiscoverTab extends StatelessWidget {
  final NearbyController controller;

  const NearbyDiscoverTab({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 4),
        NearbyRangeFilter(controller: controller),
        const SizedBox(height: 12),
        Expanded(
          child: NearbyUserList(controller: controller),
        ),
      ],
    );
  }
}
