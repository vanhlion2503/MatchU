import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:matchu_app/controllers/auth/auth_gate_controller.dart';
import 'package:matchu_app/controllers/feed/post_deep_link_controller.dart';
import 'package:matchu_app/controllers/feed/post_share_controller.dart';
import 'package:matchu_app/controllers/chat/anonymous_avatar_controller.dart';
import 'package:matchu_app/controllers/chat/call_controller.dart';
import 'package:matchu_app/controllers/matching/matching_controller.dart';
import 'package:matchu_app/controllers/matching/video_matching_session_coordinator.dart';
import 'package:matchu_app/controllers/system/app_lifecycle_controller.dart';
import 'package:matchu_app/controllers/system/notification_controller.dart';
import 'package:matchu_app/firebase_options.dart';
import 'package:matchu_app/routes/app_pages.dart';
import 'package:matchu_app/services/game/word_chain_service.dart';
import 'package:matchu_app/services/notification/app_notification_service.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/auth/auth_controller.dart';
import 'package:matchu_app/controllers/system/theme_controller.dart';
import 'package:matchu_app/controllers/system/language_controller.dart';
import 'package:matchu_app/controllers/system/network_controller.dart';
import 'package:matchu_app/translations/app_translations.dart';
import 'package:matchu_app/widgets/global_matching_bubble.dart';
import 'package:matchu_app/widgets/network_offline_overlay.dart';

Future<void> _cleanupAbandonedRegisterFlow() async {
  final box = GetStorage();
  final isRegistering = box.read('isRegistering') == true;
  if (!isRegistering) return;

  final auth = FirebaseAuth.instance;
  final user = auth.currentUser;
  if (user == null) {
    box.remove('isRegistering');
    return;
  }

  try {
    await user.reload();
  } catch (_) {}

  final refreshedUser = auth.currentUser;
  if (refreshedUser == null) {
    box.remove('isRegistering');
    return;
  }

  bool shouldDelete = true;
  try {
    final userDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(refreshedUser.uid)
            .get();
    final isProfileCompleted = userDoc.data()?['isProfileCompleted'] == true;
    shouldDelete = !isProfileCompleted;
  } catch (_) {}

  if (!shouldDelete) {
    box.remove('isRegistering');
    return;
  }

  try {
    await refreshedUser.delete();
  } on FirebaseAuthException {
    try {
      await auth.signOut();
    } catch (_) {}
  } catch (_) {
    try {
      await auth.signOut();
    } catch (_) {}
  } finally {
    box.remove('isRegistering');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ 1. INIT FIREBASE ĐÚNG CÁCH (CHỈ 1 LẦN)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (AppNotificationService.isSupportedPlatform) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // ✅ 2. LOAD WORD CHAIN SEED WORDS (🔥 THÊM DÒNG NÀY)
  await WordChainService.loadSeedWords();

  // ✅ 4. LOCAL STORAGE
  await GetStorage.init();
  await _cleanupAbandonedRegisterFlow();

  // ✅ 5. GLOBAL CONTROLLERS
  Get.put(ThemeController(), permanent: true);
  Get.put(LanguageController(), permanent: true);
  Get.put(AuthController(), permanent: true);
  Get.put(AuthGateController(), permanent: true);
  Get.put(PostShareController(), permanent: true);
  // Register before runApp so cold-start links are not missed.
  Get.put(PostDeepLinkController(), permanent: true);
  Get.put(AppLifecycleController(), permanent: true);
  Get.put(NetworkController(), permanent: true);
  final notificationController = Get.put(
    NotificationController(),
    permanent: true,
  );
  Get.put(CallController(), permanent: true);
  Get.put(AnonymousAvatarController(), permanent: true);
  Get.put(MatchingController(), permanent: true);
  Get.put(VideoMatchingSessionCoordinator(), permanent: true);
  runApp(const MyApp());

  // Notification setup may access the network and request permission. Start it
  // after the first frame so a slow FCM/Firestore call never blocks app launch.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      notificationController.initialize().catchError((Object error) {
        debugPrint('Notification initialization failed: $error');
      }),
    );
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeC = Get.find<ThemeController>();
    final languageC = Get.find<LanguageController>();

    return Obx(
      () => GetMaterialApp(
        title: "MatchU",
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeC.currentTheme,
        translations: AppTranslations(),
        locale: languageC.locale,
        fallbackLocale: const Locale('vi', 'VN'),
        initialRoute: AppPages.initial,
        getPages: AppPages.routes,
        debugShowCheckedModeBanner: false,

        // ⭐ QUAN TRỌNG NHẤT
        builder: (context, child) {
          return Stack(
            children: [
              child!,
              GlobalMatchingBubble(),
              const NetworkOfflineOverlay(),
            ],
          );
        },
      ),
    );
  }
}
