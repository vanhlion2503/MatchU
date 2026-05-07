import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/game/telepathy/telepathy_controller.dart';
import 'package:matchu_app/models/word_chain.dart';
// import 'package:matchu_app/controllers/matching/matching_controller.dart';
import 'package:matchu_app/views/chat/chat_widget/gender_icon.dart';
import 'package:matchu_app/views/chat/temp_chat/bottom_action_bar.dart';
import 'package:matchu_app/views/chat/temp_chat/telepathy/heart_rain_overlay.dart';
import 'package:matchu_app/views/chat/temp_chat/telepathy/telepathy_game_overlay.dart';
import 'package:matchu_app/views/chat/temp_chat/telepathy/telepathy_pinned_banner.dart';
import 'package:matchu_app/views/chat/temp_chat/telepathy/telepathy_result_overlay.dart';
import 'package:matchu_app/views/chat/temp_chat/word_chain/word_chain_playing_bar.dart';
import '../../../controllers/chat/temp_chat_controller.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/views/chat/temp_chat/messages_list.dart';
import 'package:matchu_app/widgets/verified_name_row.dart';

class TempChatView extends StatefulWidget {
  const TempChatView({super.key});

  @override
  State<TempChatView> createState() => _TempChatViewState();
}

class _TempChatViewState extends State<TempChatView> {
  late final String roomId;
  late final TempChatController controller;
  Worker? _telepathyStatusWorker;
  Worker? _wordChainStatusWorker;

  @override
  void initState() {
    super.initState();

    final args = Get.arguments as Map<String, dynamic>;
    roomId = args["roomId"] as String;
    controller = Get.put(TempChatController(roomId), tag: roomId);

    _telepathyStatusWorker = ever<TelepathyStatus>(
      controller.telepathy.status,
      (status) {
        if (status == TelepathyStatus.countdown ||
            status == TelepathyStatus.playing ||
            status == TelepathyStatus.revealing) {
          controller.dismissComposerState();
        }
      },
    );

    _wordChainStatusWorker = ever<WordChainStatus>(
      controller.wordChain.status,
      (status) {
        if (status == WordChainStatus.countdown ||
            status == WordChainStatus.playing ||
            status == WordChainStatus.reward) {
          controller.dismissComposerState();
        }
      },
    );

    controller.onOtherLiked = () {
      if (!mounted) return;
      HeartRainOverlay.show(
        context,
        count: 14, // số tim
      );
    };
  }

  @override
  void dispose() {
    controller.onOtherLiked = null;
    _telepathyStatusWorker?.dispose();
    _wordChainStatusWorker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 72,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: theme.colorScheme.surface.withOpacity(0.95),

        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4), // chiều cao progress bar
          child: Obx(() {
            final sec = controller.remainingSeconds.value;
            final total = 420.0;
            final progress = (sec / total).clamp(0.0, 1.0);
            final isDanger = sec <= 30;

            final color =
                isDanger ? theme.colorScheme.error : theme.colorScheme.primary;

            return SizedBox(
              height: 2,
              width: double.infinity,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: theme.dividerColor.withOpacity(0.25),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            );
          }),
        ),

        /// ================= TITLE =================
        title: Obx(() {
          final rating = controller.otherAvgRating.value;
          final ratingCount = controller.otherRatingCount.value;

          return Row(
            children: [
              /// 👤 Avatar + online dot
              Obx(() {
                final key = controller.otherAnonymousAvatar.value;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      backgroundImage:
                          key == null
                              ? const AssetImage(
                                "assets/anonymous/placeholder.png",
                              )
                              : AssetImage("assets/anonymous/$key.png"),
                    ),
                    Positioned(
                      right: 1,
                      bottom: 1,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.surface,
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),

              const SizedBox(width: 12),

              /// 🧾 Name + rating (co giãn)
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: VerifiedNameRow(
                            isVerified: controller.otherIsFaceVerified.value,
                            mainAxisSize: MainAxisSize.min,
                            useFlexibleChild: false,
                            child: Text(
                              "Người lạ",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Obx(
                          () => genderIcon(controller.otherGender.value, theme),
                        ),
                      ],
                    ),

                    if (rating != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFF86402),
                                  ),
                                ),
                                const SizedBox(width: 3),
                                const Icon(
                                  Iconsax.star1,
                                  size: 14,
                                  color: Color(0xFFFABC03),
                                ),
                              ],
                            ),
                          ),
                          if (ratingCount != null) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                "· $ratingCount đánh giá",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        }),

        /// ================= ACTIONS =================
        actions: [
          Obx(() {
            final sec = controller.remainingSeconds.value;
            final isDanger = sec <= 30;

            final minutes = sec ~/ 60;
            final seconds = sec % 60;

            final color =
                isDanger ? theme.colorScheme.error : theme.colorScheme.primary;

            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color),
                ),
                child: Text(
                  "⏱ ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}",
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            );
          }),
        ],
      ),

      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: controller.dismissComposerState,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    TelepathyPinnedBanner(controller: controller),
                    Expanded(child: MessagesList(roomId, controller)),
                    BottomActionBar(controller),
                  ],
                ),
              ),
              WordChainPlayingBar(controller: controller),
              TelepathyGameOverlay(controller: controller),
              TelepathyResultOverlay(controller: controller),
            ],
          ),
        ),
      ),
    );
  }
}
