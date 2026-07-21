import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/chat_list_controller.dart';
import 'package:matchu_app/controllers/chat/chat_user_cache_controller.dart';
import 'package:matchu_app/models/chat_room_model.dart';
import 'package:matchu_app/translations/long_chat_translations.dart';
import 'package:matchu_app/views/chat/list_chat/confirm_delete_chat.dart';

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

Future<void> showChatMoreMenu({
  required BuildContext context,
  required ChatListController controller,
  required ChatRoomModel room,
  required String myUid,
  required Offset position,
}) async {
  final otherUid = room.participants.firstWhere(
    (participant) => participant != myUid,
    orElse: () => '',
  );
  if (otherUid.isEmpty) return;

  final isUnread = room.unreadCount(myUid) > 0;
  final isMuted = controller.isMuted(otherUid);
  final action = await showMenu<_ChatMoreAction>(
    context: context,
    position: _menuPosition(context, position),
    items: [
      PopupMenuItem(
        value: _ChatMoreAction.toggleRead,
        child: _MenuRow(
          icon:
              isUnread
                  ? Icons.mark_email_read_outlined
                  : Icons.mark_email_unread_outlined,
          label: isUnread ? 'Đánh dấu đã đọc' : 'Đánh dấu chưa đọc',
        ),
      ),
      PopupMenuItem(
        value: _ChatMoreAction.toggleMute,
        child: _MenuRow(
          icon:
              isMuted
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
          label: isMuted ? 'Bật thông báo' : 'Tắt thông báo',
        ),
      ),
      const PopupMenuItem(
        value: _ChatMoreAction.delete,
        child: _MenuRow(icon: Icons.delete_outline, label: 'Xóa'),
      ),
      PopupMenuItem(
        value: _ChatMoreAction.block,
        child: _MenuRow(
          icon: Icons.block,
          label: 'Chặn người dùng',
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    ],
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

      final duration = await _showMuteDurationMenu(context, position);
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

Future<_ChatMuteDuration?> _showMuteDurationMenu(
  BuildContext context,
  Offset position,
) {
  return showMenu<_ChatMuteDuration>(
    context: context,
    position: _menuPosition(context, position),
    items: [
      for (final duration in _ChatMuteDuration.values)
        PopupMenuItem(
          value: duration,
          child: _MenuRow(icon: Icons.schedule_outlined, label: duration.label),
        ),
    ],
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

RelativeRect _menuPosition(BuildContext context, Offset position) {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  return RelativeRect.fromRect(
    Rect.fromLTWH(position.dx, position.dy, 1, 1),
    Offset.zero & overlay.size,
  );
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        Icon(icon, size: 21, color: resolvedColor),
        const SizedBox(width: 12),
        Text(
          label.tr,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: resolvedColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
