import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/notification/notification_inbox_controller.dart';
import 'package:matchu_app/models/notification/app_notification_model.dart';
import 'package:matchu_app/views/feed/widgets/post_ui_helpers.dart';

class NotificationInboxView extends GetView<NotificationInboxController> {
  const NotificationInboxView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thông báo'), centerTitle: false),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final error = controller.errorMessage.value;
        if (error != null) {
          return _NotificationState(
            icon: Iconsax.warning_2,
            title: 'Không thể tải thông báo',
            message: error,
          );
        }

        final allItems = controller.notifications;
        if (allItems.isEmpty) {
          return const _NotificationState(
            icon: Iconsax.notification,
            title: 'Chưa có thông báo',
            message:
                'Các lượt thích, bình luận và cảnh báo uy tín sẽ xuất hiện ở đây.',
          );
        }

        final visibleItems = controller.visibleNotifications;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          itemCount: visibleItems.isEmpty ? 2 : visibleItems.length + 1,
          itemBuilder: (context, index) {
            if (visibleItems.isEmpty && index == 0) {
              return const _InlineEmptyState();
            }

            final footerIndex = visibleItems.isEmpty ? 1 : visibleItems.length;
            if (index == footerIndex) {
              return _NotificationFooter(
                totalCount: allItems.length,
                unreadCount: controller.unreadCount.value,
                selectedFilter: controller.selectedFilter.value,
                onSelectFilter: controller.selectFilter,
                onMarkAllAsRead: controller.markAllAsRead,
              );
            }

            final notification = visibleItems[index];
            return _NotificationCard(
              notification: notification,
              isOpening:
                  controller.openingNotificationId.value == notification.id,
              onTap: () => controller.openNotification(notification),
            );
          },
        );
      }),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.isOpening,
    required this.onTap,
  });

  final AppNotificationModel notification;
  final bool isOpening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isUnread = notification.isUnread;
    final borderColor =
        isUnread
            ? colorScheme.primary.withValues(alpha: 0.45)
            : colorScheme.outlineVariant.withValues(alpha: 0.9);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color:
          isUnread
              ? colorScheme.primary.withValues(alpha: 0.08)
              : theme.cardTheme.color,
      elevation: theme.cardTheme.elevation ?? 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isOpening ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NotificationAvatar(notification: notification),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(
                            right: isUnread || isOpening ? 28 : 0,
                          ),
                          child: Text(
                            notification.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight:
                                  isUnread ? FontWeight.w800 : FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          notification.body,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color,
                            height: 1.35,
                          ),
                        ),
                        if (_penaltyLabel(notification).isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _PenaltyChip(label: _penaltyLabel(notification)),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              Iconsax.clock,
                              size: 14,
                              color: theme.hintColor,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              formatRelativeTime(notification.createdAt),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.hintColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                right: 0,
                top: 0,
                child:
                    isOpening
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: isUnread ? 10 : 0,
                          height: isUnread ? 10 : 0,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _penaltyLabel(AppNotificationModel item) {
    if (item.type != AppNotificationType.moderationPenalty) return '';
    final penalty = item.penalty ?? 0;
    final before = item.reputationBefore;
    final after = item.reputationAfter;
    if (before != null && after != null) {
      return 'Uy tín: $before -> $after${penalty > 0 ? ' (-$penalty)' : ''}';
    }
    if (penalty > 0) return 'Bị trừ $penalty điểm uy tín';
    return 'Cảnh báo tiêu chuẩn cộng đồng';
  }
}

class _NotificationFooter extends StatelessWidget {
  const _NotificationFooter({
    required this.totalCount,
    required this.unreadCount,
    required this.selectedFilter,
    required this.onSelectFilter,
    required this.onMarkAllAsRead,
  });

  final int totalCount;
  final int unreadCount;
  final NotificationInboxFilter selectedFilter;
  final ValueChanged<NotificationInboxFilter> onSelectFilter;
  final VoidCallback onMarkAllAsRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _FooterFilterButton(
                  label: 'Tất cả',
                  count: totalCount,
                  icon: Iconsax.notification,
                  isSelected: selectedFilter == NotificationInboxFilter.all,
                  onPressed: () => onSelectFilter(NotificationInboxFilter.all),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FooterFilterButton(
                  label: 'Chưa đọc',
                  count: unreadCount,
                  icon: Iconsax.sms_notification,
                  isSelected: selectedFilter == NotificationInboxFilter.unread,
                  onPressed:
                      () => onSelectFilter(NotificationInboxFilter.unread),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: unreadCount == 0 ? null : onMarkAllAsRead,
            icon: const Icon(Iconsax.tick_circle, size: 19),
            label: const Text('Đọc tất cả'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              textStyle: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterFilterButton extends StatelessWidget {
  const _FooterFilterButton({
    required this.label,
    required this.count,
    required this.icon,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final int count;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground = isSelected ? colorScheme.onPrimary : colorScheme.primary;

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text('$label ($count)', overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? colorScheme.primary : Colors.transparent,
        foregroundColor: foreground,
        side: BorderSide(
          color:
              isSelected
                  ? colorScheme.primary
                  : colorScheme.primary.withValues(alpha: 0.45),
        ),
        minimumSize: const Size.fromHeight(46),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _NotificationAvatar extends StatelessWidget {
  const _NotificationAvatar({required this.notification});

  final AppNotificationModel notification;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final avatarUrl = notification.actorAvatarUrl?.trim() ?? '';

    if (avatarUrl.isNotEmpty) {
      return CircleAvatar(radius: 22, backgroundImage: NetworkImage(avatarUrl));
    }

    final icon = switch (notification.type) {
      AppNotificationType.postLike => Iconsax.heart,
      AppNotificationType.postComment => Iconsax.message_text,
      AppNotificationType.moderationPenalty => Iconsax.shield_cross,
      AppNotificationType.unknown => Iconsax.notification,
    };
    final color =
        notification.type == AppNotificationType.moderationPenalty
            ? colorScheme.error
            : colorScheme.primary;

    return CircleAvatar(
      radius: 22,
      backgroundColor: color.withValues(alpha: 0.12),
      child: Icon(icon, size: 21, color: color),
    );
  }
}

class _PenaltyChip extends StatelessWidget {
  const _PenaltyChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: Column(
          children: [
            Icon(
              Iconsax.tick_circle,
              size: 34,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 10),
            Text(
              'Không còn thông báo chưa đọc',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Bạn đã xử lý hết các thông báo mới.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationState extends StatelessWidget {
  const _NotificationState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: theme.colorScheme.primary),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
