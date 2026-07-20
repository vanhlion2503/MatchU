import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:matchu_app/translations/localized_material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/nearby/nearby_controller.dart';
import 'package:matchu_app/models/nearby_user_vm.dart';
import 'package:matchu_app/views/nearby/widgets/nearby_empty_state.dart';
import 'package:matchu_app/views/nearby/widgets/nearby_user_list_item.dart';
import 'package:matchu_app/views/nearby/widgets/nearby_user_list_shimmer.dart';

class NearbyUserList extends StatefulWidget {
  final NearbyController controller;

  const NearbyUserList({super.key, required this.controller});

  @override
  State<NearbyUserList> createState() => _NearbyUserListState();
}

class _NearbyUserListState extends State<NearbyUserList> {
  static const int _initialAvatarPrecacheCount = 6;
  static const double _avatarLogicalSize = 52;
  static const Duration _avatarPrecacheTimeout = Duration(seconds: 4);

  String? _preparedAvatarBatch;
  String? _preparingAvatarBatch;

  NearbyController get controller => widget.controller;

  String _avatarBatchKey(List<NearbyUserVM> users) {
    return users
        .take(_initialAvatarPrecacheCount)
        .map((user) => '${user.uid}:${user.avatarUrl.trim()}')
        .join('|');
  }

  void _scheduleAvatarPrecache(List<NearbyUserVM> users, String batchKey) {
    if (_preparedAvatarBatch == batchKey || _preparingAvatarBatch == batchKey) {
      return;
    }

    _preparingAvatarBatch = batchKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _preparingAvatarBatch != batchKey) return;
      unawaited(_precacheVisibleAvatars(users, batchKey));
    });
  }

  Future<void> _precacheVisibleAvatars(
    List<NearbyUserVM> users,
    String batchKey,
  ) async {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheSize = (_avatarLogicalSize * devicePixelRatio).round();
    final urls =
        users
            .take(_initialAvatarPrecacheCount)
            .map((user) => user.avatarUrl.trim())
            .where((url) => url.isNotEmpty)
            .toSet();

    final futures = urls.map((url) {
      final provider = ResizeImage.resizeIfNeeded(
        cacheSize,
        cacheSize,
        CachedNetworkImageProvider(url),
      );
      return precacheImage(provider, context, onError: (_, __) {});
    });

    // Do not let one slow/broken URL keep the whole Nearby page in shimmer.
    await Future.wait(
      futures,
    ).timeout(_avatarPrecacheTimeout, onTimeout: () => <void>[]);

    if (!mounted || _preparingAvatarBatch != batchKey) return;
    setState(() {
      _preparedAvatarBatch = batchKey;
      _preparingAvatarBatch = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final cardColor =
        isDark
            ? Color.alphaBlend(
              Colors.white.withValues(alpha: 0.05),
              colorScheme.surface,
            )
            : theme.scaffoldBackgroundColor;
    final cardBorderColor =
        isDark
            ? colorScheme.outlineVariant.withValues(alpha: 0.7)
            : colorScheme.outlineVariant.withValues(alpha: 0.75);

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

      final avatarBatchKey = _avatarBatchKey(items);
      if (_preparedAvatarBatch != avatarBatchKey) {
        _scheduleAvatarPrecache(items.toList(growable: false), avatarBatchKey);
        return const NearbyUserListShimmer();
      }

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
                color: cardColor,
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                elevation: isDark ? 0 : 2,
                shadowColor: Colors.black.withValues(alpha: 0.08),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: cardBorderColor),
                  ),
                  child: Column(
                    children: [
                      for (var index = 0; index < items.length; index++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: NearbyUserListItem(user: items[index]),
                        ),
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
