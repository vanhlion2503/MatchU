import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/profile/followers_controller.dart';
import 'package:matchu_app/views/profile/other_profile_view.dart';

class FollowersView extends StatelessWidget {
  final String userId;

  const FollowersView({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final FollowersController c = Get.put(FollowersController(userId));
    final textTheme = Theme.of(context).textTheme;

    return Obx(() {
      if (c.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      if (c.followers.isEmpty) {
        return const Center(child: Text("Chưa có người theo dõi."));
      }

      return ListView.builder(
        itemCount: c.followers.length,
        itemBuilder: (_, index) {
          final u = c.followers[index];

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              Get.to(()=> OtherProfileView(userId: u.uid));
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                children: [
                  SizedBox(height: 12),
                  Row(
                    children: [
                      // Avatar
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
                  
                      // Name + Nickname
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u.fullname, style: textTheme.titleMedium),
                            Text(
                              "@${u.nickname}",
                              style: textTheme.bodySmall?.copyWith(
                                color: Colors.grey,
                              ),
                            ),
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
