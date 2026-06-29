import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/profile/other_profile_controller.dart';
import 'package:matchu_app/controllers/profile/profile_posts_controller.dart';
import 'package:matchu_app/models/user_model.dart';
import 'package:matchu_app/routes/app_router.dart';
import 'package:matchu_app/services/chat/chat_service.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/chat/long_chat/chat_view.dart';
import 'package:matchu_app/views/profile/avatar_fullscreen_view.dart';
import 'package:matchu_app/views/profile/follow_tab_view.dart';
import 'package:matchu_app/views/profile/profile_widget/profile_widget.dart';
import 'package:matchu_app/views/profile/widgets/profile_posts_section.dart';
import 'package:matchu_app/views/report/profile_user_report_bottom_sheet.dart';
import 'package:matchu_app/widgets/profile_interests_wrap.dart';
import 'package:matchu_app/widgets/verified_name_row.dart';

class OtherProfileView extends StatelessWidget {
  final String userId;

  const OtherProfileView({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final OtherProfileController c = Get.put(
      OtherProfileController(userId),
      tag: userId, // ⭐ Gán tag để controller không bị trùng
      permanent: false, // Cho phép tự hủy khi back
    );

    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leading: Obx(() {
          final isBlocked = c.hasBlockRelationship;
          final foregroundColor =
              isBlocked ? colorScheme.onSurface : colorScheme.onPrimary;
          final borderColor =
              isBlocked
                  ? colorScheme.outline.withValues(alpha: 0.45)
                  : colorScheme.onPrimary.withValues(alpha: 0.8);
          final backgroundColor =
              isBlocked
                  ? colorScheme.surface.withValues(alpha: 0.92)
                  : Colors.transparent;

          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_ios_new),
                  color: foregroundColor,
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ),
          );
        }),
        actions: [
          Obx(() {
            final user = c.user.value;
            final isMe = user != null && c.currentUid == user.uid;
            if (user == null || isMe || c.hasBlockRelationship) {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _OtherProfileActionMenu(
                isBlocking: c.isBlocking.value,
                onReport: () => _openProfileReportSheet(context, c, user),
                onBlock: () => _confirmBlockUser(context, c),
              ),
            );
          }),
        ],
      ),
      body: Obx(() {
        if (c.isLoadingFollowing.value ||
            c.isLoadingBlockState.value ||
            c.user.value == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final UserModel u = c.user.value!;
        final String currentUid = c.currentUid;
        final bool isMe = currentUid == u.uid;
        if (!isMe && c.hasBlockRelationship) {
          return _BlockedProfileState(
            isBlockedByUser: c.isBlockedByUser.value,
            onBack: () => Navigator.of(context).maybePop(),
            onOpenRestrictions: () => Get.toNamed(AppRouter.restrictionList),
          );
        }
        final bool canSeeFollowersOnly = isMe || c.isFollowing.value;
        final postsTag = ProfilePostsController.otherProfileTag(
          u.uid,
          includePrivate: isMe,
          includeFollowersOnly: canSeeFollowersOnly,
        );
        final savedPostsTag =
            isMe ? ProfilePostsController.ownerSavedTag(u.uid) : null;
        if (!Get.isRegistered<ProfilePostsController>(tag: postsTag)) {
          Get.put(
            ProfilePostsController(
              userId: u.uid,
              includePrivate: isMe,
              includeFollowersOnly: canSeeFollowersOnly,
            ),
            tag: postsTag,
          );
        }
        if (savedPostsTag != null &&
            !Get.isRegistered<ProfilePostsController>(tag: savedPostsTag)) {
          Get.put(
            ProfilePostsController(
              userId: u.uid,
              includePrivate: true,
              source: ProfilePostsSource.saved,
            ),
            tag: savedPostsTag,
          );
        }

        return SingleChildScrollView(
          child: Column(
            children: [
              // ================= HEADER =================
              SizedBox(
                height: 240,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colorScheme.primary, colorScheme.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(30),
                          bottomRight: Radius.circular(30),
                        ),
                      ),
                      child: SizedBox(
                        height: 240,
                        child: Container(
                          height: 180,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                colorScheme.primary,
                                colorScheme.secondary,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(30),
                              bottomRight: Radius.circular(30),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ================= AVATAR =================
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Material(
                          shape: const CircleBorder(),
                          color: Colors.transparent,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap:
                                () =>
                                    openAvatarFullscreen(context, u.avatarUrl),
                            child: CircleAvatar(
                              radius: 55,
                              backgroundColor:
                                  Theme.of(context).scaffoldBackgroundColor,
                              child: CircleAvatar(
                                radius: 50,
                                backgroundImage:
                                    u.avatarUrl.isNotEmpty
                                        ? CachedNetworkImageProvider(
                                          u.avatarUrl,
                                        )
                                        : const AssetImage(
                                              "assets/avatas/avataMd.png",
                                            )
                                            as ImageProvider,
                                child:
                                    u.avatarUrl.isEmpty
                                        ? Text(
                                          u.nickname[0].toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                        : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // ================= NAME =================
              VerifiedNameRow(
                isVerified: u.isFaceVerified,
                mainAxisAlignment: MainAxisAlignment.center,
                badgeSize: 20,
                child: Text(
                  u.fullname,
                  style: textTheme.headlineSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              if (!u.isFaceVerified)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    "Tài khoản này chưa xác thực",
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                      fontSize: 15,
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                "@${u.nickname} • ${c.age}",
                style: textTheme.bodyMedium?.copyWith(
                  color: textTheme.bodySmall?.color,
                ),
              ),

              const SizedBox(height: 18),

              // ================= FOLLOW BUTTON =================
              if (!isMe)
                Obx(() {
                  final followed = c.isFollowing.value;
                  final canMessage = c.canMessage.value;

                  const double buttonHeight = 45;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      /// ================= FOLLOW BUTTON =================
                      SizedBox(
                        height: buttonHeight,
                        child:
                            followed
                                ? Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(30),
                                    color:
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? AppTheme.darkBorder
                                            : AppTheme.lightBorder,
                                  ),
                                  child: OutlinedButton(
                                    onPressed: () => c.unfollow(),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide.none,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                    ),
                                    child: Text(
                                      "Đã theo dõi",
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                )
                                : ElevatedButton(
                                  onPressed: () => c.follow(),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  child: Text(
                                    "Theo dõi",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ),
                      ),

                      /// ================= MESSAGE BUTTON =================
                      if (canMessage) ...[
                        const SizedBox(width: 12),
                        SizedBox(
                          height: buttonHeight,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _openChat(userId);
                            },
                            icon: Icon(
                              Iconsax.message,
                              size: 22,
                              color:
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppTheme.lightBorder
                                      : AppTheme.darkBorder,
                            ),
                            label: Text(
                              "Nhắn tin",
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppTheme.darkBorder
                                      : AppTheme.lightBorder,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                }),

              const SizedBox(height: 20),

              // ================= BIO =================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  u.bio.isNotEmpty ? u.bio : "Chưa có mô tả.",
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium,
                ),
              ),

              if (u.interests.isNotEmpty) ...[
                const SizedBox(height: 14),
                ProfileInterestsWrap(interests: u.interests),
              ],

              const SizedBox(height: 25),

              // ================= FOLLOW STATS =================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: statItem(
                        "${u.followers.length}",
                        "Theo dõi",
                        textTheme,
                        onTap: () {
                          Get.to(
                            () => FollowTabView(
                              userId: c.user.value!.uid,
                              initialIndex: 0,
                            ),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: statItem(
                        "${u.following.length}",
                        "Đã theo dõi",
                        textTheme,
                        onTap: () {
                          Get.to(
                            () => FollowTabView(
                              userId: c.user.value!.uid,
                              initialIndex: 1,
                            ),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: statItem("Lv. ${u.rank}", "Rank", textTheme),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              ProfilePostsSection(
                controllerTag: postsTag,
                isOwnerView: isMe,
                savedControllerTag: savedPostsTag,
              ),
            ],
          ),
        );
      }),
    );
  }

  Future<void> _openProfileReportSheet(
    BuildContext context,
    OtherProfileController controller,
    UserModel user,
  ) async {
    final reported = await Get.bottomSheet<bool>(
      ProfileUserReportBottomSheet(
        toUid: user.uid,
        reportedUserName: user.fullname,
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );

    if (reported != true || !context.mounted) return;

    final shouldBlock = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Đã gửi báo cáo'),
            content: Text(
              'Bạn có muốn chặn ${user.fullname} không? Nếu chặn, bạn sẽ không còn thấy hồ sơ, bài viết và tin nhắn từ tài khoản này.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Bỏ qua'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Chặn luôn'),
              ),
            ],
          ),
    );

    if (shouldBlock != true || !context.mounted) return;
    if (controller.isBlocking.value) return;

    final blocked = await controller.blockUser();
    if (blocked && context.mounted) {
      Get.snackbar(
        'Đã chặn người dùng',
        'Tài khoản này đã được thêm vào danh sách hạn chế.',
        snackPosition: SnackPosition.TOP,
      );
      await Navigator.of(context).maybePop();
    }
  }

  void openAvatarFullscreen(BuildContext context, String? avatarUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => AvatarFullscreenView(avatarUrl: avatarUrl),
    );
  }

  void _openChat(String otherUid) async {
    final chatService = ChatService();

    // 🔥 Tạo hoặc lấy roomId (nên làm ở service)
    try {
      final roomId = await chatService.getOrCreateRoom(otherUid);

      Get.to(
        () => const ChatView(),
        arguments: {"roomId": roomId, "otherUid": otherUid},
        transition: Transition.cupertino,
      );
    } catch (error) {
      Get.snackbar(
        'L\u1ED7i',
        error is StateError
            ? error.message
            : 'Kh\u00F4ng th\u1EC3 m\u1EDF cu\u1ED9c tr\u00F2 chuy\u1EC7n.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    }
  }

  Future<void> _confirmBlockUser(
    BuildContext context,
    OtherProfileController controller,
  ) async {
    if (controller.isBlocking.value) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Ch\u1EB7n ng\u01B0\u1EDDi d\u00F9ng?'),
            content: const Text(
              'B\u1EA1n s\u1EBD kh\u00F4ng c\u00F2n th\u1EA5y h\u1ED3 s\u01A1, b\u00E0i vi\u1EBFt v\u00E0 ng\u01B0\u1EDDi d\u00F9ng n\u00E0y trong c\u00E1c danh s\u00E1ch c\u1EE7a b\u1EA1n.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('H\u1EE7y'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Ch\u1EB7n'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    final blocked = await controller.blockUser();
    if (blocked && context.mounted) {
      await Navigator.of(context).maybePop();
    }
  }
}

enum _OtherProfileMenuAction { report, block }

class _OtherProfileActionMenu extends StatelessWidget {
  const _OtherProfileActionMenu({
    required this.isBlocking,
    required this.onReport,
    required this.onBlock,
  });

  final bool isBlocking;
  final VoidCallback onReport;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopupMenuButton<_OtherProfileMenuAction>(
      icon:
          isBlocking
              ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : Icon(Iconsax.warning_2, color: theme.colorScheme.onPrimary),
      enabled: !isBlocking,
      offset: const Offset(0, 46),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (action) {
        switch (action) {
          case _OtherProfileMenuAction.report:
            onReport();
            break;
          case _OtherProfileMenuAction.block:
            onBlock();
            break;
        }
      },
      itemBuilder:
          (context) => [
            const PopupMenuItem(
              value: _OtherProfileMenuAction.report,
              child: _OtherProfileMenuItem(
                icon: Iconsax.warning_2,
                label: 'B\u00E1o c\u00E1o',
              ),
            ),
            const PopupMenuItem(
              value: _OtherProfileMenuAction.block,
              child: _OtherProfileMenuItem(
                icon: Iconsax.profile_delete,
                label: 'Ch\u1EB7n ng\u01B0\u1EDDi d\u00F9ng',
                danger: true,
              ),
            ),
          ],
    );
  }
}

class _OtherProfileMenuItem extends StatelessWidget {
  const _OtherProfileMenuItem({
    required this.icon,
    required this.label,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        danger ? theme.colorScheme.error : theme.colorScheme.onSurface;

    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _BlockedProfileState extends StatelessWidget {
  const _BlockedProfileState({
    required this.isBlockedByUser,
    required this.onBack,
    required this.onOpenRestrictions,
  });

  final bool isBlockedByUser;
  final VoidCallback onBack;
  final VoidCallback onOpenRestrictions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Iconsax.shield_cross,
                size: 46,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 14),
              Text(
                isBlockedByUser
                    ? 'Kh\u00F4ng th\u1EC3 xem h\u1ED3 s\u01A1 n\u00E0y'
                    : 'B\u1EA1n \u0111\u00E3 ch\u1EB7n ng\u01B0\u1EDDi d\u00F9ng n\u00E0y',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isBlockedByUser
                    ? 'Ng\u01B0\u1EDDi d\u00F9ng n\u00E0y hi\u1EC7n kh\u00F4ng kh\u1EA3 d\u1EE5ng v\u1EDBi t\u00E0i kho\u1EA3n c\u1EE7a b\u1EA1n.'
                    : 'C\u00F3 th\u1EC3 g\u1EE1 ch\u1EB7n trong Danh s\u00E1ch h\u1EA1n ch\u1EBF.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodySmall?.color,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                    label: const Text('Quay l\u1EA1i'),
                  ),
                  if (!isBlockedByUser)
                    FilledButton(
                      onPressed: onOpenRestrictions,
                      child: const Text(
                        'M\u1EDF danh s\u00E1ch h\u1EA1n ch\u1EBF',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
