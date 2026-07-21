import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/chat/chat_list_controller.dart';
import 'package:matchu_app/controllers/chat/chat_user_cache_controller.dart';
import 'package:matchu_app/models/chat_room_model.dart';
import 'package:matchu_app/translations/long_chat_translations.dart';
import 'package:matchu_app/views/chat/list_chat/confirm_delete_chat.dart';
import 'package:matchu_app/views/chat/list_chat/muted_notification_icon.dart';

enum _ChatMoreAction { toggleRead, toggleMute, delete, block }

enum _ChatMuteDuration { minutes30, hour1, hours3, hours8, untilTurnedOn }

extension on _ChatMuteDuration {
  Duration? get duration {
    return switch (this) {
      _ChatMuteDuration.minutes30 => const Duration(minutes: 30),
      _ChatMuteDuration.hour1 => const Duration(hours: 1),
      _ChatMuteDuration.hours3 => const Duration(hours: 3),
      _ChatMuteDuration.hours8 => const Duration(hours: 8),
      _ChatMuteDuration.untilTurnedOn => null,
    };
  }

  String get label {
    return switch (this) {
      _ChatMuteDuration.minutes30 => '30 phút',
      _ChatMuteDuration.hour1 => '1 giờ',
      _ChatMuteDuration.hours3 => '3 giờ',
      _ChatMuteDuration.hours8 => '8 giờ',
      _ChatMuteDuration.untilTurnedOn => 'Cho đến khi bật lại',
    };
  }
}

Future<void> showChatMoreBottomSheet({
  required BuildContext context,
  required ChatListController controller,
  required ChatRoomModel room,
  required String myUid,
}) async {
  final otherUid = room.participants.firstWhere(
    (participant) => participant != myUid,
    orElse: () => '',
  );
  if (otherUid.isEmpty) return;

  final isUnread = room.unreadCount(myUid) > 0;
  final isMuted = controller.isMuted(otherUid);
  final action = await showModalBottomSheet<_ChatMoreAction>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder:
        (sheetContext) => _ChatActionsSheet(
          isUnread: isUnread,
          isMuted: isMuted,
          onSelected: (action) => Navigator.of(sheetContext).pop(action),
          onCancel: () => Navigator.of(sheetContext).pop(),
        ),
  );

  if (!context.mounted || action == null) return;

  switch (action) {
    case _ChatMoreAction.toggleRead:
      await _runAction(context, () => controller.toggleReadState(room));
      return;
    case _ChatMoreAction.toggleMute:
      if (isMuted) {
        await _runAction(context, () => controller.unmuteUser(otherUid));
        return;
      }

      final duration = await _showMuteDurationBottomSheet(context);
      if (!context.mounted || duration == null) return;
      await _runAction(
        context,
        () => controller.muteUser(otherUid, duration: duration.duration),
      );
      return;
    case _ChatMoreAction.delete:
      await showConfirmDeleteChat(
        onConfirm: () {
          unawaited(_runAction(context, () => controller.delete(room)));
        },
      );
      return;
    case _ChatMoreAction.block:
      if (!await _confirmBlock(context, otherUid)) return;
      if (!context.mounted) return;
      await _runAction(context, () async {
        await controller.block(room);
      });
  }
}

Future<_ChatMuteDuration?> _showMuteDurationBottomSheet(BuildContext context) {
  return showModalBottomSheet<_ChatMuteDuration>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder:
        (sheetContext) => _MuteDurationSheet(
          onSelected: (duration) => Navigator.of(sheetContext).pop(duration),
        ),
  );
}

Future<bool> _confirmBlock(BuildContext context, String otherUid) async {
  final cache = Get.find<ChatUserCacheController>();
  final user = cache.getUser(otherUid) ?? await cache.loadIfNeeded(otherUid);
  if (!context.mounted) return false;
  final name = user?.fullname.trim();
  final displayName = name == null || name.isEmpty ? 'người dùng này'.tr : name;

  return await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: Text('Chặn người dùng?'.tr),
              content: Text(
                '${'Bạn có muốn chặn'.tr} $displayName? '
                '${'Sau khi chặn, hai người sẽ không thể nhắn tin cho nhau.'.tr}',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text('Hủy'.tr),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text('Chặn'.tr),
                ),
              ],
            ),
      ) ??
      false;
}

Future<void> _runAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (_) {
    if (!context.mounted) return;
    Get.snackbar(
      longChatTr('Không thể thực hiện thao tác.'),
      longChatTr('Vui lòng thử lại.'),
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
    );
  }
}

class _ChatActionsSheet extends StatelessWidget {
  const _ChatActionsSheet({
    required this.isUnread,
    required this.isMuted,
    required this.onSelected,
    required this.onCancel,
  });

  final bool isUnread;
  final bool isMuted;
  final ValueChanged<_ChatMoreAction> onSelected;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;

    return _SheetContent(
      title: 'Tùy chọn'.tr,
      children: [
        _SheetActionTile(
          icon: Icon(
            isUnread ? Iconsax.message_tick : Iconsax.message,
            size: 23,
          ),
          label: (isUnread ? 'Đánh dấu đã đọc' : 'Đánh dấu chưa đọc').tr,
          onTap: () => onSelected(_ChatMoreAction.toggleRead),
        ),
        _SheetActionTile(
          icon:
              isMuted
                  ? const Icon(Iconsax.notification_bing, size: 23)
                  : const MutedNotificationIcon(size: 22),
          label: (isMuted ? 'Bật thông báo' : 'Tắt thông báo').tr,
          onTap: () => onSelected(_ChatMoreAction.toggleMute),
        ),
        _SheetActionTile(
          icon: Icon(Iconsax.trash, size: 23, color: errorColor),
          label: 'Xóa'.tr,
          color: errorColor,
          onTap: () => onSelected(_ChatMoreAction.delete),
        ),
        _SheetActionTile(
          icon: Icon(Iconsax.forbidden, size: 23, color: errorColor),
          label: 'Chặn người dùng'.tr,
          color: errorColor,
          onTap: () => onSelected(_ChatMoreAction.block),
        ),
        _SheetActionTile(
          icon: const Icon(Iconsax.close_circle, size: 23),
          label: 'Hủy'.tr,
          onTap: onCancel,
        ),
      ],
    );
  }
}

class _MuteDurationSheet extends StatelessWidget {
  const _MuteDurationSheet({required this.onSelected});

  final ValueChanged<_ChatMuteDuration> onSelected;

  @override
  Widget build(BuildContext context) {
    return _SheetContent(
      title: 'Tắt thông báo trong'.tr,
      children: [
        for (final duration in _ChatMuteDuration.values)
          _SheetActionTile(
            icon: const Icon(Iconsax.clock, size: 23),
            label: duration.label.tr,
            onTap: () => onSelected(duration),
          ),
      ],
    );
  }
}

class _SheetContent extends StatelessWidget {
  const _SheetContent({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        12 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _SheetActionTile extends StatelessWidget {
  const _SheetActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final Widget icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? Theme.of(context).colorScheme.onSurface;

    return ListTile(
      minTileHeight: 54,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: IconTheme(
        data: IconThemeData(color: resolvedColor, size: 23),
        child: SizedBox.square(dimension: 26, child: Center(child: icon)),
      ),
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: resolvedColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
    );
  }
}
