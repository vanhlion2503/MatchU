import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/temp_chat_controller.dart';
import 'package:matchu_app/controllers/game/telepathy/telepathy_controller.dart';
import 'package:matchu_app/theme/app_theme.dart';

const _brandGradient = LinearGradient(
  colors: [Color(0xFFF97316), Color(0xFFEC4899)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class TelepathyInviteBar extends StatelessWidget {
  final TempChatController controller;

  const TelepathyInviteBar({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final telepathy = controller.telepathy;

    return Obx(() {
      final submitting = telepathy.submittingAction.value;

      final loadingAccept =
          submitting == TelepathySubmitAction.accept;
      final loadingDecline =
          submitting == TelepathySubmitAction.decline;

      if (telepathy.status.value != TelepathyStatus.inviting) {
        return const SizedBox.shrink();
      }

      final waiting = telepathy.myConsent.value;
      final otherAccepted = telepathy.otherConsent.value;

      return Container(
        key: ValueKey(telepathy.invitedAt.value),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.14),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _brandGradient,
                  ),
                  child: const Icon(
                    Icons.flash_on,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Thử thách thần giao cách cảm?",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Cùng kiểm tra độ hợp nhau. Cả 2 hãy đồng ý để bắt đầu",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 🔥 USER B: ĐỐI PHƯƠNG ĐÃ ĐỒNG Ý
            if (!waiting && otherAccepted)
              Obx(() {
                return AnimatedScale(
                  scale: telepathy.opponentJustAccepted.value ? 1.06 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Đối phương đã đồng ý 🎉",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

            if (waiting)
              Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      otherAccepted
                          ? "Đối phương đã sẵn sàng ⚡ Chuẩn bị bắt đầu..."
                          : "Đang chờ đối phương đồng ý...",
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  _GhostActionButton(
                    label: "Bỏ qua",
                    icon: Icons.local_fire_department,
                    compact: true,
                    loading: loadingDecline,
                    onTap: submitting == null
                        ? () => telepathy.respond(false)
                        : null,
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _GhostActionButton(
                      label: "Bỏ qua",
                      icon: Icons.local_fire_department,
                      loading: loadingDecline,
                      onTap: submitting == null
                          ? () => telepathy.respond(false)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _GradientActionButton(
                      label: "Đồng ý",
                      icon: Icons.flash_on,
                      loading: loadingAccept,
                      onTap: submitting == null
                          ? () => telepathy.respond(true)
                          : null,
                    ),
                  ),
                ],
              ),
          ],
        ),
      );
    });
  }
}

class _GhostActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool compact;
  final bool loading;

  const _GhostActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.compact = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onTap, // ⛔ disable
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: EdgeInsets.symmetric(
            vertical: compact ? 8 : 12,
            horizontal: compact ? 12 : 14,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.darkBorder
                : AppTheme.lightBorder,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: loading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(
                        theme.colorScheme.primary,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: compact ? 14 : 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}


class _GradientActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool loading;

  const _GradientActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onTap, // ⛔ disable
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: loading ? null : _brandGradient,
            color: loading
                ? theme.colorScheme.surfaceVariant
                : null,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: loading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(
                        theme.colorScheme.primary,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

