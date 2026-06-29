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

    final isOnline = user.activeStatus == "online";
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
              _Avatar(
                avatarUrl: user.avatarUrl,
                isOnline: isOnline,
                displayName: nickname,
              ),
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            "@$nickname",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.68,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusDot(isOnline: isOnline),
                        const SizedBox(width: 4),
                        Text(
                          isOnline ? "Online" : "Offline",
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(
                              alpha: 0.58,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _DistanceBadge(distanceKm: user.distanceKm),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colorScheme.onSurface.withValues(alpha: 0.34),
              ),
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
          backgroundColor: colorScheme.surfaceContainerHighest,
          backgroundImage:
              avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
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
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color:
                  isOnline ? colorScheme.primary : colorScheme.outlineVariant,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).scaffoldBackgroundColor,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusDot extends StatelessWidget {
  final bool isOnline;

  const _StatusDot({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: isOnline ? colorScheme.primary : colorScheme.outline,
        shape: BoxShape.circle,
      ),
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
