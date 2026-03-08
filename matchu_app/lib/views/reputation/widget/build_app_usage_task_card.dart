import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/models/reputation_daily_state.dart';
import 'package:matchu_app/theme/app_theme.dart';

Widget buildAppUsageTaskCard({
    required BuildContext context,
    required TextTheme textTheme,
    required ReputationDailyTask? task,
    required bool hasReachedMax,
    required bool isClaiming,
    required VoidCallback onClaim,
  }) {
    const cardGradient = LinearGradient(
      colors: [Color(0xFF22C55E), Color(0xFF4ADE80)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    final bool canClaim =
        task != null &&
        task.isCompleted &&
        !task.claimed &&
        !hasReachedMax &&
        !isClaiming;
    final int safeTarget =
        (task?.target ?? 15) <= 0 ? 15 : (task?.target ?? 15);
    final int safeProgress = (task?.progress ?? 0).clamp(0, safeTarget);
    final double progress = (safeProgress / safeTarget).clamp(0.0, 1.0);
    final String subtitle =
        task == null
            ? "Theo thời gian sử dụng trong ngày"
            : (task.claimed ? "Đã nhận thưởng hôm nay" : "Sử dụng app 15 phút");

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
      buttonLabel = "Chưa đủ 15p";
    } else {
      buttonLabel = "Nhận";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            Theme.of(context).brightness == Brightness.dark
                ? Color.fromARGB(255, 15, 21, 37)
                : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color:
              Theme.of(context).brightness == Brightness.dark
                  ? const Color.fromARGB(68, 74, 255, 137)
                  : const Color(0xFFDCFCE7),
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
                                ? const Color.fromARGB(255, 0, 75, 26)
                                : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Iconsax.timer_1,
                        size: 25,
                        color: Color(0xFF22C55E),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Duy trì trực tuyến",
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
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
                "+1 Uy tín",
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF22C55E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "$safeProgress/$safeTarget p",
                      style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color:
                            Theme.of(context).brightness == Brightness.dark
                                ? AppTheme.darkTextPrimary
                                : const Color(0xFF64748B),
                      ),
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
                              widthFactor: progress,
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: cardGradient,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              DecoratedBox(
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
                              color: Color(0x33EC4B79),
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
            ],
          ),
        ],
      ),
    );
  }