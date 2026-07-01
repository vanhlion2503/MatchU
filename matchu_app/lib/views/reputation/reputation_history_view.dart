import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/reputation/reputation_controller.dart';
import 'package:matchu_app/models/reputation_daily_state.dart';

class ReputationHistoryView extends StatefulWidget {
  const ReputationHistoryView({super.key});

  @override
  State<ReputationHistoryView> createState() => _ReputationHistoryViewState();
}

class _ReputationHistoryViewState extends State<ReputationHistoryView> {
  late final ReputationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        Get.isRegistered<ReputationController>()
            ? Get.find<ReputationController>()
            : Get.put(ReputationController());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: Text("Lịch sử uy tín", style: theme.textTheme.headlineMedium),
        actions: [
          IconButton(
            tooltip: "Làm mới",
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.loadHistory(force: true),
          ),
        ],
      ),
      body: Obx(() {
        if (_controller.isLoadingHistory.value &&
            _controller.historyItems.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final error = _controller.historyErrorMessage.value;
        if (error != null && _controller.historyItems.isEmpty) {
          return _HistoryMessage(
            icon: Iconsax.warning_2,
            title: "Không tải được lịch sử",
            message: error,
            actionLabel: "Thử lại",
            onAction: () => _controller.loadHistory(force: true),
          );
        }

        if (_controller.historyItems.isEmpty) {
          return const _HistoryMessage(
            icon: Iconsax.receipt_text,
            title: "Chưa có lịch sử",
            message: "Các lần cộng hoặc trừ điểm uy tín sẽ hiển thị tại đây.",
          );
        }

        return RefreshIndicator(
          onRefresh: () => _controller.loadHistory(force: true),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            itemCount: _controller.historyItems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return _HistoryTile(item: _controller.historyItems[index]);
            },
          ),
        );
      }),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item});

  final ReputationHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        item.isPenalty ? theme.colorScheme.error : const Color(0xFF1E9E55);
    final bgColor = color.withValues(alpha: 0.1);
    final pointsText = item.points > 0 ? "+${item.points}" : "${item.points}";
    final description = item.description.trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(
              item.isPenalty ? Iconsax.warning_2 : Iconsax.add_circle,
              color: color,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      pointsText,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _MetaChip(text: _formatDateTime(item.createdAtMillis)),
                    _MetaChip(
                      text:
                          "${item.reputationBefore} -> ${item.reputationAfter}",
                    ),
                    if (item.severity != null)
                      _MetaChip(text: _severityLabel(item.severity!)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatDateTime(int millis) {
  if (millis <= 0) return "Không rõ thời gian";
  final date = DateTime.fromMillisecondsSinceEpoch(millis);
  final now = DateTime.now();
  final isToday =
      date.year == now.year && date.month == now.month && date.day == now.day;
  final minute = date.minute.toString().padLeft(2, "0");
  final time = "${date.hour}:$minute";
  if (isToday) return "Hôm nay $time";
  return "${date.day}/${date.month}/${date.year} $time";
}

String _severityLabel(String severity) {
  switch (severity) {
    case "minor":
      return "Nhẹ";
    case "moderate":
      return "Vừa";
    case "severe":
      return "Nặng";
    case "critical":
      return "Rất nặng";
    default:
      return severity;
  }
}
