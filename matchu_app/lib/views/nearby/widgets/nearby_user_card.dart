import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/models/nearby_user_vm.dart';
import 'package:matchu_app/views/profile/other_profile_view.dart';

class NearbyUserCard extends StatelessWidget {
  final NearbyUserVM user;

  const NearbyUserCard({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final isOnline = user.activeStatus == "online";
    final fullName = user.fullname.isNotEmpty ? user.fullname : "Người dùng";
    final nickname = user.nickname.isNotEmpty ? user.nickname : fullName;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          if (user.uid.isEmpty) return;
          Get.to(() => OtherProfileView(userId: user.uid));
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(
                avatarUrl: user.avatarUrl,
                isOnline: isOnline,
                displayName: nickname,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _DistanceBadge(distanceKm: user.distanceKm),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "@"+nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String avatarUrl;
  final bool isOnline;
  final String displayName;

  const _Avatar({
    required this.avatarUrl,
    required this.isOnline,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: colorScheme.surfaceVariant,
          backgroundImage:
              avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
          child: avatarUrl.isEmpty
              ? Text(
                  displayName.isEmpty
                      ? "U"
                      : displayName.substring(0, 1).toUpperCase(),
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                )
              : null,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: isOnline
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              shape: BoxShape.circle,
              border: Border.all(
                color: colorScheme.surface,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DistanceBadge extends StatelessWidget {
  final double distanceKm;

  const _DistanceBadge({
    required this.distanceKm,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _formatDistance(distanceKm),
        style: textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSecondaryContainer,
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
