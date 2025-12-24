import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:matchu_app/controllers/chat/rating_controller.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/rating/star_rating.dart';
import 'package:matchu_app/views/report/report_bottom_sheet.dart';
import 'package:matchu_app/widgets/circle_icon_button.dart';

class RatingView extends StatelessWidget {
  RatingView({super.key});

  final controller = Get.find<RatingController>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorTheme = theme.colorScheme;
    const double appBarCircleSize = 45;
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            "Đánh giá",
            style: theme.textTheme.headlineSmall,
          ),
          leading: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Center(
              child: SizedBox(
                width: appBarCircleSize,
                height: appBarCircleSize,
                child: CircleIconButton(
                  size: appBarCircleSize,
                  iconSize: 20,
                  icon: Iconsax.flag,
                  iconColor: AppTheme.errorColor,
                  onTap: () {
                    Get.bottomSheet(
                      ReportBottomSheet(
                        roomId: controller.roomId,
                        toUid: controller.toUid,
                      ),
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                    );
                  },
                ),
              ),
            ),
          ),
          actions: [
            Center(
              child: SizedBox(
                width: appBarCircleSize,
                height: appBarCircleSize,
                child: CircleIconButton(
                  size: appBarCircleSize,
                  iconSize: 20,
                  icon: Iconsax.forward,
                  onTap: controller.skip,
                ),
              ),
            ),
            const SizedBox(width: 12), // spacing với mép phải
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              SizedBox(height: 24),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3), // độ dày viền
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? AppTheme.darkBorder 
                            : AppTheme.lightBorder, // màu viền
                        width: 2,
                      ),
                    ),
                    child: Obx(() {
                      final key = controller.otherAnonymousAvatar.value;
                      return CircleAvatar(
                        radius: 50,
                        backgroundImage: key == null
                            ? const AssetImage("assets/anonymous/placeholder.png")
                            : AssetImage("assets/anonymous/$key.png"),
                      );
                    }),
                  ),

                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                        color: AppTheme.successColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 15,
                        color: Colors.white,
                      ),
                    )),
                ],
              ),

              SizedBox(height: 32),

              Text(
                "Người lạ",
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 14),

              Text(
                "Cuộc trò chuyện đã kết thúc.\nBạn cảm thấy trải nghiệm thế nào?",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),

              const SizedBox(height: 36),

              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: colorTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).brightness == Brightness.dark 
                            ? AppTheme.darkBorder 
                            : AppTheme.lightBorder,),
                ),

                child: Column(
                  children: [
                    Obx(() => StarRating(
                          rating: controller.rating.value,
                          onChanged: (v) => controller.rating.value = v,
                        )
                      ),
                    const SizedBox(height: 12),
                    Obx(() => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xFFFFC107).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            ratingText(controller.rating.value),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Color.fromARGB(255, 255, 147, 7),
                              fontWeight: FontWeight.bold
                            ),
                          ),
                        )
                      ),
                  ],
                ),
              ),
              const Spacer(),
              
              Obx(() => SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: controller.isSubmitting.value
                      ? null
                      : controller.submit,
                  child: controller.isSubmitting.value
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text("Gửi đánh giá →"),
                ),
              )),

              const SizedBox(height: 46),
            ],
          ),
        ),
      ),
    );
  }
  String ratingText(double v) {
    switch (v.round()) {
      case 1:
        return "Rất tệ";
      case 2:
        return "Tệ";
      case 3:
        return "Bình thường";
      case 4:
        return "Tốt";
      case 5:
        return "Rất tốt";
      default:
        return "";
    }
  }
}
