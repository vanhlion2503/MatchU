import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/search/search_user_controller.dart';
import 'package:matchu_app/routes/app_router.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/profile/other_profile_view.dart';
import 'package:matchu_app/widgets/back_circle_button.dart';
import 'package:matchu_app/widgets/verified_name_row.dart';

class SearchUserView extends StatelessWidget {
  SearchUserView({super.key});

  final SearchUserController suc = Get.find();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 56, // 👈 đủ chỗ cho nút tròn
        leading: Align(
          alignment: Alignment.centerLeft,
          child: BackCircleButton(
            offset: const Offset(10, 0),
            size: 44,
            iconSize: 20,
          ),
        ),
        title: Text("Tìm bạn bè", style: textTheme.headlineMedium),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IconButton(
              onPressed: () {
                Get.toNamed(AppRouter.profileQr);
              },
              icon: const Icon(Iconsax.scan),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Obx(
                () => TextField(
                  focusNode: suc.searchFocus,
                  onChanged: (value) => suc.searchUser(value),
                  decoration: InputDecoration(
                    hintText: "Nhập nickname...",
                    prefixIcon: Icon(Icons.search),
                    filled: true,
                    fillColor:
                        suc.isFocused.value
                            ? theme.colorScheme.surface
                            : (theme.brightness == Brightness.dark
                                    ? AppTheme.darkBorder
                                    : AppTheme.lightBorder)
                                .withValues(alpha: 0.5),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color:
                            theme.brightness == Brightness.dark
                                ? AppTheme.darkBorder
                                : AppTheme.lightBorder,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color:
                            theme.brightness == Brightness.dark
                                ? AppTheme.darkBorder
                                : AppTheme.lightBorder,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: AppTheme.primaryColor),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Obx(() {
                if (suc.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (suc.results.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Iconsax.user_search,
                          size: 50,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                        SizedBox(height: 10),
                        Text(
                          "Không tìm thấy người dùng",
                          style: TextStyle(
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // =============== TITLE: KẾT QUẢ TÌM KIẾM ===============
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 18,
                        bottom: 8,
                        top: 10,
                      ),
                      child: Text(
                        "Kết quả tìm kiếm",
                        style: textTheme.bodySmall!.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),

                    // =============== LIST USER ===============
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        itemCount: suc.results.length,
                        itemBuilder: (_, index) {
                          final user = suc.results[index];

                          return GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () {
                              Get.to(() => OtherProfileView(userId: user.uid));
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  // AVATAR
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundImage:
                                        user.avatarUrl.isNotEmpty
                                            ? CachedNetworkImageProvider(
                                              user.avatarUrl,
                                            )
                                            : null,
                                    child:
                                        user.avatarUrl.isEmpty
                                            ? Text(
                                              user.nickname[0].toUpperCase(),
                                              style: textTheme.bodyLarge
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            )
                                            : null,
                                  ),

                                  SizedBox(width: 12),

                                  // NAME & USERNAME
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        VerifiedNameRow(
                                          isVerified: user.isFaceVerified,
                                          child: Text(
                                            user.fullname,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: textTheme.bodyLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ),
                                        Text(
                                          "@${user.nickname}",
                                          style: textTheme.bodyMedium?.copyWith(
                                            color:
                                                theme
                                                    .textTheme
                                                    .bodySmall
                                                    ?.color,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
