import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/profile/profile_controller.dart';
import 'package:matchu_app/controllers/reputation/reputation_controller.dart';
import 'package:matchu_app/views/reputation/widget/build_app_usage_task_card.dart';
import 'package:matchu_app/views/reputation/widget/build_daily_task_card.dart';
import 'package:matchu_app/views/reputation/widget/build_mutual_like_long_chat_task_card.dart';
import 'package:matchu_app/views/reputation/widget/build_received_fire_star_task_card.dart';
import 'package:matchu_app/views/reputation/widget/build_temp_chat_task_card.dart';
import 'package:matchu_app/views/reputation/widget/header_card.dart';
import 'package:matchu_app/views/reputation/widget/reputation_view_shimmer.dart';

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
        scrolledUnderElevation: 0,
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
          return const ReputationViewShimmer();
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
        final tempChatTask = dailyState?.tempChat3Rooms3MinutesTask;
        final mutualLikeLongChatTask = dailyState?.mutualLikeLongChat5TimesTask;
        final receivedFiveStarTask = dailyState?.receivedFiveStarRatingTask;
        final isClaimingLoginTask =
            reputationController.isClaimingTaskId.value == "loginDaily";
        final isClaimingAppUsageTask =
            reputationController.isClaimingTaskId.value == "appUsage15Minutes";
        final isClaimingTempChatTask =
            reputationController.isClaimingTaskId.value ==
            "tempChat3Rooms3Minutes";
        final isClaimingFiveStarTask =
            reputationController.isClaimingTaskId.value ==
            "receivedFiveStarRating";
        final isClaimingMutualLikeLongChatTask =
            reputationController.isClaimingTaskId.value ==
            "mutualLikeLongChat5Times";
        final hasReachedMax =
            dailyState?.hasReachedMax ?? (reputationScore >= 100);
        final canEarnMore =
            dailyState?.canEarnMore ??
            (!hasReachedMax && safeClaimed < safeCap);
        final remainingToday = (safeCap - safeClaimed).clamp(0, safeCap);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            children: [
              buildHeaderCard(
                textTheme: textTheme,
                fullName: profileController.fullName,
                isVerified: user.isFaceVerified,
                rank: profileController.rank,
                avatarUrl: user.avatarUrl,
                avatarVersion: user.updatedAt?.millisecondsSinceEpoch ?? 0,
                reputationScore: reputationScore,
                todayClaimed: safeClaimed,
                dailyCap: safeCap,
                progress: todayProgress,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Nhiệm vụ hôm nay",
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      "$remainingToday điểm còn lại",
                      style: textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              buildDailyTaskCard(
                context: context,
                textTheme: textTheme,
                task: loginTask,
                hasReachedMax: hasReachedMax,
                isClaiming: isClaimingLoginTask,
                onClaim: () => reputationController.claimTask("loginDaily"),
              ),
              const SizedBox(height: 12),
              buildAppUsageTaskCard(
                context: context,
                textTheme: textTheme,
                task: appUsageTask,
                hasReachedMax: hasReachedMax,
                isClaiming: isClaimingAppUsageTask,
                onClaim:
                    () => reputationController.claimTask("appUsage15Minutes"),
              ),
              const SizedBox(height: 12),
              buildTempChatTaskCard(
                context: context,
                textTheme: textTheme,
                task: tempChatTask,
                hasReachedMax: hasReachedMax,
                isClaiming: isClaimingTempChatTask,
                onClaim:
                    () => reputationController.claimTask(
                      "tempChat3Rooms3Minutes",
                    ),
              ),
              const SizedBox(height: 12),
              buildMutualLikeLongChatTaskCard(
                context: context,
                textTheme: textTheme,
                task: mutualLikeLongChatTask,
                hasReachedMax: hasReachedMax,
                isClaiming: isClaimingMutualLikeLongChatTask,
                onClaim:
                    () => reputationController.claimTask(
                      "mutualLikeLongChat5Times",
                    ),
              ),
              const SizedBox(height: 12),
              buildReceivedFiveStarTaskCard(
                context: context,
                textTheme: textTheme,
                task: receivedFiveStarTask,
                hasReachedMax: hasReachedMax,
                canEarnMore: canEarnMore,
                isClaiming: isClaimingFiveStarTask,
                onClaim:
                    () => reputationController.claimTask(
                      "receivedFiveStarRating",
                    ),
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
}
