import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/chat/anonymous_avatar_controller.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/chat/chat_widget/avatar_overlay_service.dart';
import 'avatar_carousel.dart';

class AnonymousAvatarSelector extends StatelessWidget {
  const AnonymousAvatarSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<AnonymousAvatarController>();
    final theme = Theme.of(context);

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Iconsax.arrow_left_2,
              size: 28,
              color: Colors.white,
              ),
            onPressed: AvatarOverlayService.hide,
          ),
          title: Text(
            "Chọn Avatar",
            style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkTextPrimary
                    ),
            ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            const SizedBox(height: 16),
            /// ===== AVATAR CAROUSEL =====
            const AvatarCarousel(),

            const SizedBox(height: 16),


            /// ===== HINT =====
            Text(
              "Vuốt ngang để thay đổi",
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: const Color.fromARGB(255, 179, 178, 178)),
            ),

            const Spacer(),

            /// ===== SAVE BUTTON =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: AvatarOverlayService.hide,
                  child: const Text("Lưu thay đổi"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

