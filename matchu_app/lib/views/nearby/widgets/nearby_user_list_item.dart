import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/models/nearby_user_vm.dart';
import 'package:matchu_app/views/profile/other_profile_view.dart';
import 'package:matchu_app/widgets/verified_name_row.dart';

class NearbyUserListItem extends StatelessWidget {
  final NearbyUserVM user;

  const NearbyUserListItem({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final fullName = user.fullname.isNotEmpty ? user.fullname : "Người dùng";
    final nickname = user.nickname.isNotEmpty ? user.nickname : fullName;

    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (user.uid.isEmpty) return;
          Get.to(() => OtherProfileView(userId: user.uid));
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Avatar(avatarUrl: user.avatarUrl, displayName: nickname),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    VerifiedNameRow(
                      isVerified: user.isFaceVerified,
                      badgeSize: 16,
                      child: Text(
                        fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "@$nickname",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.68),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _DistanceBadge(distanceKm: user.distanceKm),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String avatarUrl;
  final String displayName;

  const _Avatar({required this.avatarUrl, required this.displayName});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return CircleAvatar(
      radius: 26,
      backgroundColor: colorScheme.surfaceContainerHighest,
      backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
      child:
          avatarUrl.isEmpty
              ? Text(
                displayName.isEmpty
                    ? "U"
                    : displayName.substring(0, 1).toUpperCase(),
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              )
              : null,
    );
  }
}

class _DistanceBadge extends StatelessWidget {
  final double distanceKm;

  const _DistanceBadge({required this.distanceKm});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _formatDistance(distanceKm),
        style: textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface.withValues(alpha: 0.72),
        ),
      ),
    );
  }

  String _formatDistance(double km) {
    if (km < 1) {
      return "Cách ${(km * 1000).round()}m";
    }
    return "Cách ${km.toStringAsFixed(1)}km";
  }
}
