import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/profile/following_controller.dart';
import 'package:matchu_app/views/profile/other_profile_view.dart';
import 'package:matchu_app/theme/app_theme.dart';

class FollowingView extends StatelessWidget {
  final String userId;

  const FollowingView({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final FollowingController c = Get.put(FollowingController(userId));
    final textTheme = Theme.of(context).textTheme;

    return Obx(() {
      if (c.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      if (c.users.isEmpty) {
        return const Center(child: Text("Bạn chưa theo dõi ai."));
      }

      return ListView.builder(
        itemCount: c.users.length,
        itemBuilder: (_, index) {
          final u = c.users[index];

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              Get.to(
                () => OtherProfileView(userId: u.uid),
                preventDuplicates: false,  
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                children: [
                  SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundImage: u.avatarUrl.isNotEmpty
                            ? NetworkImage(u.avatarUrl)
                            : null,
                        child: u.avatarUrl.isEmpty
                            ? Text(u.nickname[0].toUpperCase())
                            : null,
                      ),
                  
                      const SizedBox(width: 12),
                  
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u.fullname, 
                            style: textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? AppTheme.darkTextPrimary 
                                  : AppTheme.lightTextPrimary,

                              fontWeight: FontWeight.w800
                            )
                            ),
                            Text("@${u.nickname}",
                                style: textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).brightness == Brightness.dark 
                                  ? AppTheme.darkTextPrimary 
                                  : AppTheme.lightTextPrimary,
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }
}
