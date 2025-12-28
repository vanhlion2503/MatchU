import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:get_storage/get_storage.dart';
import 'package:matchu_app/controllers/auth/avatar_controller.dart';
import 'package:matchu_app/controllers/chat/anonymous_avatar_controller.dart';
import 'package:matchu_app/controllers/chat/chat_user_cache_controller.dart';
import 'package:matchu_app/controllers/chat/unread_controller.dart';
import 'package:matchu_app/controllers/user/user_controller.dart';
import 'package:matchu_app/firebase_options.dart';
import 'package:matchu_app/routes/app_pages.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/controllers/theme_controller.dart';
import 'package:matchu_app/widgets/global_matching_bubble.dart';
import 'package:matchu_app/controllers/matching/matching_controller.dart';
import 'package:firebase_app_check/firebase_app_check.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ 1. INIT FIREBASE ĐÚNG CÁCH (CHỈ 1 LẦN)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ 2. ACTIVATE APP CHECK (SAU FIREBASE)
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );

  // ✅ 3. LOCAL STORAGE
  await GetStorage.init();

  // ✅ 4. GLOBAL CONTROLLERS
  Get.put(ThemeController(), permanent: true);
  Get.put(AuthController(), permanent: true);
  Get.put(MatchingController(), permanent: true);
  Get.put(AvatarController(), permanent: true);
  Get.put(AnonymousAvatarController(), permanent: true);
  Get.put(UserController(), permanent: true);
  Get.put(ChatUserCacheController(), permanent: true);
  Get.put(UnreadController(), permanent: true);

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

          // ⭐ QUAN TRỌNG NHẤT
          builder: (context, child) {
            return Stack(
              children: [
                child!,

                GlobalMatchingBubble(),
              ],
            );
          },
        ));
  }
}

