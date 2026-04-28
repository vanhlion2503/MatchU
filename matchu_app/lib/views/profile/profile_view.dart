import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/auth/avatar_controller.dart';
import 'package:matchu_app/controllers/feed/post_creation_sync.dart';
import 'package:matchu_app/controllers/profile/profile_controller.dart';
import 'package:matchu_app/controllers/profile/profile_posts_controller.dart';
import 'package:matchu_app/routes/app_router.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/feed/create_post_sheet.dart';
import 'package:matchu_app/views/profile/follow_tab_view.dart';
import 'package:matchu_app/views/profile/profile_widget/popup_profile_widget.dart';
import 'package:matchu_app/views/profile/profile_widget/profile_widget.dart';
import 'package:matchu_app/views/profile/profile_widget/right_side_menu.dart';
import 'package:matchu_app/views/profile/widgets/profile_posts_section.dart';
import 'package:matchu_app/widgets/avatar_bottom_sheet.dart';
import 'package:matchu_app/widgets/verified_name_row.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  Future<void> _openCreatePostSheet(BuildContext context) async {
    final createdPost = await CreatePostSheet.show(context);
    if (createdPost == null) return;

    PostCreationSync.sync(createdPost);
    if (createdPost.isPublic) return;

    Get.snackbar(
      'Thông báo',
      'Bài viết ở chế độ riêng tư sẽ không hiển thị trong bảng tin công khai.',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final ProfileController c = Get.put(ProfileController());
    final AvatarController avatarC = Get.find<AvatarController>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Obx(() {
        if (c.isLoading.value || c.user.value == null) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset + 80),
          child: FloatingActionButton(
            heroTag: 'profile_create_post_fab',
            tooltip: 'Tạo bài viết',
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            onPressed: () => _openCreatePostSheet(context),
            child: const Icon(Iconsax.edit_2),
          ),
        );
      }),
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
        final postsTag = ProfilePostsController.ownerProfileTag(user.uid);
        final savedPostsTag = ProfilePostsController.ownerSavedTag(user.uid);
        if (!Get.isRegistered<ProfilePostsController>(tag: postsTag)) {
          Get.put(
            ProfilePostsController(userId: user.uid, includePrivate: true),
            tag: postsTag,
          );
        }
        if (!Get.isRegistered<ProfilePostsController>(tag: savedPostsTag)) {
          Get.put(
            ProfilePostsController(
              userId: user.uid,
              includePrivate: true,
              source: ProfilePostsSource.saved,
            ),
            tag: savedPostsTag,
          );
        }

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
                      child: SafeArea(
                        bottom: false,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            height: kToolbarHeight,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
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
                                                      .avatarUrl // Default placeholder: no cache-busting
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
              VerifiedNameRow(
                isVerified: user.isFaceVerified,
                mainAxisAlignment: MainAxisAlignment.center,
                badgeSize: 20,
                child: Text(
                  c.fullName,
                  style: textTheme.headlineSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),

              if (!user.isFaceVerified)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    "Tài khoản chưa xác thực",
                    style: textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontSize: 15,
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: statItem(
                        c.followersCount.toString(),
                        "Theo dõi",
                        textTheme,
                        onTap: () {
                          Get.to(
                            () => FollowTabView(
                              userId: c.user.value!.uid,
                              initialIndex: 0, // Open Followers tab
                            ),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: statItem(
                        c.followingCount.toString(),
                        "Đã theo dõi",
                        textTheme,
                        onTap: () {
                          Get.to(
                            () => FollowTabView(
                              userId: c.user.value!.uid,
                              initialIndex: 1, // Open Following tab
                            ),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: statItem("Lv. ${c.rank}", "Rank", textTheme),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),

              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Get.toNamed(AppRouter.reputation),
                overlayColor: WidgetStatePropertyAll(Colors.transparent),
                child: Card(
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
                              style: textTheme.bodyMedium?.copyWith(
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
                                style: textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ProfilePostsSection(
                controllerTag: postsTag,
                isOwnerView: true,
                savedControllerTag: savedPostsTag,
              ),
              const SizedBox(height: 96),
            ],
          ),
        );
      }),
    );
  }
}
