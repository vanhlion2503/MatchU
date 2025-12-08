import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/routes/app_router.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _animationController.forward();

    Future.microtask(() {
    final authC = Get.put(AuthController(), permanent: true);
    authC.checkInitialLogin();
  });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      /// ✅ PHẦN NỘI DUNG CHÍNH
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            /// LOGO
                            Image.asset(
                              'assets/icon/Icon.png',
                              width: height * 0.18, // ✅ TỰ ĐỘNG CO GIÃN
                              fit: BoxFit.contain,
                            ),

                            const SizedBox(height: 16),

                            /// APP NAME
                            RichText(
                              text: TextSpan(
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineLarge!
                                    .copyWith(fontWeight: FontWeight.bold),
                                children: const [
                                  TextSpan(
                                    text: "Match",
                                    style: TextStyle(
                                      color: AppTheme.textPrimaryColor,
                                    ),
                                  ),
                                  TextSpan(
                                    text: "U",
                                    style: TextStyle(
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            /// SLOGAN
                            Text(
                              "Khám phá những mối quan hệ mới.",
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge!
                                  .copyWith(
                                    color: AppTheme.textSecondaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),

                            SizedBox(height: height * 0.08),

                            /// BUTTON START
                            SizedBox(
                              width: double.infinity,
                              height: 60,
                              child: ElevatedButton(
                                onPressed: () {
                                  Get.toNamed(AppRouter.register);
                                },
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Bắt đầu ngay",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Icon(
                                      Icons.arrow_forward,
                                      size: 21,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            /// LOGIN REDIRECT
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Đã có tài khoản?",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium!
                                      .copyWith(
                                        color:
                                            AppTheme.textSecondaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () {
                                    Get.toNamed(AppRouter.login);
                                  },
                                  child: Text(
                                    "Đăng nhập",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium!
                                        .copyWith(
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      /// ✅ VERSION Ở ĐÁY MÀN HÌNH (KHÔNG OVERFLOW)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          "Version 1.0.0",
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge!
                              .copyWith(
                                color: AppTheme.textSecondaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
