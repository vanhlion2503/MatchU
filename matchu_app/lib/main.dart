import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:matchu_app/controllers/auth/auth_gate_controller.dart';
import 'package:matchu_app/controllers/chat/anonymous_avatar_controller.dart';
import 'package:matchu_app/controllers/chat/call_controller.dart';
import 'package:matchu_app/controllers/matching/matching_controller.dart';
import 'package:matchu_app/controllers/system/app_lifecycle_controller.dart';
import 'package:matchu_app/firebase_options.dart';
import 'package:matchu_app/routes/app_pages.dart';
import 'package:matchu_app/services/game/word_chain_service.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/controllers/system/theme_controller.dart';
import 'package:matchu_app/widgets/global_matching_bubble.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ 1. INIT FIREBASE ĐÚNG CÁCH (CHỈ 1 LẦN)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ✅ 2. ACTIVATE APP CHECK (SAU FIREBASE)
  await FirebaseAppCheck.instance.activate(
    providerAndroid: const AndroidDebugProvider(),
    providerApple: const AppleDebugProvider(),
  );

  // ✅ 3. LOAD WORD CHAIN SEED WORDS (🔥 THÊM DÒNG NÀY)
  await WordChainService.loadSeedWords();

  // ✅ 4. LOCAL STORAGE
  await GetStorage.init();

  // ✅ 5. GLOBAL CONTROLLERS
  Get.put(ThemeController(), permanent: true);
  Get.put(AuthController(), permanent: true);
  Get.put(AuthGateController(), permanent: true);
  Get.put(AppLifecycleController(), permanent: true);
  Get.put(CallController(), permanent: true);
  Get.put(AnonymousAvatarController(), permanent: true);
  Get.put(MatchingController(), permanent: true);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeC = Get.find<ThemeController>();

    return Obx(
      () => GetMaterialApp(
        title: "MatchU",
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeC.currentTheme,
        initialRoute: AppPages.initial,
        getPages: AppPages.routes,
        debugShowCheckedModeBanner: false,

        // ⭐ QUAN TRỌNG NHẤT
        builder: (context, child) {
          return Stack(children: [child!, GlobalMatchingBubble()]);
        },
      ),
    );
  }
}
