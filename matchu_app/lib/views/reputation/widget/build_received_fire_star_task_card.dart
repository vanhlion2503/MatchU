import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/models/reputation_daily_state.dart';
import 'package:matchu_app/theme/app_theme.dart';

Widget buildReceivedFiveStarTaskCard({
    required BuildContext context,
    required TextTheme textTheme,
    required ReputationDailyTask? task,
    required bool hasReachedMax,
    required bool canEarnMore,
    required bool isClaiming,
    required VoidCallback onClaim,
  }) {
    const cardGradient = LinearGradient(
      colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    final int safeTarget = (task?.target ?? 1) <= 0 ? 1 : (task?.target ?? 1);
    final int safeProgress = (task?.progress ?? 0).clamp(0, 5);
    final int cycleCount = (safeProgress / safeTarget).floor();
    final int rewardPerCycle =
        (task?.reward ?? 1) <= 0 ? 1 : (task?.reward ?? 1);
    final int claimedReward = (task?.claimedReward ?? 0).clamp(0, 999);
    final int totalRewardFromProgress = cycleCount * rewardPerCycle;
    final int pendingReward = (totalRewardFromProgress - claimedReward).clamp(
      0,
      999,
    );
    final bool canClaim =
        task != null &&
        pendingReward > 0 &&
        !hasReachedMax &&
        canEarnMore &&
        !isClaiming;
    final double progress = (safeProgress / 5).clamp(0.0, 1.0);

    final String subtitle =
        task == null
            ? "Nhận +1 mỗi lượt được vote 5 sao (tối đa 5 lượt/ngày)"
            : "Nhận 1 uy tín mỗi lượt";

    String buttonLabel;
    if (task == null) {
      buttonLabel = "Đang tải...";
    } else if (isClaiming) {
      buttonLabel = "Đang nhận...";
    } else if (hasReachedMax) {
      buttonLabel = "Đã đủ uy tín";
    } else if (!canEarnMore) {
      buttonLabel = "Đã hết";
    } else if (safeProgress > 0 && pendingReward <= 0) {
      buttonLabel = "Đã nhận hết";
    } else if (!canClaim) {
      buttonLabel = "Chưa có lượt";
    } else {
      buttonLabel = "Nhận +$pendingReward";
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
                  ? const Color.fromARGB(85, 249, 115, 22)
                  : const Color(0xFFFFEDD5),
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
                                ? const Color.fromARGB(255, 95, 46, 4)
                                : const Color(0xFFFFEDD5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Iconsax.star_1,
                        size: 23,
                        color: Color(0xFFF97316),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Được vote 5 sao",
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
                pendingReward > 0 ? "+$pendingReward Uy tín" : "+0 Uy tín",
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFF97316),
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
                      "$safeProgress/5 lượt",
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
                              color: Color(0x33F97316),
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