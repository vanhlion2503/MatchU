import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/anonymous_avatar_controller.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/chat/chat_widget/avatar_page_indicator.dart';

class AvatarCarousel extends StatefulWidget {
  const AvatarCarousel({
    super.key,
    required this.selectedAvatar,
    required this.onChanged,
  });

  final String? selectedAvatar;
  final ValueChanged<String> onChanged;

  @override
  State<AvatarCarousel> createState() => _AvatarCarouselState();
}

class _AvatarCarouselState extends State<AvatarCarousel> {
  late final PageController _pageController;
  final c = Get.find<AnonymousAvatarController>();
  final ValueNotifier<double> _page = ValueNotifier(0);
  late final Worker _avatarsWorker;

  int _indexFor(String? avatarKey) {
    if (c.avatars.isEmpty) return 0;
    if (avatarKey == null) return 0;

    final index = c.avatars.indexOf(avatarKey);
    if (index < 0) return 0;

    return index;
  }

  @override
  void initState() {
    super.initState();

    final initialIndex = _indexFor(widget.selectedAvatar);
    final maxIndex = c.avatars.length - 1;
    final targetIndex = maxIndex < 0 ? 0 : initialIndex.clamp(0, maxIndex);

    _pageController = PageController(
      initialPage: targetIndex,
      viewportFraction: 0.58,
    );

    _page.value = targetIndex.toDouble();

    _pageController.addListener(() {
      final nextPage = _pageController.page;
      if (nextPage == null) return;
      _page.value = nextPage;
    });

    _avatarsWorker = ever<List<String>>(c.avatars, (_) {
      _ensureValidSelection();
      _syncPageWithSelection(jump: true);
    });

    _ensureValidSelection();
  }

  @override
  void didUpdateWidget(covariant AvatarCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectedAvatar != widget.selectedAvatar) {
      _syncPageWithSelection();
    }
  }

  void _ensureValidSelection() {
    if (c.avatars.isEmpty) return;

    final selected = widget.selectedAvatar;
    if (selected != null && c.avatars.contains(selected)) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || c.avatars.isEmpty) return;
      widget.onChanged(c.avatars.first);
    });
  }

  void _syncPageWithSelection({bool jump = false}) {
    if (!mounted || c.avatars.isEmpty || !_pageController.hasClients) {
      return;
    }

    final maxIndex = c.avatars.length - 1;
    final targetIndex = _indexFor(widget.selectedAvatar).clamp(0, maxIndex);
    final currentPage = _pageController.page;
    final isSamePage =
        currentPage != null && (currentPage - targetIndex).abs() < 0.01;

    if (!isSamePage) {
      if (jump) {
        _pageController.jumpToPage(targetIndex);
      } else {
        _pageController.animateToPage(
          targetIndex,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOutCubic,
        );
      }
    }

    _page.value = targetIndex.toDouble();
  }

  @override
  void dispose() {
    _avatarsWorker.dispose();
    _pageController.dispose();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 240,
            child: Obx(() {
              if (c.avatars.isEmpty) {
                return const SizedBox();
              }

              return PageView.builder(
                controller: _pageController,
                itemCount: c.avatars.length,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) {
                  if (index < 0 || index >= c.avatars.length) return;
                  widget.onChanged(c.avatars[index]);
                },
                itemBuilder: (context, index) {
                  final avatarKey = c.avatars[index];

                  return ValueListenableBuilder<double>(
                    valueListenable: _page,
                    builder: (_, page, __) {
                      final rawDiff = (page - index).abs();
                      final diff = rawDiff.clamp(0.0, 1.0);
                      final focus = Curves.easeOutCubic.transform(1 - diff);
                      final scale = lerpDouble(0.84, 1.0, focus)!;
                      final opacity = lerpDouble(0.46, 1.0, focus)!;
                      final avatarRadius = lerpDouble(52, 70, focus)!;
                      final liftY = lerpDouble(8, 0, focus)!;
                      final glowSize = lerpDouble(128, 158, focus)!;
                      final isSelected = widget.selectedAvatar == avatarKey;

                      return Center(
                        child: Opacity(
                          opacity: opacity,
                          child: Transform.translate(
                            offset: Offset(0, liftY),
                            child: Transform.scale(
                              scale: scale,
                              child: Stack(
                                alignment: Alignment.center,
                                clipBehavior: Clip.none,
                                children: [
                                  AnimatedOpacity(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOutCubic,
                                    opacity: isSelected ? 1 : 0,
                                    child: Container(
                                      width: glowSize,
                                      height: glowSize,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.cyanAccent.withValues(
                                              alpha: 0.68,
                                            ),
                                            blurRadius: 34,
                                            spreadRadius: 5,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  CircleAvatar(
                                    radius: avatarRadius,
                                    backgroundImage: AssetImage(
                                      'assets/anonymous/$avatarKey.png',
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 15,
                                    right: 15,
                                    child: AnimatedScale(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      curve: Curves.easeOutBack,
                                      scale: isSelected ? 1 : 0,
                                      child: AnimatedOpacity(
                                        duration: const Duration(
                                          milliseconds: 140,
                                        ),
                                        opacity: isSelected ? 1 : 0,
                                        child: Container(
                                          width: 30,
                                          height: 30,
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
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            }),
          ),
          Obx(() {
            final selected = widget.selectedAvatar;
            final label = selected == null ? '' : c.getAvatarName(selected);

            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) {
                final curved = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic,
                );
                return FadeTransition(
                  opacity: curved,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.12),
                      end: Offset.zero,
                    ).animate(curved),
                    child: child,
                  ),
                );
              },
              child: Text(
                label,
                key: ValueKey(label),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.darkTextPrimary,
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
          ValueListenableBuilder<double>(
            valueListenable: _page,
            builder: (_, page, __) {
              return AvatarPageIndicator(count: c.avatars.length, page: page);
            },
          ),
        ],
      ),
    );
  }
}
