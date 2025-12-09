import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/search/search_user_controller.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/views/profile/other_profile_view.dart';

class SearchUserView extends StatelessWidget {
  SearchUserView({super.key});
  

  final SearchUserController suc = Get.find();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          "Tìm bạn bè",
          style: textTheme.headlineMedium,
          )
        ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Obx(() => TextField(
                focusNode: suc.searchFocus,
                onChanged: (value) => suc.searchUser(value),
                decoration: InputDecoration(
                  hintText: "Nhập nickname...",
                  prefixIcon: Icon(Icons.search),
                  filled: true,
                  fillColor: suc.isFocused.value 
                      ? Colors.white                     
                      : Colors.grey.shade200,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppTheme.primaryColor),
                  ),
                ),
              ))
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
                        Icon(Icons.person_search, size: 50, color: Colors.grey),
                        SizedBox(height: 10),
                        Text("Không tìm thấy người dùng",
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // =============== TITLE: KẾT QUẢ TÌM KIẾM ===============
                    Padding(
                      padding: const EdgeInsets.only(left: 18, bottom: 8, top: 10),
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        itemCount: suc.results.length,
                        itemBuilder: (_, index) {
                          final user = suc.results[index];

                          return GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () {
                              Get.to(()=> OtherProfileView(userId: user.uid));
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  // AVATAR
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundImage: user.avatarUrl.isNotEmpty
                                        ? NetworkImage(user.avatarUrl)
                                        : null,
                                    child: user.avatarUrl.isEmpty
                                        ? Text(
                                            user.nickname[0].toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : null,
                                  ),
                            
                                  SizedBox(width: 12),
                            
                                  // NAME & USERNAME
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.fullname,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          "@${user.nickname}",
                                          style: TextStyle(color: Colors.grey[600]),
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
                    )
                  ],
                );
              }),
            )

          ],
        ),
      )
    );
  }
}
