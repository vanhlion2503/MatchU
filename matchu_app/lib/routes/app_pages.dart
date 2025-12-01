import 'package:get/get.dart';
import 'package:matchu_app/routes/app_router.dart';
import 'package:matchu_app/views/splash_view.dart';

class AppPages {
  static const initial = AppRouter.splash;

  static final routes = [
    GetPage(name: AppRouter.splash, page: ()=> const SplashView()),
    // GetPage(name: AppRouter.login, page: ()=> const LoginView()),
    // GetPage(name: AppRouter.register, page: ()=> const RegisterView()),
    // GetPage(name: AppRouter.forgotPassword, page: ()=> const ForgotPasswordView()),
    // GetPage(name: AppRouter.changePassword, page: ()=> const ChangePasswordView()),
    // GetPage(
    //   name: AppRouter.home, 
    //   page: ()=> const HomeView(),
    //   binding: BindingsBuilder((){
    //     Get.put(HomeController());
    //   })
    // ),
    // GetPage(
    //   name: AppRouter.main, 
    //   page: ()=> const MainView(),
    //   binding: BindingsBuilder((){
    //     Get.put(MainController());
    //   })
    // ),
    // GetPage(
    //   name: AppRouter.profile, 
    //   page: ()=> const ProfileView(),
    //   binding: BindingsBuilder((){
    //     Get.put(ProfileController());
    //   })
    // ),
  ];
}