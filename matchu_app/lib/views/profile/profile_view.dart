import 'package:flutter/material.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/profile/follow_tab_view.dart';
import 'package:matchu_app/widgets/avatar_bottom_sheet.dart';
import 'package:matchu_app/views/profile/profile_widget/profile_widget.dart';
import 'package:matchu_app/controllers/profile/profile_controller.dart';
import 'package:get/get.dart';
import 'package:matchu_app/views/profile/profile_widget/popup_profile_widget.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/views/profile/profile_widget/right_side_menu.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:matchu_app/controllers/auth/avatar_controller.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final ProfileController c = Get.put(ProfileController());
    final AvatarController avatarC = Get.find<AvatarController>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Obx(() {
        // ====== LOADING ======
        if (c.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        // ====== KHÔNG CÓ USER ======
        if (c.user.value == null) {
          return const Center(child: Text("Không tìm thấy hồ sơ người dùng."));
        }
        final user = c.user.value!;
        return SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(
                height: 240,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 180,
                      width: double.infinity,
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
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: 0,
                          left: 20,
                          right: 20,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: () {
                                Get.toNamed('/search-user');
                              },
                              icon: Icon(
                                Iconsax.user_cirlce_add,
                                color: colorScheme.onPrimary,
                                size: 30,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                RightSideMenu.open(context);
                              },
                              icon: Icon(
                                Iconsax.more_circle,
                                color: colorScheme.onPrimary,
                                size: 30,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // AVATAR
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Obx(() {
                          final user = avatarC.user.value;
                          return GestureDetector(
                            onTap: () => showAvatarBottomSheet(context),
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 55,
                                  backgroundColor:
                                      theme.scaffoldBackgroundColor,
                                  child: CircleAvatar(
                                    radius: 50,
                                    backgroundColor: Colors.grey.shade200,
                                    backgroundImage:
                                        user != null &&
                                                user.avatarUrl.isNotEmpty
                                            ? CachedNetworkImageProvider(
                                              user.avatarUrl ==
                                                      AvatarController
                                                          .defaultAvatarUrl
                                                  ? user
                                                      .avatarUrl // ❗ placeholder → KHÔNG cache busting
                                                  : "${user.avatarUrl}?v=${user.updatedAt?.millisecondsSinceEpoch ?? 0}",
                                            )
                                            : const AssetImage(
                                              "assets/avatas/avataMd.png",
                                            ),
                                  ),
                                ),

                                // ICON CAMERA
                                Positioned(
                                  bottom: 4,
                                  right: 4,
                                  child: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AppTheme.primaryColor,
                                    child: const Icon(
                                      Iconsax.camera,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),

                                // LOADING OVERLAY
                                if (avatarC.isUploadingAvatar.value)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.3,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // ---------------- NAME ----------------
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      c.fullName,
                      style: textTheme.headlineSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (user.isFaceVerified)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(
                        Icons.verified_rounded,
                        size: 20,
                        color: Colors.blue,
                      ),
                    ),
                ],
              ),

              if (!user.isFaceVerified)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    "Tài khoản chưa xác thực",
                    style: textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),

              const SizedBox(height: 6),

              Text(
                "@${c.nickName} • ${c.getAge}",
                style: textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),

              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Stack(
                  children: [
                    // ===== BIO TEXT (Center) =====
                    GestureDetector(
                      onTap: () => showEditBioDialog(context, c),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: Text(
                          c.bio.isNotEmpty ? c.bio : "Chưa có mô tả bản thân.",
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color:
                                c.bio.isNotEmpty
                                    ? textTheme.bodyMedium?.color
                                    : theme.textTheme.bodySmall?.color,
                          ),
                        ),
                      ),
                    ),

                    // ===== EDIT ICON (Right) =====
                    Positioned(
                      right: 0,
                      child: GestureDetector(
                        onTap: () => showEditBioDialog(context, c),
                        child: Icon(
                          Iconsax.edit_2,
                          size: 22,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // ---------------- STATS ----------------
              Row(
                children: [
                  Expanded(
                    child: statItem(
                      c.followersCount.toString(),
                      "Người theo dõi",
                      textTheme,
                      onTap: () {
                        Get.to(
                          () => FollowTabView(
                            userId: c.user.value!.uid,
                            initialIndex: 0, // ⭐ mở tab Followers
                          ),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: statItem(
                      c.followingCount.toString(),
                      "Đang theo dõi",
                      textTheme,
                      onTap: () {
                        Get.to(
                          () => FollowTabView(
                            userId: c.user.value!.uid,
                            initialIndex: 1, // ⭐ mở tab Following
                          ),
                        );
                      },
                    ),
                  ),
                  Expanded(child: statItem("Lv. ${c.rank}", "Rank", textTheme)),
                ],
              ),
              const SizedBox(height: 25),

              // ---------------- REPUTATION CARD ----------------
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Điểm uy tín",
                            style: textTheme.titleMedium?.copyWith(
                              color:
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppTheme.darkTextPrimary
                                      : AppTheme.lightTextPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),

                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.successColor.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              c.reputationLabel.toUpperCase(),
                              style: textTheme.bodySmall?.copyWith(
                                color: AppTheme.successColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 15),

                      Row(
                        children: [
                          SizedBox(
                            width: 60,
                            height: 60,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CircularProgressIndicator(
                                  value: c.reputationPercent,
                                  strokeWidth: 6,
                                  color: colorScheme.primary,
                                  backgroundColor:
                                      theme.brightness == Brightness.dark
                                          ? AppTheme.darkBorder
                                          : AppTheme.lightBorder,
                                ),
                                Center(
                                  child: Text(
                                    "${user.reputationScore}%",
                                    style: textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 15),

                          Expanded(
                            child: Text(
                              "Giữ cách trò chuyện lịch sự để tăng độ uy tín và mở khóa nhiều tính năng hơn.",
                              style: textTheme.bodySmall?.copyWith(
                                color: theme.textTheme.bodySmall?.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // ---------------- TABS ----------------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  tabItem("Posts", true, textTheme),
                  tabItem("Media", false, textTheme),
                  tabItem("Likes", false, textTheme),
                ],
              ),

              const SizedBox(height: 20),

              // ---------------- POSTS PLACEHOLDER ----------------
              SizedBox(
                height: 140,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemBuilder:
                      (_, index) => Container(
                        width: 120,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color:
                                theme.brightness == Brightness.dark
                                    ? AppTheme.darkBorder
                                    : AppTheme.lightBorder,
                          ),
                        ),
                      ),
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemCount: 4,
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        );
      }),
    );
  }
}
