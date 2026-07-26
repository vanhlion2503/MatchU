import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/bindings/feed/post_detail_binding.dart';
import 'package:matchu_app/bindings/feed/post_search_binding.dart';
import 'package:matchu_app/bindings/feed/post_search_results_binding.dart';
import 'package:matchu_app/bindings/notification/notification_inbox_binding.dart';
import 'package:matchu_app/bindings/user/account_security_binding.dart';
import 'package:matchu_app/bindings/security/chat_passcode_security_binding.dart';
import 'package:matchu_app/bindings/profile/profile_privacy_binding.dart';
import 'package:matchu_app/bindings/verification/face_verification_binding.dart';
import 'package:matchu_app/bindings/chat/temp_chat_binding.dart';
import 'package:matchu_app/bindings/matching/video_matching_binding.dart';
import 'package:matchu_app/bindings/matching/video_matching_admission_binding.dart';
import 'package:matchu_app/controllers/auth/avatar_controller.dart';
import 'package:matchu_app/controllers/chat/chat_user_cache_controller.dart';
import 'package:matchu_app/controllers/chat/rating_controller.dart';
import 'package:matchu_app/controllers/chat/unread_controller.dart';
import 'package:matchu_app/controllers/feed/feed_controller.dart';
import 'package:matchu_app/controllers/feed/feed_engagement_controller.dart';
import 'package:matchu_app/controllers/feed/post_chat_share_controller.dart';
import 'package:matchu_app/controllers/feed/post_restrictions_controller.dart';
import 'package:matchu_app/controllers/nearby/nearby_controller.dart';
import 'package:matchu_app/controllers/notification/notification_unread_controller.dart';
import 'package:matchu_app/controllers/qr/profile_qr_controller.dart';
import 'package:matchu_app/controllers/reputation/reputation_controller.dart';
import 'package:matchu_app/controllers/search/search_user_controller.dart';
import 'package:matchu_app/controllers/user/account_settings_controller.dart';
import 'package:matchu_app/controllers/user/presence_controller.dart';
import 'package:matchu_app/controllers/user/user_controller.dart';
import 'package:matchu_app/routes/app_router.dart';
import 'package:matchu_app/views/auth/enroll_phone_view.dart';
import 'package:matchu_app/views/auth/forgot_password_view.dart';
import 'package:matchu_app/views/auth/otp_enroll_view.dart';
import 'package:matchu_app/views/auth/verify_email_view.dart';
import 'package:matchu_app/views/chat/list_chat/chat_list_view.dart';
import 'package:matchu_app/views/chat/call/screens/call_view.dart';
import 'package:matchu_app/views/chat/call/screens/incoming_call_view.dart';
import 'package:matchu_app/views/chat/long_chat/chat_view.dart';
import 'package:matchu_app/views/matching/matching_view.dart';
import 'package:matchu_app/views/matching/video_matching_view.dart';
import 'package:matchu_app/views/notification/notification_inbox_view.dart';
import 'package:matchu_app/views/rating/rating_view.dart';
import 'package:matchu_app/views/reputation/reputation_view.dart';
import 'package:matchu_app/views/qr/profile_qr_view.dart';
import 'package:matchu_app/views/search/search_user_view.dart';
import 'package:matchu_app/views/search/post_search_view.dart';
import 'package:matchu_app/views/search/post_search_results_view.dart';
import 'package:matchu_app/views/setting/display_mode_view.dart';
import 'package:matchu_app/views/setting/language_view.dart';
import 'package:matchu_app/views/setting/edit_profile_view.dart';
import 'package:matchu_app/views/setting/account_security_view.dart';
import 'package:matchu_app/views/setting/account_security_hub_view.dart';
import 'package:matchu_app/views/setting/chat_passcode/chat_passcode_security_view.dart';
import 'package:matchu_app/views/setting/chat_passcode/change_chat_passcode_view.dart';
import 'package:matchu_app/views/setting/chat_passcode/forgot_chat_passcode_view.dart';
import 'package:matchu_app/views/setting/chat_passcode/new_chat_passcode_view.dart';
import 'package:matchu_app/views/setting/restriction_list_view.dart';
import 'package:matchu_app/views/setting/following_list_privacy_view.dart';
import 'package:matchu_app/views/setting/private_account_view.dart';
import 'package:matchu_app/views/splash_view.dart';
import 'package:matchu_app/views/verification/face_verification_view.dart';
import 'package:matchu_app/views/auth/login_view.dart';
import 'package:matchu_app/views/auth/register_view.dart';
import 'package:matchu_app/views/auth/otp_login_view.dart';
import 'package:matchu_app/views/auth/complete_profile_view.dart';
import 'package:matchu_app/views/feed/post_detail_view.dart';
import 'package:matchu_app/views/home_view.dart';
import 'package:matchu_app/controllers/main/main_controller.dart';
import 'package:matchu_app/views/main_view.dart';
import 'package:matchu_app/views/welcome_view.dart';
import 'package:matchu_app/views/chat/temp_chat/temp_chat_view.dart';

class AppPages {
  static const initial = AppRouter.splash;

  static final routes = [
    GetPage(
      name: AppRouter.splash,
      page: () => const SplashView(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    ),
    GetPage(name: AppRouter.register, page: () => const RegisterView()),
    GetPage(name: AppRouter.verifyEmail, page: () => const VerifyEmailView()),
    GetPage(name: AppRouter.enrollPhone, page: () => const EnrollPhoneView()),
    GetPage(name: AppRouter.otpEnroll, page: () => const OtpEnrollView()),
    GetPage(name: AppRouter.login, page: () => const LoginView()),

    GetPage(name: AppRouter.otpLogin, page: () => const OtpLoginView()),
    GetPage(
      name: AppRouter.completeProfile,
      page: () => const CompleteProfileView(),
    ),
    GetPage(
      name: AppRouter.welcome,
      page: () => const WelcomeView(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    ),

    GetPage(
      name: AppRouter.forgotPassword,
      page: () => const ForgotPasswordView(),
    ),

    // GetPage(name: AppRouter.changePassword, page: ()=> const ChangePasswordView()),
    GetPage(
      name: AppRouter.home,
      page: () => const HomeView(),
      binding: BindingsBuilder(() {
        Get.put(NotificationUnreadController());
        Get.lazyPut<FeedController>(() => FeedController(), fenix: true);
        Get.lazyPut<FeedEngagementController>(
          () => FeedEngagementController(),
          fenix: true,
        );
        Get.lazyPut<PostRestrictionsController>(
          () => PostRestrictionsController(),
          fenix: true,
        );
      }),
    ),
    GetPage(
      name: AppRouter.postDetail,
      page: () => const PostDetailView(),
      binding: PostDetailBinding(),
    ),
    GetPage(
      name: AppRouter.searchPosts,
      page: () => const PostSearchView(),
      binding: PostSearchBinding(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 240),
    ),
    GetPage(
      name: AppRouter.postSearchResults,
      page: () => const PostSearchResultsView(),
      binding: PostSearchResultsBinding(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 240),
    ),
    GetPage(
      name: AppRouter.notifications,
      page: () => const NotificationInboxView(),
      binding: NotificationInboxBinding(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 240),
    ),
    GetPage(
      name: AppRouter.main,
      page: () => MainView(),
      binding: BindingsBuilder(() {
        Get.put(MainController());
        VideoMatchingAdmissionBinding().dependencies();

        // 🔹 User-related (CHỈ INIT SAU LOGIN)
        Get.put(UserController());
        Get.put(PresenceController());
        Get.put(UnreadController());
        Get.put(NotificationUnreadController());

        // 🔹 Chat / cache
        Get.put(ChatUserCacheController());
        Get.lazyPut<PostChatShareController>(
          () => PostChatShareController(),
          fenix: true,
        );

        // 🔹 Feature
        Get.put(AvatarController());
        Get.lazyPut<FeedController>(() => FeedController(), fenix: true);
        Get.lazyPut<FeedEngagementController>(
          () => FeedEngagementController(),
          fenix: true,
        );

        // 🔥 NEARBY
        Get.put(NearbyController());
      }),
    ),
    GetPage(
      name: AppRouter.searchUser,
      page: () => SearchUserView(),
      binding: BindingsBuilder(() {
        Get.put(SearchUserController());
      }),
    ),
    GetPage(
      name: AppRouter.profileQr,
      page: () => const ProfileQrView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<ProfileQrController>(() => ProfileQrController());
      }),
    ),

    GetPage(name: AppRouter.displayMode, page: () => DisplayModeView()),
    GetPage(name: AppRouter.language, page: () => const LanguageView()),

    GetPage(
      name: AppRouter.accountSecurity,
      page: () => const AccountSecurityView(),
      binding: AccountSecurityBinding(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 240),
    ),
    GetPage(
      name: AppRouter.accountInformation,
      page:
          () => const AccountSecurityDetailView(
            section: AccountSecurityDetailSection.account,
          ),
      binding: AccountSecurityBinding(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: AppRouter.passwordSecurity,
      page:
          () => const AccountSecurityDetailView(
            section: AccountSecurityDetailSection.password,
          ),
      binding: AccountSecurityBinding(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: AppRouter.deviceSessions,
      page:
          () => const AccountSecurityDetailView(
            section: AccountSecurityDetailSection.devices,
          ),
      binding: AccountSecurityBinding(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: AppRouter.deleteAccount,
      page:
          () => const AccountSecurityDetailView(
            section: AccountSecurityDetailSection.deleteAccount,
          ),
      binding: AccountSecurityBinding(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: AppRouter.chatPinSecurity,
      page: () => const ChatPasscodeSecurityView(),
      binding: ChatPasscodeSecurityBinding(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: AppRouter.changeChatPin,
      page: () => const ChangeChatPasscodeView(),
      binding: ChatPasscodeSecurityBinding(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: AppRouter.forgotChatPin,
      page: () => const ForgotChatPasscodeView(),
      binding: ChatPasscodeSecurityBinding(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: AppRouter.recoverChatPin,
      page:
          () => const NewChatPasscodeView(
            mode: ChatPasscodeRecoveryMode.faceRecovery,
          ),
      binding: ChatPasscodeSecurityBinding(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: AppRouter.resetChatPin,
      page:
          () => const NewChatPasscodeView(
            mode: ChatPasscodeRecoveryMode.destructiveReset,
          ),
      binding: ChatPasscodeSecurityBinding(),
      transition: Transition.cupertino,
    ),

    GetPage(
      name: AppRouter.restrictionList,
      page: () => const RestrictionListView(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<PostRestrictionsController>()) {
          Get.lazyPut<PostRestrictionsController>(
            () => PostRestrictionsController(),
          );
        }
      }),
    ),

    GetPage(
      name: AppRouter.followingListPrivacy,
      page: () => const FollowingListPrivacyView(),
      binding: ProfilePrivacyBinding(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: AppRouter.privateAccount,
      page: () => const PrivateAccountView(),
      binding: ProfilePrivacyBinding(),
      transition: Transition.cupertino,
    ),

    GetPage(
      name: AppRouter.faceVerification,
      page: () => const FaceVerificationView(),
      binding: FaceVerificationBinding(),
    ),

    GetPage(name: AppRouter.matching, page: () => MatchingView()),

    GetPage(
      name: AppRouter.videoMatching,
      page: () => const VideoMatchingView(),
      binding: VideoMatchingBinding(),
    ),

    GetPage(
      name: AppRouter.rating,
      page: () => RatingView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<RatingController>(() => RatingController());
      }),
    ),
    GetPage(
      name: AppRouter.reputation,
      page: () => const ReputationView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<ReputationController>(() => ReputationController());
      }),
    ),

    /// TEMP CHAT ROOM
    GetPage(
      name: AppRouter.tempChat,
      page: () => const TempChatView(),
      binding: TempChatBinding(),
    ),

    GetPage(
      name: AppRouter.chat,
      page: () => const ChatView(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 260),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<PresenceController>()) {
          Get.put(PresenceController());
        }
        if (!Get.isRegistered<ChatUserCacheController>()) {
          Get.put(ChatUserCacheController());
        }
      }),
    ),
    GetPage(name: AppRouter.incomingCall, page: () => const IncomingCallView()),
    GetPage(name: AppRouter.call, page: () => const CallView()),

    GetPage(name: AppRouter.chatList, page: () => ChatListView()),

    GetPage(
      name: AppRouter.editProfile,
      page: () => EditProfileView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<AccountSettingsController>(
          () => AccountSettingsController(),
        );
      }),
    ),
  ];
}
