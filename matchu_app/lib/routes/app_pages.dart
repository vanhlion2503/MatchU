import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/rating_controller.dart';
import 'package:matchu_app/controllers/search/search_user_controller.dart';
import 'package:matchu_app/routes/app_router.dart';
import 'package:matchu_app/views/auth/enroll_phone_view.dart';
import 'package:matchu_app/views/auth/otp_enroll_view.dart';
import 'package:matchu_app/views/auth/verify_email_view.dart';
import 'package:matchu_app/views/chat/chat_view.dart';
import 'package:matchu_app/views/matching/matching_view.dart';
import 'package:matchu_app/views/rating/rating_view.dart';
import 'package:matchu_app/views/search/search_user_view.dart';
import 'package:matchu_app/views/setting/display_mode_view.dart';
import 'package:matchu_app/views/splash_view.dart';
import 'package:matchu_app/views/auth/login_view.dart';
import 'package:matchu_app/views/auth/register_view.dart';
import 'package:matchu_app/views/auth/otp_login_view.dart';
import 'package:matchu_app/views/auth/complete_profile_view.dart';
import 'package:matchu_app/views/home_view.dart';
import 'package:matchu_app/controllers/main/main_controller.dart';
import 'package:matchu_app/views/main_view.dart';
import 'package:matchu_app/views/welcome_view.dart';
import 'package:matchu_app/controllers/matching/matching_controller.dart';
import 'package:matchu_app/views/chat/temp_chat/temp_chat_view.dart';

class AppPages {
  static const initial = AppRouter.splash;

  static final routes = [
    GetPage(
      name: AppRouter.splash, 
      page: ()=> const SplashView(),
    ),
    GetPage(
      name: AppRouter.register, 
      page: ()=> const RegisterView(),
    ),
    GetPage(
      name: AppRouter.verifyEmail, 
      page: () => const VerifyEmailView(),
    ),
    GetPage(
      name: AppRouter.enrollPhone, 
      page: ()=> const EnrollPhoneView(),
    ),
    GetPage(
      name: AppRouter.otpEnroll, 
      page: ()=> const OtpEnrollView(),
    ),
    GetPage(
      name: AppRouter.login, 
      page: ()=> const LoginView(),
    ),

    GetPage(
      name: AppRouter.otpLogin, 
      page: () => const OtpLoginView(),
    ),
    GetPage(
      name: AppRouter.completeProfile, 
      page: () => const CompleteProfileView(),
    ),
    GetPage(
      name: AppRouter.welcome, 
      page: () => const WelcomeView(),
    ),



    // GetPage(name: AppRouter.forgotPassword, page: ()=> const ForgotPasswordView()),
    // GetPage(name: AppRouter.changePassword, page: ()=> const ChangePasswordView()),
    GetPage(
      name: AppRouter.home, 
      page: ()=> const HomeView(),
    ),
    GetPage(
      name: AppRouter.main, 
      page: ()=> MainView(),
      binding: BindingsBuilder((){
        Get.put(MainController());
      })
    ),
    GetPage(
      name: AppRouter.searchUser,
      page: () => SearchUserView(),
      binding: BindingsBuilder(() {
        Get.put(SearchUserController());
      }),
    ),

    GetPage(
      name: AppRouter.displayMode,
      page: () => DisplayModeView(),
    ),
    
    GetPage(
      name: AppRouter.matching,
      page: () => MatchingView(),
      binding: BindingsBuilder(() {
        Get.put(MatchingController());
      }),
    ),

    GetPage(
      name: AppRouter.rating,
      page: () => RatingView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<RatingController>(() => RatingController());
      }),
    ),


    /// TEMP CHAT ROOM
    GetPage(
      name: AppRouter.tempChat,
      page: () => TempChatView(),
    ),

    GetPage(
      name: AppRouter.chat,
      page: () => const ChatView(),
    ),

  ];
}