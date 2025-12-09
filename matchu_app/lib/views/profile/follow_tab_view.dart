import 'package:flutter/material.dart';
import 'package:matchu_app/controllers/profile/other_profile_controller.dart';
import 'package:get/get.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/profile/follower_tab_view.dart';
import 'package:matchu_app/views/profile/following_tab_view.dart';


class FollowTabView extends StatefulWidget {
  final String userId;
  final int initialIndex;

  const FollowTabView({
    super.key,
    required this.userId,
    this.initialIndex = 0,
    });

  @override
  State<FollowTabView> createState() => _FollowTabViewState();
}

class _FollowTabViewState extends State<FollowTabView> 
  with SingleTickerProviderStateMixin{
    late TabController tabC;
    late OtherProfileController c;

    @override
    void initState(){
      super.initState();
      c = Get.put(OtherProfileController(widget.userId));

      tabC = TabController(
        length: 2, 
        vsync: this,
        initialIndex: widget.initialIndex,
        );
    }

    @override
    Widget build(BuildContext context) {
      final textTheme = Theme.of(context).textTheme;

      return Obx(() {
        // Loading user → show spinner
        if (c.user.value == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = c.user.value!;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              user.nickname,
              style: textTheme.titleLarge,
            ),
            centerTitle: true,
            elevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent, // Quan trọng
            bottom: TabBar(
              controller: tabC,
              labelColor: AppTheme.textPrimaryColor,
              unselectedLabelColor: AppTheme.textSecondaryColor,
              indicatorColor: AppTheme.textPrimaryColor,
              dividerColor: Colors.transparent,   // Quan trọng
              tabs: const [
                Tab(text: "Người theo dõi"),
                Tab(text: "Đang theo dõi"),
              ],
            ),
          ),

          body: TabBarView(
            controller: tabC,
            children:[
              FollowersView(userId: widget.userId),
              FollowingView(userId: widget.userId),
            ],
          ),
        );
      });
    }

}
