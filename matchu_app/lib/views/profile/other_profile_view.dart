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
    final OtherProfileController c = Get.put(OtherProfileController(userId));

    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
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
                            BackButton(color: Colors.white),
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
                        backgroundColor: Colors.white,
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
              if (!isMe)
              Obx(() {
                final followed = c.isFollowing.value;

                return ElevatedButton(
                  onPressed: () {
                    followed ? c.unfollow() : c.follow();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        followed ? Colors.grey.shade300 : Colors.black,
                    foregroundColor:
                        followed ? Colors.black : Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 35, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    followed ? "Đang theo dõi" : "Theo dõi",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
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
                  itemBuilder: (_, index) => Container(
                    width: 120,
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                  ),
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
