import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/models/reputation_daily_state.dart';
import 'package:matchu_app/theme/app_theme.dart';

Widget buildPostEngagementTaskCard({
  required BuildContext context,
  required TextTheme textTheme,
  required ReputationDailyTask? task,
  required bool hasReachedMax,
  required bool isClaiming,
  required VoidCallback onClaim,
}) {
  const cardGradient = LinearGradient(
    colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  final likeItem = task?.breakdownItem('likes');
  final commentItem = task?.breakdownItem('comments');
  final likeTarget = likeItem?.target ?? 5;
  final commentTarget = commentItem?.target ?? 5;
  final likeProgress = (likeItem?.progress ?? 0).clamp(0, likeTarget);
  final commentProgress = (commentItem?.progress ?? 0).clamp(0, commentTarget);
  final rewardTextValue =
      task == null ? 3 : (task.claimed ? task.claimedReward : task.reward);

  final bool canClaim =
      task != null &&
      task.isCompleted &&
      !task.claimed &&
      !hasReachedMax &&
      !isClaiming;

  String buttonLabel;
  if (task == null) {
    buttonLabel = "Đang tải...";
  } else if (isClaiming) {
    buttonLabel = "Đang nhận...";
  } else if (hasReachedMax) {
    buttonLabel = "Đã đủ uy tín";
  } else if (task.claimed) {
    buttonLabel = "Đã nhận";
  } else if (!task.isCompleted) {
    buttonLabel = "Chưa hoàn thành";
  } else {
    buttonLabel = "Nhận";
  }

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color:
          Theme.of(context).brightness == Brightness.dark
              ? const Color.fromARGB(255, 15, 21, 37)
              : Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color:
            Theme.of(context).brightness == Brightness.dark
                ? const Color.fromARGB(80, 34, 211, 238)
                : const Color(0xFFE0F2FE),
        width: 2,
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1A0F172A),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).brightness == Brightness.dark
                              ? const Color.fromARGB(130, 8, 47, 73)
                              : const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Iconsax.like_15,
                      size: 23,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Tương tác bài viết",
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Like 5 bài và bình luận 5 lần mỗi ngày",
                          style: textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              "+$rewardTextValue Uy tín",
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0284C7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _EngagementProgressRow(
          label: "Like bài viết",
          valueText: "$likeProgress/$likeTarget",
          progress: likeProgress / likeTarget,
          gradient: cardGradient,
          textTheme: textTheme,
        ),
        const SizedBox(height: 8),
        _EngagementProgressRow(
          label: "Bình luận",
          valueText: "$commentProgress/$commentTarget",
          progress: commentProgress / commentTarget,
          gradient: cardGradient,
          textTheme: textTheme,
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: canClaim ? cardGradient : null,
              color:
                  canClaim
                      ? null
                      : Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.darkSurface
                      : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              boxShadow:
                  canClaim
                      ? const [
                        BoxShadow(
                          color: Color(0x3306B6D4),
                          blurRadius: 14,
                          offset: Offset(0, 4),
                        ),
                      ]
                      : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: canClaim ? onClaim : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        buttonLabel,
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color:
                              canClaim
                                  ? Colors.white
                                  : Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppTheme.darkTextPrimary
                                  : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Iconsax.star_1,
                        size: 14,
                        color:
                            canClaim
                                ? Colors.white
                                : Theme.of(context).brightness ==
                                    Brightness.dark
                                ? AppTheme.darkTextPrimary
                                : const Color(0xFF64748B),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _EngagementProgressRow extends StatelessWidget {
  const _EngagementProgressRow({
    required this.label,
    required this.valueText,
    required this.progress,
    required this.gradient,
    required this.textTheme,
  });

  final String label;
  final String valueText;
  final double progress;
  final Gradient gradient;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              valueText,
              style: textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? AppTheme.darkTextPrimary
                        : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 6,
            child: Stack(
              children: [
                Container(color: const Color(0xFFF1F5F9)),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(gradient: gradient),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
