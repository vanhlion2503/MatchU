import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/profile/other_profile_controller.dart';
import 'package:matchu_app/models/user_model.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/profile/follow_tab_view.dart';
import 'package:matchu_app/widgets/profile_widget/profile_widget.dart';

class OtherProfileView extends StatelessWidget {
  final String userId;

  const OtherProfileView({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final OtherProfileController c = Get.put(
      OtherProfileController(userId),
      tag: userId,        // ⭐ Gán tag để controller không bị trùng
      permanent: false,   // Cho phép tự hủy khi back
    );


    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Obx(() {
        if (c.isLoadingFollowing.value || c.user.value == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final UserModel u = c.user.value!;
        final String currentUid = c.currentUid;
        final bool isMe = currentUid == u.uid; 

        return SingleChildScrollView(
          child: Column(
            children: [
              // ================= HEADER =================
              Stack(
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
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            BackButton(color: colorScheme.onPrimary),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ================= AVATAR =================
                  Positioned(
                    bottom: -45,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: CircleAvatar(
                        radius: 55,
                        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                        child: CircleAvatar(
                          radius: 50,
                          backgroundImage: u.avatarUrl.isNotEmpty
                              ? NetworkImage(u.avatarUrl)
                              : AssetImage("assets/avatas/avataMd.png"),
                          child: u.avatarUrl.isEmpty
                              ? Text(
                                  u.nickname[0].toUpperCase(),
                                  style: const TextStyle(
                                      fontSize: 22, fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 60),

              // ================= NAME =================
              Text(u.fullname, style: textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text("@${u.nickname}", style: textTheme.bodyMedium),

              const SizedBox(height: 18),

              // ================= FOLLOW BUTTON =================
              // ================= FOLLOW BUTTON =================
              if (!isMe)
                Obx(() {
                  final followed = c.isFollowing.value;

                  if (followed) {
                    // ------------------ NÚT ĐANG THEO DÕI ------------------
                    return OutlinedButton(
                      onPressed: () => c.unfollow(),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        foregroundColor: Theme.of(context).colorScheme.primary,
                      ),
                      child: const Text(
                        "Đang theo dõi",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    );
                  } else {
                    // ------------------ NÚT THEO DÕI ------------------
                    return ElevatedButton(
                      onPressed: () => c.follow(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        "Theo dõi",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    );
                  }
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

              const SizedBox(height: 25),

              // ================= FOLLOW STATS =================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  statItem(
                    "${u.followers.length}", 
                    "Người theo dõi",
                    textTheme,
                    onTap: () {
                      Get.to(() => FollowTabView(
                        userId: c.user.value!.uid,
                        initialIndex: 0,
                        ));
                    },
                    ),
                  statItem(
                    "${u.following.length}", 
                    "Đang theo dõi",
                    textTheme,
                    onTap: () {
                      Get.to(() => FollowTabView(
                        userId: c.user.value!.uid,
                        initialIndex: 1,
                        ));
                    },
                    ),
                  statItem("Lv. ${u.rank}", "Rank", textTheme),
                ],
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

              // ================= POSTS =================
              SizedBox(
                height: 140,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: 4,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, index) {
                    final theme = Theme.of(context);
                    final isDark = theme.brightness == Brightness.dark;
                    return Container(
                      width: 120,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                        ),
                      ),
                    );
                  },
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
