import 'package:flutter/material.dart';
import 'package:matchu_app/controllers/profile/other_profile_controller.dart';
import 'package:get/get.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/profile/follower_tab_view.dart';
import 'package:matchu_app/views/profile/following_tab_view.dart';
import 'package:matchu_app/widgets/back_circle_button.dart';


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
            title: Text(
              user.nickname,
              style: textTheme.titleLarge?.copyWith(
                color: Theme.of(context).brightness == Brightness.dark 
                        ? AppTheme.darkTextPrimary 
                        : AppTheme.lightTextPrimary,
              ),
            ),
            centerTitle: true,
            elevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent, // Quan trọng
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Builder(
                builder: (context) {
                  final theme = Theme.of(context);
                  return TabBar(
                    controller: tabC,
                    labelColor: theme.colorScheme.onSurface,
                    unselectedLabelColor: theme.textTheme.bodySmall?.color,
                    indicatorColor: theme.colorScheme.onSurface,
                    dividerColor: Colors.transparent,   // Quan trọng
                    tabs: const [
                      Tab(text: "Người theo dõi"),
                      Tab(text: "Đang theo dõi"),
                    ],
                  );
                },
              ),
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
