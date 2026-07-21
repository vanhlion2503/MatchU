import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

class MutedNotificationIcon extends StatelessWidget {
  const MutedNotificationIcon({super.key, this.size = 18, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor =
        color ?? Theme.of(context).colorScheme.onSurfaceVariant;

    return Semantics(
      label: 'Thông báo đã tắt'.tr,
      child: SizedBox.square(
        dimension: size + 2,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Iconsax.notification, size: size, color: resolvedColor),
            Transform.rotate(
              angle: -0.72,
              child: Container(
                width: size + 3,
                height: 1.7,
                decoration: BoxDecoration(
                  color: resolvedColor,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.surface,
                      spreadRadius: 0.8,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
