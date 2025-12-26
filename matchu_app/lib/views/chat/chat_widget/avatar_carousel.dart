import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/anonymous_avatar_controller.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/chat/chat_widget/avatar_page_indicator.dart';

class AvatarCarousel extends StatefulWidget {
  const AvatarCarousel({super.key});

  @override
  State<AvatarCarousel> createState() => _AvatarCarouselState();
}

class _AvatarCarouselState extends State<AvatarCarousel> {
  late final PageController _pageController;
  final c = Get.find<AnonymousAvatarController>();

  final ValueNotifier<double> _page = ValueNotifier(0);

  @override
  void initState() {
    super.initState();

    ever<List<String>>(c.avatars, (_) {
      if (c.avatars.isEmpty) return;

      final index = c.selectedAvatar.value == null
          ? 0
          : c.avatars.indexOf(c.selectedAvatar.value!);

      _pageController.jumpToPage(
        index.clamp(0, c.avatars.length - 1),
      );

      _page.value = index.toDouble();
    });


    final initialIndex = c.selectedAvatar.value == null
        ? 0
        : c.avatars.indexOf(c.selectedAvatar.value!);

    _pageController = PageController(
      initialPage: initialIndex.clamp(0, c.avatars.length - 1),
      viewportFraction: 0.55,
    );

    // 🔥 DÒNG QUAN TRỌNG
    _page.value = initialIndex.toDouble();

    _pageController.addListener(() {
      _page.value = _pageController.page ?? _page.value;
    });
  }


  @override
  void dispose() {
    _pageController.dispose();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 230,
            child: PageView.builder(
              controller: _pageController,
              itemCount: c.avatars.length,
              onPageChanged: (i) {
                c.selectAndSave(c.avatars[i]);
              },
              itemBuilder: (context, index) {
                return ValueListenableBuilder<double>(
                  valueListenable: _page,
                  builder: (_, page, __) {
                    final diff = (page - index).abs();
                    final scale = (1 - diff * 0.35).clamp(0.75, 1.0);
                    final opacity = (1 - diff * 0.6).clamp(0.4, 1.0);
      
                    final isSelected =
                        c.selectedAvatar.value == c.avatars[index];
      
                    return Center(
                      child: Opacity(
                        opacity: opacity,
                        child: Transform.scale(
                          scale: scale,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (isSelected)
                                Container(
                                  width: 150,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.cyanAccent.withOpacity(0.8),
                                        blurRadius: 30,
                                        spreadRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
      
                              CircleAvatar(
                                radius: isSelected ? 70 : 55,
                                backgroundImage: AssetImage(
                                  "assets/anonymous/${c.avatars[index]}.png",
                                ),
                              ),
      
                              if (isSelected)
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF2ED8FF),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      color: Colors.black,
                                      size: 18,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          /// ===== NAME =====
          Obx(() {
            final key = c.selectedAvatar.value;
            return Text(
              key == null ? "" : c.getAvatarName(key),
              style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppTheme.darkTextPrimary
                  ),
              );
            }),
      
          const SizedBox(height: 24),
          ValueListenableBuilder<double>(
            valueListenable: _page,
            builder: (_, page, __) {
              return AvatarPageIndicator(
                count: c.avatars.length,
                page: page,
              );
            },
          ),
        ],
      ),
    );
  }

}
