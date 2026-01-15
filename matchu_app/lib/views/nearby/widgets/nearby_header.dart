import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/nearby/nearby_controller.dart';

class NearbyHeader extends GetView<NearbyController> {
  const NearbyHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Khám phá",
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Container(
            child: IconButton(
              tooltip: "Làm mới",
              icon: const Icon(Icons.refresh),
              onPressed: controller.refresh, // ✅ OK
            ),
          ),
        ],
      ),
    );
  }
}
