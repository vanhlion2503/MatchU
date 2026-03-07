import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/profile/profile_controller.dart';
import 'package:matchu_app/controllers/reputation/reputation_controller.dart';
import 'package:matchu_app/models/reputation_daily_state.dart';

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
        title: const Text("Diem uy tin"),
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
          return const Center(
            child: Text("Khong tim thay thong tin nguoi dung."),
          );
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
        final isClaimingLoginTask =
            reputationController.isClaimingTaskId.value == "loginDaily";
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
                          "Cap $rank",
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
                      "Uy tin",
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
                    "Tien do hom nay",
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    "$todayClaimed / $dailyCap diem",
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
    final theme = Theme.of(context);

    final bool canClaim =
        task != null &&
        task.isCompleted &&
        !task.claimed &&
        !hasReachedMax &&
        !isClaiming;

    String buttonLabel;
    if (task == null) {
      buttonLabel = "Dang tai...";
    } else if (hasReachedMax) {
      buttonLabel = "Da dat 100";
    } else if (task.claimed) {
      buttonLabel = "Da nhan +${task.claimedReward}";
    } else if (!task.isCompleted) {
      buttonLabel = "Chua hoan thanh";
    } else if (isClaiming) {
      buttonLabel = "Dang nhan...";
    } else {
      buttonLabel = "Nhan +${task.reward}";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.55,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.medal_star, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Nhiem vu moi ngay",
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Vao app moi ngay",
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            "Tien do: ${task?.progress ?? 0}/${task?.target ?? 1}  |  Thuong: +${task?.reward ?? 1}",
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            "Nhiem vu se tu hoan thanh khi ban mo app. Sau do bam nut Nhan diem.",
            style: textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canClaim ? onClaim : null,
              child: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }

  static String _greetingByTime() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Chao buoi sang,";
    if (hour < 18) return "Chao buoi chieu,";
    return "Chao buoi toi,";
  }
}
