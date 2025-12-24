import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/controllers/chat/anonymous_avatar_controller.dart';
import 'package:matchu_app/services/chat/matching_service.dart';
import 'package:matchu_app/views/chat/chat_widget/anonymous_avatar_selector.dart';
import 'package:matchu_app/widgets/chat_widget/ripple_animation_widget.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/matching/matching_controller.dart';

class RandomChatView extends StatefulWidget {
  const RandomChatView({super.key});

  @override
  State<RandomChatView> createState() => _RandomChatViewState();
}

class _RandomChatViewState extends State<RandomChatView>
    with SingleTickerProviderStateMixin {

  late final AnimationController _rippleController;
  final controller = Get.find<MatchingController>();
  final anonAvatarC = Get.find<AnonymousAvatarController>();
  final _matchingService = MatchingService();
  String selectedTarget = "random";

  @override
  void initState() {
    super.initState();

    /// 🔥 PHẢI repeat()
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = Get.find<AuthController>();
      final user = auth.user;
      if (user != null) {
        await _matchingService.forceUnlock(user.uid);
      }
    });
  }

  @override
  void dispose() {
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;

    return Scaffold(
      backgroundColor: color.background,
      appBar: AppBar(
        title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            "100 trực tuyến",
            style: theme.textTheme.headlineSmall,
          ),
        ],
      ),
      actions: [
          Container(
            margin: const EdgeInsets.only(right: 15),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.surface.withOpacity(0.6),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
              ),
            ),
            child: IconButton(
              icon: const Icon(Iconsax.messages, size: 25,),
              onPressed: () {
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Text(
                  "Trò chuyện ngay", 
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontSize: 26,
                  )),
                const SizedBox(height: 8),
                Text(
                  "Kết nối ẩn danh. Chủ động \nlộ diện khi bạn sẵn sàng.",
                  style: theme.textTheme.bodyLarge,
                ), 
                /// 🎯 AVATAR + RADAR
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      /// 🌊 2 VÒNG RADAR – LAN XUỐNG DƯỚI
                      RippleAnimation(
                        animation: _rippleController,
                        color: color.primary,
                        size: 250, // 🔥 to để lan sâu
                      ),
                      /// 🔵 Vòng cố định
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color.primary,
                            width: 3,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Get.bottomSheet(
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Theme.of(context).scaffoldBackgroundColor,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                              ),
                              child: const AnonymousAvatarSelector(),
                            ),
                            isScrollControlled: true,
                          );
                        },
                        child: Obx(() {
                          final key = anonAvatarC.selectedAvatar.value;

                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              /// ===== AVATAR =====
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: Theme.of(context).colorScheme.surface,
                                backgroundImage: key == null
                                    ? const AssetImage("assets/anonymous/placeholder.png")
                                    : AssetImage("assets/anonymous/$key.png"),
                              ),

                              /// ===== ICON CHANGE =====
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Theme.of(context).colorScheme.primary,
                                    border: Border.all(
                                      color: Theme.of(context).scaffoldBackgroundColor,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Iconsax.edit_2, // hoặc Iconsax.camera
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Muốn tìm…",
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold
                  ),
                ),
                const SizedBox(height: 20),
          
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isLight
                        ? const Color(0xFFF1F4F7).withOpacity(0.65) // 👈 rõ hơn, không opacity
                        : color.surface.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _genderChip(theme, "Nam", "male")),
                      const SizedBox(width: 8),
                      Expanded(child: _genderChip(theme, "Nữ", "female")),
                      const SizedBox(width: 8),
                      Expanded(child: _genderChip(theme, "Ngẫu nhiên", "random")),
                    ],
                  ),
                ),
                const SizedBox(height: 120),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed:() async {
                      if (!anonAvatarC.isSelected) {
                        Get.snackbar(
                          "Thiếu avatar ẩn danh",
                          "Vui lòng chọn avatar trước khi bắt đầu",
                        );
                        return;
                      }
                      controller.isMinimized.value = false;
                      Get.toNamed(
                        "/matching",
                        arguments: {
                          "targetGender": selectedTarget,
                          "anonymousAvatar": anonAvatarC.selectedAvatar.value,
                          },
                      );
                    }, 
                    child: Text("🔍 Bắt đầu tìm kiếm")),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _genderChip(
    ThemeData theme,
    String label,
    String value,
  ) {
    final color = theme.colorScheme;
    final selected = selectedTarget == value;
    final isLight = theme.brightness == Brightness.light;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => selectedTarget = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? (isLight
                  ? Color(0xFF2A2F36).withOpacity(0.8)// 👈 xanh rõ hơn cho light
                  : Color.fromARGB(255, 255, 255, 255).withOpacity(0.2))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.white
                : (isLight
                    ? Color(0xFF2A2F36).withOpacity(0.7) // 👈 xám đậm hơn
                    : color.onSurface.withOpacity(0.7)),
          ),
        ),
      ),
    );
  }

}
