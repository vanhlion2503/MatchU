import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/matching/matching_controller.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:simple_ripple_animation/simple_ripple_animation.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/widgets/matching_widget/line_paint.dart';
import 'package:matchu_app/widgets/animated_dots.dart';

class MatchingView extends StatefulWidget {
  const MatchingView({super.key});

  @override
  State<MatchingView> createState() => _MatchingViewState();
}

class _MatchingViewState extends State<MatchingView> 
    with SingleTickerProviderStateMixin{
  final controller = Get.find<MatchingController>();
  late final AnimationController? _lineController;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Nếu đang match hoặc đã match thì chỉ hiển thị UI
      if (controller.isSearching.value ||
          controller.isMatched.value) {
        return;
      }

      controller.isMinimized.value = false;

      final args = Get.arguments as Map<String, dynamic>?;

      if (args != null && args["targetGender"] is String) {
        controller.startMatching(
          targetGender: args["targetGender"],
        );
      }
    });

    _lineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }


  @override
  void dispose() {
    _lineController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Đang tìm người chat",
          style: theme.textTheme.headlineSmall,
          ),
        leading: Container(
          margin: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.surface.withOpacity(0.6),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
            ),
          ),
          child: IconButton(
            icon: const Icon(Iconsax.arrow_left_2, size: 25,),
            onPressed: () async {
              await controller.stopMatching();
              Get.back();
            },
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.surface.withOpacity(0.6),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
              ),
            ),
            child: IconButton(
              icon: const Icon(Iconsax.home_2, size: 25,),
              onPressed: () {
                controller.isMinimized.value = true;
                Get.back();
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Obx(() {
            if (controller.isMatched.value) {
              return _matchedSuccessView(theme);
            }
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children:[
                  const SizedBox(height: 60),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _meAvatar(),
                      SizedBox(width: 8,),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          // Khoảng cách giữa 2 avatar
                          final lineWidth = MediaQuery.of(context).size.width * 0.4;
        
                          return SizedBox(
                            width: lineWidth,
                            height: 60,
                            child: _centerLine(),
                          );
                        },
                      ),
                      SizedBox(width: 8,),
                      _strangerRipple(theme),
                    ],
                  ),
                  const SizedBox(height: 100),
                  Text(
                    "Đang tìm bạn chat...",
                    style: theme.textTheme.titleLarge
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark 
                          ? AppTheme.darkTextPrimary
                          : AppTheme.lightTextPrimary,
                          ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Chúng tôi đang kết nối bạn với một người ngẫu nhiên phù hợp.",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.hintColor),
                  ),
        
                  SizedBox(height: 40),
        
                  AnimatedDots(
                    color: theme.colorScheme.primary,
                    size: 10,
                  ),
        
                  SizedBox(height: 24),
        
                  _matchTimer(theme),
        
                  const Spacer(),
                  Obx(() {
                    return AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: controller.canCancel.value ? 1 : 0,
                      child: IgnorePointer(
                        ignoring: !controller.canCancel.value,
                        child: SizedBox(
                          width: 300,
                          height: 60,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.error,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () async {
                              await controller.stopMatching();
                              Get.back();
                            },
                            child: const Text("Hủy tìm kiếm"),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 50),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
  Widget _meAvatar() {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark 
                            ? AppTheme.darkBorder 
                            : AppTheme.lightBorder, // 👈 màu viền
                  width: 3,
                ),
              ),
              child: const CircleAvatar(
                radius: 38,
                backgroundImage: NetworkImage("https://i.pravatar.cc/300"),
              ),
            ),
            Positioned(
              top: 65,
              right: 2,
              child: Container(
                width: 15,
                  height: 15,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.background,
                      width: 2,
                    ),
                  ),
              ))
          ],
        ),
      ],
    );
  }

  Widget _centerLine() {
    final color = Theme.of(context).colorScheme;

    if (_lineController == null) {
      return const SizedBox(); // 👈 tránh crash
    }

    return AnimatedBuilder(
      animation: _lineController!,
      builder: (context, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: DashedLinePainter(
                  color: color.outline.withOpacity(0.3),
                  progress: _lineController!.value,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.surface.withOpacity(0.8),
                border: Border.all(
                  color: color.outline.withOpacity(0.15),
                ),
              ),
              child: Icon(
                Icons.swap_horiz,
                size: 20,
                color: color.onSurface,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _strangerRipple(ThemeData theme) {
    final borderColor = theme.brightness == Brightness.dark
        ? AppTheme.darkBorder
        : AppTheme.lightBorder;

    return Column(
      children: [
        RippleAnimation(
          color: borderColor.withOpacity(0.35),
          minRadius: 25, // lớn hơn avatar 1 chút cho đẹp
          ripplesCount: 3,
          duration: const Duration(seconds: 3),
          repeat: true,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: borderColor,
                    width: 3,
                  ),
                ),
                child: CircleAvatar(
                  radius: 38,
                  backgroundColor: theme.colorScheme.surfaceVariant,
                  child: Icon(
                    Icons.help_outline,
                    color: theme.hintColor,
                    size: 32,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _matchTimer(ThemeData theme){
    return Obx((){
      final seconds = controller.elapsedSeconds.value;
      final min = seconds ~/ 60;
      final sec = seconds % 60;

      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 100),
        child: Text(
        "${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}",
        key: ValueKey(seconds),
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 22,
          letterSpacing: 2,
          color: Theme.of(context).brightness == Brightness.dark 
                        ? AppTheme.darkTextPrimary
                        : AppTheme.lightTextPrimary,
        ),
      ),
        );
    });
  }
  Widget _matchedSuccessView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          /// 🎉 ICON SCALE + FADE
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.7, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            builder: (_, scale, child) {
              return Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: scale.clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withOpacity(0.12),
              ),
              child: Icon(
                Iconsax.heart,
                size: 46,
                color: theme.colorScheme.primary,
              ),
            ),
          ),

          const SizedBox(height: 24),

          /// 🎯 TITLE
          Text(
            "🎉 Đã kết nối!",
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkTextPrimary
                  : AppTheme.lightTextPrimary,
            ),
          ),

          const SizedBox(height: 8),

          /// 📝 SUBTEXT
          AnimatedOpacity(
            opacity: 1,
            duration: const Duration(milliseconds: 400),
            child: Text(
              "Đang chuyển vào phòng chat…",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ),

          const SizedBox(height: 24),

          /// ⏳ LOADING NHẸ
          AnimatedDots(
            color: theme.colorScheme.primary,
            size: 8,
          ),
        ],
      ),
    );
  }

}


