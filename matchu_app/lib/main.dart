import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:get_storage/get_storage.dart';
import 'package:matchu_app/firebase_options.dart';
import 'package:matchu_app/routes/app_pages.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/controllers/theme_controller.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ⭐ Fix duplicate-app — chỉ init Firebase nếu chưa init
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  await GetStorage.init();

  // GetX controllers
  Get.put(ThemeController(), permanent: true);
  Get.put(AuthController(), permanent: true);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeC = Get.find<ThemeController>();

    return Obx(() => GetMaterialApp(
          title: "MatchU",
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeC.currentTheme,
          initialRoute: AppPages.initial,
          getPages: AppPages.routes,
          debugShowCheckedModeBanner: false,
        ));
  }
}
