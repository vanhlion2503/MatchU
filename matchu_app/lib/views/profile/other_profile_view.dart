import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/profile/other_profile_controller.dart';
import 'package:matchu_app/models/user_model.dart';
import 'package:matchu_app/services/chat/chat_service.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/chat/long_chat/chat_view.dart';
import 'package:matchu_app/views/profile/avatar_fullscreen_view.dart';
import 'package:matchu_app/views/profile/follow_tab_view.dart';
import 'package:matchu_app/views/profile/profile_widget/profile_widget.dart';

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
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // ================= BACKGROUND =================
                            Container(
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

                            // ================= BACK BUTTON (🔥 ĐÚNG CHỖ) =================
                            Positioned(
                              top:
                                  MediaQuery.of(context).padding.top +
                                  4, // 👈 sát status bar
                              left: 8,
                              child: IconButton(
                                onPressed: () => Get.back(),
                                icon: const Icon(Icons.arrow_back_ios_new),
                                color: colorScheme.onPrimary,
                              ),
                            ),
                          ],
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      u.fullname,
                      style: textTheme.headlineSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (u.isFaceVerified)
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
              if (!u.isFaceVerified)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    "Tài khoản này chưa xác thực",
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                      fontSize: 12,
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
                                      "Đang theo dõi",
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

              const SizedBox(height: 25),

              // ================= FOLLOW STATS =================
              Row(
                children: [
                  Expanded(
                    child: statItem(
                      "${u.followers.length}",
                      "Người theo dõi",
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
                      "Đang theo dõi",
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
                  Expanded(child: statItem("Lv. ${u.rank}", "Rank", textTheme)),
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
                          color:
                              isDark
                                  ? AppTheme.darkBorder
                                  : AppTheme.lightBorder,
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
    final roomId = await chatService.getOrCreateRoom(otherUid);

    Get.to(
      () => const ChatView(),
      arguments: {"roomId": roomId},
      transition: Transition.cupertino,
    );
  }
}
