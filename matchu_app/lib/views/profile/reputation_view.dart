import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/profile/profile_controller.dart';
import 'package:matchu_app/controllers/reputation/reputation_controller.dart';
import 'package:matchu_app/models/reputation_daily_state.dart';
import 'package:matchu_app/theme/app_theme.dart';

class ReputationView extends StatelessWidget {
  const ReputationView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final ProfileController profileController =
        Get.isRegistered<ProfileController>()
            ? Get.find<ProfileController>()
            : Get.put(ProfileController());
    final ReputationController reputationController =
        Get.isRegistered<ReputationController>()
            ? Get.find<ReputationController>()
            : Get.put(ReputationController());

    return Scaffold(
      appBar: AppBar(
        title: Text("Điểm uy tín", style: theme.textTheme.headlineMedium),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => reputationController.refreshState(),
          ),
        ],
      ),
      body: Obx(() {
        final user = profileController.user.value;
        final dailyState = reputationController.state.value;

        final isInitialLoading =
            profileController.isLoading.value ||
            (reputationController.isLoading.value && dailyState == null);

        if (isInitialLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (user == null) {
          return const Center(child: Text("Không tìn thấy người dùng"));
        }

        final dailyCap = dailyState?.dailyCap ?? user.reputationTodayCap;
        final todayClaimed =
            dailyState?.todayClaimed ?? user.reputationTodayClaimed;
        final safeCap = dailyCap <= 0 ? 10 : dailyCap;
        final safeClaimed = todayClaimed.clamp(0, safeCap);
        final todayProgress = (safeClaimed / safeCap).clamp(0.0, 1.0);
        final reputationScore =
            dailyState?.reputationScore ?? user.reputationScore;
        final loginTask = dailyState?.loginDailyTask;
        final appUsageTask = dailyState?.appUsage15MinutesTask;
        final isClaimingLoginTask =
            reputationController.isClaimingTaskId.value == "loginDaily";
        final isClaimingAppUsageTask =
            reputationController.isClaimingTaskId.value == "appUsage15Minutes";
        final hasReachedMax =
            dailyState?.hasReachedMax ?? (reputationScore >= 100);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            children: [
              _buildHeaderCard(
                textTheme: textTheme,
                fullName: profileController.fullName,
                rank: profileController.rank,
                avatarUrl: user.avatarUrl,
                avatarVersion: user.updatedAt?.millisecondsSinceEpoch ?? 0,
                reputationScore: reputationScore,
                todayClaimed: safeClaimed,
                dailyCap: safeCap,
                progress: todayProgress,
              ),
              const SizedBox(height: 16),
              _buildDailyTaskCard(
                context: context,
                textTheme: textTheme,
                task: loginTask,
                hasReachedMax: hasReachedMax,
                isClaiming: isClaimingLoginTask,
                onClaim: () => reputationController.claimTask("loginDaily"),
              ),
              const SizedBox(height: 12),
              _buildAppUsageTaskCard(
                context: context,
                textTheme: textTheme,
                task: appUsageTask,
                hasReachedMax: hasReachedMax,
                isClaiming: isClaimingAppUsageTask,
                onClaim:
                    () => reputationController.claimTask("appUsage15Minutes"),
              ),
              if (reputationController.errorMessage.value != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    reputationController.errorMessage.value!,
                    style: textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }

  Widget _buildHeaderCard({
    required TextTheme textTheme,
    required String fullName,
    required int rank,
    required String avatarUrl,
    required int avatarVersion,
    required int reputationScore,
    required int todayClaimed,
    required int dailyCap,
    required double progress,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEC4B79), Color(0xFFFF6D2A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44EC4B79),
            blurRadius: 26,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -38,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 2,
                            ),
                            color: Colors.white.withValues(alpha: 0.24),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child:
                              avatarUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                    imageUrl: "$avatarUrl?v=$avatarVersion",
                                    fit: BoxFit.cover,
                                    errorWidget:
                                        (_, __, ___) => Image.asset(
                                          "assets/avatas/avataMd.png",
                                          fit: BoxFit.cover,
                                        ),
                                  )
                                  : Image.asset(
                                    "assets/avatas/avataMd.png",
                                    fit: BoxFit.cover,
                                  ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _greetingByTime(),
                                style: textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Iconsax.star_1,
                          size: 15,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "Cấp $rank",
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "$reputationScore",
                    style: textTheme.displayMedium?.copyWith(
                      color: Colors.white,
                      fontSize: 52,
                      fontWeight: FontWeight.w700,
                      height: 0.95,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Text(
                      "Uy tín",
                      style: textTheme.titleMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Tiến độ hôm nay",
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    "$todayClaimed / $dailyCap điểm",
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: progress,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTaskCard({
    required BuildContext context,
    required TextTheme textTheme,
    required ReputationDailyTask? task,
    required bool hasReachedMax,
    required bool isClaiming,
    required VoidCallback onClaim,
  }) {
    const cardGradient = LinearGradient(
      colors: [Color(0xFFEC4B79), Color(0xFFFF6D2A)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    final bool canClaim =
        task != null &&
        task.isCompleted &&
        !task.claimed &&
        !hasReachedMax &&
        !isClaiming;
    final int safeTarget = (task?.target ?? 1) <= 0 ? 1 : (task?.target ?? 1);
    final double progress =
        ((task?.progress ?? 0) / safeTarget).clamp(0.0, 1.0).toDouble();
    final int rewardTextValue =
        task == null ? 1 : (task.claimed ? task.claimedReward : task.reward);

    String buttonLabel;
    if (task == null) {
      buttonLabel = "Đang tải...";
    } else if (isClaiming) {
      buttonLabel = "Đang nhận...";
    } else if (hasReachedMax) {
      buttonLabel = "Đã đạt 100";
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
        color: Theme.of(context).brightness == Brightness.dark
                ? Color.fromARGB(255, 15, 21, 37)
                : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
                ? Color.fromARGB(47, 250, 146, 205)
                : Color(0xFFFCE7F3),
          width: 2
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0F172A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child:Column(
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
                            color: Theme.of(context).brightness == Brightness.dark
                              ? const Color.fromARGB(162, 110, 29, 74)
                              : const Color(0xFFFDF2F8),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Iconsax.calendar_2,
                            size: 25,
                            color: Color(0xFFEC4899),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Đăng nhập mỗi ngày",
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Vào app mỗi ngày",
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
                      color: const Color(0xFFEC4899),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
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
                  ),
                  const SizedBox(width: 12),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: canClaim ? cardGradient : null,
                      color: canClaim ? null : Theme.of(context).brightness == Brightness.dark
                                                ? AppTheme.darkSurface
                                                : Color(0xFFF1F5F9),
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
                                          : Theme.of(context).brightness == Brightness.dark
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
                                        : Theme.of(context).brightness == Brightness.dark
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

  Widget _buildAppUsageTaskCard({
    required BuildContext context,
    required TextTheme textTheme,
    required ReputationDailyTask? task,
    required bool hasReachedMax,
    required bool isClaiming,
    required VoidCallback onClaim,
  }) {
    const cardGradient = LinearGradient(
      colors: [Color(0xFF22C55E),Color(0xFF4ADE80)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    final bool canClaim =
        task != null &&
        task.isCompleted &&
        !task.claimed &&
        !hasReachedMax &&
        !isClaiming;
    final int safeTarget = (task?.target ?? 15) <= 0 ? 15 : (task?.target ?? 15);
    final int safeProgress = (task?.progress ?? 0).clamp(0, safeTarget);
    final double progress = (safeProgress / safeTarget).clamp(0.0, 1.0);
    final String subtitle =
        task == null
            ? "Theo thời gian sử dụng trong ngày"
            : (task.claimed
                ? "Đã nhận thưởng hôm nay"
                : "Sử dụng app 30 phút");

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
                "+1 Uy tin",
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
                        color: Theme.of(context).brightness == Brightness.dark
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
                  color: canClaim
                      ? null
                      : Theme.of(context).brightness == Brightness.dark
                          ? AppTheme.darkSurface
                          : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: canClaim
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
                              color: canClaim
                                  ? Colors.white
                                  : Theme.of(context).brightness == Brightness.dark
                                      ? AppTheme.darkTextPrimary
                                      : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Iconsax.star_1,
                            size: 14,
                            color: canClaim
                                ? Colors.white
                                : Theme.of(context).brightness == Brightness.dark
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

  static String _greetingByTime() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Chào buổi sáng,";
    if (hour < 18) return "Chào buổi chiều,";
    return "Chào buổi tối";
  }
}
