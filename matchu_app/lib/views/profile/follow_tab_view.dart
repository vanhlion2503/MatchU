import 'package:matchu_app/translations/localized_material.dart';
import 'package:matchu_app/controllers/profile/other_profile_controller.dart';
import 'package:get/get.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/profile/follower_tab_view.dart';
import 'package:matchu_app/views/profile/following_tab_view.dart';
import 'package:matchu_app/widgets/back_circle_button.dart';
import 'package:matchu_app/widgets/verified_name_row.dart';
import 'package:matchu_app/widgets/user_list_shimmer.dart';

class FollowTabView extends StatefulWidget {
  final String userId;
  final int initialIndex;

  const FollowTabView({super.key, required this.userId, this.initialIndex = 0});

  @override
  State<FollowTabView> createState() => _FollowTabViewState();
}

class _FollowTabViewState extends State<FollowTabView>
    with SingleTickerProviderStateMixin {
  late TabController tabC;
  late OtherProfileController c;
  late final String _controllerTag;

  @override
  void initState() {
    super.initState();
    _controllerTag = 'follow_tab_${widget.userId}';
    c = Get.put(OtherProfileController(widget.userId), tag: _controllerTag);

    tabC = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
  }

  @override
  void dispose() {
    tabC.dispose();
    if (Get.isRegistered<OtherProfileController>(tag: _controllerTag)) {
      Get.delete<OtherProfileController>(tag: _controllerTag);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Obx(() {
      // Keep the list layout stable while the profile header is loading.
      if (c.user.value == null) {
        return const Scaffold(body: SafeArea(child: UserListShimmer()));
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
          title: VerifiedNameRow(
            isVerified: user.isFaceVerified,
            mainAxisSize: MainAxisSize.min,
            useFlexibleChild: false,
            child: Text(
              user.nickname,
              style: textTheme.titleLarge?.copyWith(
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.lightTextPrimary,
              ),
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
                  dividerColor: Colors.transparent, // Quan trọng
                  tabs: [Tab(text: "Theo dõi".tr), Tab(text: "Đã theo dõi".tr)],
                );
              },
            ),
          ),
        ),

        body: TabBarView(
          controller: tabC,
          children: [
            FollowersView(userId: widget.userId),
            FollowingView(userId: widget.userId),
          ],
        ),
      );
    });
  }
}
