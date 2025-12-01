import 'dart:ffi';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/routes/app_router.dart';
import 'package:matchu_app/theme/app_theme.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> with TickerProviderStateMixin {
  @override
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  void initState(){
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),  
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _animationController.forward();

    // _checkAuthAndNavigate();
  }
  // void _checkAuthAndNavigate()async{
  //   await Future.delayed(Duration(seconds: 2));

  //   final authController = Get.put(AuthController(), permanent: true);

  //   await Future.delayed(Duration(milliseconds: 500));

  //   if (authController.isAuthenticated){
  //     Get.offAllNamed(AppRouter.main);
  //   }
  // }
  void dispose(){
    _animationController.dispose();
    super.dispose();
  }
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: AnimatedBuilder(
          animation: _animationController, 
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation, 
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      child:Image.asset(
                      'assets/icon/Icon.png',
                      width: 160,
                      fit: BoxFit.contain,
                      ),
                    ),
                    RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        children: const [
                          TextSpan(
                            text: "Match",
                            style: TextStyle(
                              color: AppTheme.textPrimaryColor, // Màu cho chữ Match
                            ),
                          ),
                          TextSpan(
                            text: "U",
                            style: TextStyle(
                              color: AppTheme.primaryColor, // Màu khác cho chữ U
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      "Khám phá những mối quan \nhệ mới.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color.fromARGB(255, 112, 112, 112),
                      ),
                    ),
                    const SizedBox(height: 180),
                    SizedBox(
                      width: 350,
                      child: ElevatedButton(
                        onPressed: () {},
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Bắt đầu ngay",
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                            ),
                            SizedBox(width: 10),
                            Icon(
                              Icons.arrow_forward, 
                              size: 21,
                              color: Colors.black,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Đã có tài khoản?",
                        style: TextStyle(
                          fontSize: 16,
                          color: const Color.fromARGB(255, 112, 112, 112),
                          fontWeight: FontWeight.w700,
                        ),
                        ),
                        SizedBox(width: 10),
                        GestureDetector(
                          onTap:(){
                          },
                          child: 
                          const Text("Đăng nhập",
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                          ),
                        )

                      ],
                    )
                  ],
                ),
              ),
            );
          }
        ),
      ),
    );
  }
}
