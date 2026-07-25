import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/models/temp_room_extension.dart';

class TempRoomExtensionPrompt extends StatelessWidget {
  const TempRoomExtensionPrompt({
    super.key,
    required this.extensionCount,
    required this.isLoading,
    required this.onExtend,
    this.onDarkSurface = false,
  });

  final int extensionCount;
  final bool isLoading;
  final Future<void> Function() onExtend;
  final bool onDarkSurface;

  Future<void> _confirm(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            icon: const Icon(Iconsax.clock, size: 30),
            title: Text('Thêm 5 phút?'.tr),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Chỉ cần một người gia hạn. Phòng sẽ có thêm 5 phút và người gia hạn trả 1 gem.'
                      .tr,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                _ExtensionCost(
                  extensionNumber: extensionCount + 1,
                  compact: false,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text('Để sau'.tr),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                icon: Image.asset('assets/icon/gem.png', width: 18, height: 18),
                label: Text('Dùng 1 gem'.tr),
              ),
            ],
          ),
    );
    if (confirmed == true) await onExtend();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground =
        onDarkSurface ? Colors.white : theme.colorScheme.onPrimaryContainer;
    final secondary =
        onDarkSurface
            ? Colors.white.withValues(alpha: 0.72)
            : theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.72);

    return Material(
      color:
          onDarkSurface
              ? Colors.black.withValues(alpha: 0.66)
              : theme.colorScheme.primaryContainer,
      elevation: onDarkSurface ? 0 : 2,
      shadowColor: theme.colorScheme.primary.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color:
              onDarkSurface
                  ? Colors.white24
                  : theme.colorScheme.primary.withValues(alpha: 0.24),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color:
                    onDarkSurface
                        ? Colors.white.withValues(alpha: 0.12)
                        : theme.colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Iconsax.clock, size: 20, color: foreground),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sắp hết thời gian'.tr,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Gia hạn thêm 5 phút'.tr,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: secondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: isLoading ? null : () => _confirm(context),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                minimumSize: const Size(0, 42),
              ),
              child:
                  isLoading
                      ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : _ExtensionCost(
                        extensionNumber: extensionCount + 1,
                        compact: true,
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtensionCost extends StatelessWidget {
  const _ExtensionCost({required this.extensionNumber, required this.compact});

  final int extensionNumber;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/icon/gem.png', width: 18, height: 18),
        const SizedBox(width: 5),
        Text('1', style: style),
        if (!compact) ...[
          const SizedBox(width: 10),
          Text(
            '${'Lượt'.tr} '
            '$extensionNumber/${TempRoomExtensionPolicy.maxExtensions}',
            style: style,
          ),
        ],
      ],
    );
  }
}
