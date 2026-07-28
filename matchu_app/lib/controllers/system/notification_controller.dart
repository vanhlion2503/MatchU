import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:matchu_app/translations/localized_material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/chat_controller.dart';
import 'package:matchu_app/controllers/chat/chat_user_cache_controller.dart';
import 'package:matchu_app/controllers/feed/post_deep_link_controller.dart';
import 'package:matchu_app/controllers/main/main_controller.dart';
import 'package:matchu_app/models/chat_notification_payload.dart';
import 'package:matchu_app/models/notification/post_engagement_notification_payload.dart';
import 'package:matchu_app/models/notification/admin_notification_payload.dart';
import 'package:matchu_app/routes/app_router.dart';
import 'package:matchu_app/services/notification/app_notification_service.dart';
import 'package:matchu_app/services/notification/push_device_repository.dart';
import 'package:matchu_app/services/notification/admin_notification_navigation.dart';
import 'package:matchu_app/services/user/presence_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

enum NotificationScreenContext { other, chatList, chatRoom }

class NotificationController extends GetxController {
  NotificationController({PushDeviceRepository? pushDeviceRepository})
    : _pushDeviceRepository = pushDeviceRepository ?? PushDeviceRepository();

  static const String _appLogoAssetPath = 'assets/icon/Icon.png';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PushDeviceRepository _pushDeviceRepository;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundMessageSub;
  StreamSubscription<RemoteMessage>? _messageOpenedSub;

  NotificationScreenContext _screenContext = NotificationScreenContext.other;
  String? _activeRoomId;
  bool _isForeground = true;
  bool _isInitialized = false;
  bool _initialMessageChecked = false;
  int _authGeneration = 0;
  String? _activeAuthUid;
  Future<PackageInfo>? _packageInfo;
  AdminNotificationPayload? _pendingAdminNavigation;

  final ListQueue<ChatNotificationPayload> _pendingNavigations = ListQueue();
  bool _isFlushingNavigation = false;
  String? _lastHandledNavigationKey;
  int? _lastHandledNavigationAtMs;
  SnackbarController? _activeNotificationSnackbar;

  static const int _navigationDedupWindowMs = 1500;

  bool get supportsNotifications => AppNotificationService.isSupportedPlatform;

  Future<void> initialize() async {
    if (_isInitialized || !supportsNotifications) {
      return;
    }

    _isInitialized = true;

    await AppNotificationService.initialize(
      onTap: _handleLocalTap,
      onPostTap: _handlePostTap,
      onAdminTap: _handleAdminTap,
    );
    final launchDetails =
        await AppNotificationService.localNotifications
            .getNotificationAppLaunchDetails();
    final localLaunchPayload =
        launchDetails?.didNotificationLaunchApp == true
            ? ChatNotificationPayload.fromPayloadString(
              launchDetails?.notificationResponse?.payload,
            )
            : null;
    if (localLaunchPayload != null) {
      _addPendingNavigation(localLaunchPayload);
    } else if (launchDetails?.didNotificationLaunchApp == true) {
      final postPayload = PostEngagementNotificationPayload.fromPayloadString(
        launchDetails?.notificationResponse?.payload,
      );
      if (postPayload != null) {
        _queuePostNavigation(postPayload);
      } else {
        final adminPayload = AdminNotificationPayload.fromPayloadString(
          launchDetails?.notificationResponse?.payload,
        );
        if (adminPayload != null) {
          await _handleAdminTap(adminPayload);
        }
      }
    }
    await _messaging.setAutoInitEnabled(true);
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: false,
    );

    _foregroundMessageSub = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );
    _messageOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final payload = ChatNotificationPayload.fromRemoteMessage(message);
      if (payload != null) {
        _enqueueNavigation(payload, allowImmediateRedirect: true);
        return;
      }

      final postPayload = PostEngagementNotificationPayload.fromRemoteMessage(
        message,
      );
      if (postPayload != null) {
        _queuePostNavigation(postPayload);
        return;
      }
      final adminPayload = AdminNotificationPayload.fromRemoteMessage(message);
      if (adminPayload != null) {
        unawaited(_handleAdminTap(adminPayload));
      }
    });

    if (!_initialMessageChecked) {
      _initialMessageChecked = true;
      final initialMessage = await _messaging.getInitialMessage();
      final payload =
          initialMessage == null
              ? null
              : ChatNotificationPayload.fromRemoteMessage(initialMessage);
      if (payload != null) {
        _addPendingNavigation(payload);
      } else if (initialMessage != null) {
        final postPayload = PostEngagementNotificationPayload.fromRemoteMessage(
          initialMessage,
        );
        if (postPayload != null) {
          _queuePostNavigation(postPayload);
        } else {
          final adminPayload = AdminNotificationPayload.fromRemoteMessage(
            initialMessage,
          );
          if (adminPayload != null) await _handleAdminTap(adminPayload);
        }
      }
    }

    _authSub = _auth.authStateChanges().listen(_handleAuthChanged);
  }

  /// Re-sync services that have no auth-state event when the network returns.
  /// Firestore listeners reconnect by themselves; FCM token registration and
  /// presence need an explicit write retry.
  Future<void> resumeAfterNetworkRecovery() async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (supportsNotifications) {
      final settings = await _messaging.getNotificationSettings();
      await _syncCurrentToken(userId: user.uid, settings: settings);
    }
    await _syncDeviceContext();
  }

  Future<void> _handleAuthChanged(User? user) async {
    final generation = ++_authGeneration;
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;

    if (user == null || !supportsNotifications) {
      _activeAuthUid = null;
      _pendingNavigations.clear();
      _lastHandledNavigationKey = null;
      _lastHandledNavigationAtMs = null;
      return;
    }

    if (_activeAuthUid != null && _activeAuthUid != user.uid) {
      _pendingNavigations.clear();
      _lastHandledNavigationKey = null;
      _lastHandledNavigationAtMs = null;
    }
    _activeAuthUid = user.uid;

    final settings = await _requestPermissionAndReadSettings();
    if (!_isCurrentAuthOperation(user.uid, generation)) return;
    try {
      await _syncCurrentToken(userId: user.uid, settings: settings);
    } catch (error) {
      // APNs can take a moment to issue its token on a fresh iOS install. Keep
      // the device permission state and let onTokenRefresh finish registration.
      debugPrint('Push token is not ready yet: $error');
      await _upsertDeviceNotificationState(
        userId: user.uid,
        settings: settings,
      );
    }
    if (!_isCurrentAuthOperation(user.uid, generation)) return;

    _tokenRefreshSub = _messaging.onTokenRefresh.listen((token) async {
      if (_auth.currentUser?.uid != user.uid) return;
      final latestSettings = await _messaging.getNotificationSettings();
      await _upsertDeviceNotificationState(
        userId: user.uid,
        token: token,
        settings: latestSettings,
      );
    });

    await PresenceService.updateDeviceContext(
      appState: _isForeground ? 'foreground' : 'background',
      screen: _screenContextValue,
      roomId: _activeRoomId,
      online: true,
    );

    unawaited(flushPendingNavigation());
    if (Get.isRegistered<PostDeepLinkController>()) {
      unawaited(Get.find<PostDeepLinkController>().flushPendingNavigation());
    }
    final pendingAdmin = _pendingAdminNavigation;
    if (pendingAdmin != null) {
      _pendingAdminNavigation = null;
      unawaited(_handleAdminTap(pendingAdmin));
    }
  }

  Future<NotificationSettings> _requestPermissionAndReadSettings() async {
    return _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  Future<void> _syncCurrentToken({
    required String userId,
    required NotificationSettings settings,
  }) async {
    final token = await _messaging.getToken();
    await _upsertDeviceNotificationState(
      userId: userId,
      token: token,
      settings: settings,
    );
  }

  Future<void> _upsertDeviceNotificationState({
    required String userId,
    required NotificationSettings settings,
    String? token,
  }) async {
    if (_auth.currentUser?.uid != userId) return;
    _packageInfo ??= PackageInfo.fromPlatform();
    final packageInfo = await _packageInfo!;

    await _pushDeviceRepository.upsert(
      userId: userId,
      platform: _platformName(),
      settings: settings,
      appVersion: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
      locale: PlatformDispatcher.instance.locale.toLanguageTag(),
      token: token,
    );
  }

  bool _isCurrentAuthOperation(String userId, int generation) {
    return generation == _authGeneration && _auth.currentUser?.uid == userId;
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final payload = ChatNotificationPayload.fromRemoteMessage(message);
    if (payload == null) {
      final postPayload = PostEngagementNotificationPayload.fromRemoteMessage(
        message,
      );
      if (postPayload != null) {
        await AppNotificationService.showLocalPostNotification(postPayload);
        return;
      }
      final adminPayload = AdminNotificationPayload.fromRemoteMessage(message);
      if (adminPayload != null) {
        await AppNotificationService.showLocalAdminNotification(adminPayload);
      }
      return;
    }
    if (_shouldSuppressNotification(payload.roomId)) return;
    final sentAt = message.sentTime ?? DateTime.now();

    final resolvedPayload = payload.copyWith(
      title:
          payload.title ??
          message.notification?.title ??
          payload.senderName ??
          'Tin nh\u1EAFn m\u1EDBi',
      body:
          payload.body ??
          message.notification?.body ??
          'B\u1EA1n c\u00F3 tin nh\u1EAFn m\u1EDBi',
    );

    _showForegroundSnackbar(resolvedPayload, sentAt: sentAt);
  }

  void _showForegroundSnackbar(
    ChatNotificationPayload payload, {
    required DateTime sentAt,
  }) {
    final context = Get.context;
    if (context == null) {
      unawaited(AppNotificationService.showLocalChatNotification(payload));
      return;
    }
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title = _resolveNotificationTitle(payload);
    final body = _resolveNotificationBody(payload);
    final timeLabel = _formatNotificationElapsed(sentAt);

    unawaited(_activeNotificationSnackbar?.close() ?? Future<void>.value());
    _activeNotificationSnackbar = Get.showSnackbar(
      GetSnackBar(
        snackPosition: SnackPosition.TOP,
        snackStyle: SnackStyle.FLOATING,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        borderRadius: 16,
        isDismissible: true,
        backgroundColor: colorScheme.surface,
        padding: EdgeInsets.zero,
        onTap: (_) {
          _enqueueNavigation(payload, allowImmediateRedirect: true);
        },
        messageText: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  _appLogoAssetPath,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.78,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        timeLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.62),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _resolveNotificationTitle(ChatNotificationPayload payload) {
    final senderName = _normalizeNotificationText(payload.senderName);
    if (senderName != null && senderName.isNotEmpty) {
      return senderName;
    }

    final title = _normalizeNotificationText(payload.title);
    if (title != null && title.isNotEmpty) {
      return title;
    }

    return 'Tin nh\u1EAFn m\u1EDBi';
  }

  String _resolveNotificationBody(ChatNotificationPayload payload) {
    final body = _normalizeNotificationText(payload.body);
    if (body != null && body.isNotEmpty) {
      return body;
    }

    return 'B\u1EA1n c\u00F3 tin nh\u1EAFn m\u1EDBi';
  }

  String _formatNotificationElapsed(DateTime sentAt) {
    final diff = DateTime.now().difference(sentAt.toLocal());
    if (diff.isNegative || diff.inSeconds < 60) {
      return 'V\u1EEBa xong';
    }

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} ph\u00FAt';
    }

    if (diff.inHours < 24) {
      return '${diff.inHours} gi\u1EDD';
    }

    if (diff.inDays < 7) {
      return '${diff.inDays} ng\u00E0y';
    }

    final local = sentAt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  String? _normalizeNotificationText(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return _repairUtf8Mojibake(trimmed);
  }

  String _repairUtf8Mojibake(String input) {
    var normalized = input;
    for (var i = 0; i < 2; i++) {
      if (!_looksLikeMojibake(normalized)) {
        break;
      }
      try {
        final repaired = utf8.decode(latin1.encode(normalized));
        if (repaired == normalized) {
          break;
        }
        normalized = repaired;
      } catch (_) {
        break;
      }
    }
    return normalized;
  }

  bool _looksLikeMojibake(String text) {
    return text.contains('Ã') ||
        text.contains('Æ') ||
        text.contains('Ð') ||
        text.contains('â€') ||
        text.contains('áº') ||
        text.contains('á»') ||
        text.contains('\uFFFD');
  }

  Future<void> _handleLocalTap(ChatNotificationPayload payload) async {
    _enqueueNavigation(payload, allowImmediateRedirect: true);
  }

  Future<void> _handlePostTap(PostEngagementNotificationPayload payload) async {
    _queuePostNavigation(payload);
  }

  Future<void> _handleAdminTap(AdminNotificationPayload payload) async {
    if (_auth.currentUser == null) {
      _pendingAdminNavigation = payload;
      return;
    }
    await AdminNotificationNavigation.open(
      actionType: payload.actionType,
      actionValue: payload.actionValue,
    );
  }

  void _queuePostNavigation(PostEngagementNotificationPayload payload) {
    if (!Get.isRegistered<PostDeepLinkController>()) return;
    Get.find<PostDeepLinkController>().queuePostNavigation(payload.postId);
  }

  void _enqueueNavigation(
    ChatNotificationPayload payload, {
    required bool allowImmediateRedirect,
  }) {
    _addPendingNavigation(payload);
    if (allowImmediateRedirect) {
      unawaited(flushPendingNavigation(allowMainRedirect: true));
    }
  }

  Future<void> flushPendingNavigation({
    bool allowMainRedirect = false,
    int retries = 8,
  }) async {
    if (_isFlushingNavigation) return;
    _isFlushingNavigation = true;
    try {
      while (_pendingNavigations.isNotEmpty) {
        final didHandle = await _flushFirstPendingNavigation(
          allowMainRedirect: allowMainRedirect,
          retries: retries,
        );
        if (!didHandle) break;
      }
    } finally {
      _isFlushingNavigation = false;
    }
  }

  Future<bool> _flushFirstPendingNavigation({
    required bool allowMainRedirect,
    required int retries,
  }) async {
    final payload =
        _pendingNavigations.isEmpty ? null : _pendingNavigations.first;
    if (payload == null || _auth.currentUser == null) return false;

    final navigationKey = '${payload.roomId}:${payload.messageId ?? ''}';
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_lastHandledNavigationKey == navigationKey &&
        _lastHandledNavigationAtMs != null &&
        nowMs - _lastHandledNavigationAtMs! < _navigationDedupWindowMs) {
      _pendingNavigations.removeFirst();
      return true;
    }

    final hasMainDeps =
        Get.isRegistered<MainController>() &&
        Get.isRegistered<ChatUserCacheController>();

    if (!hasMainDeps) {
      if (!allowMainRedirect) return false;

      if (Get.currentRoute != AppRouter.main) {
        final opened = await _startNavigation(
          Get.offAllNamed(AppRouter.main),
          expectedRoute: AppRouter.main,
        );
        if (!opened) return false;
      }

      if (retries <= 0) return false;
      await Future.delayed(const Duration(milliseconds: 350));
      return _flushFirstPendingNavigation(
        allowMainRedirect: true,
        retries: retries - 1,
      );
    }

    final mainController = Get.find<MainController>();
    if (mainController.currentIndex.value != 3) {
      mainController.changePage(3);
    }

    await Future.delayed(const Duration(milliseconds: 120));

    final currentArgs = Get.arguments;
    final currentRoomId =
        currentArgs is Map ? currentArgs['roomId']?.toString() : null;

    if (Get.currentRoute == AppRouter.chat) {
      if (currentRoomId == payload.roomId) {
        final messageId = payload.messageId?.trim();
        if (messageId != null && messageId.isNotEmpty) {
          if (Get.isRegistered<ChatController>(tag: payload.roomId)) {
            Get.find<ChatController>(
              tag: payload.roomId,
            ).focusMessageFromNotification(messageId);
            _markNavigationHandled(navigationKey);
            return true;
          }

          final opened = await _startNavigation(
            Get.offNamed(
              AppRouter.chat,
              arguments: _buildChatArguments(payload),
            ),
            expectedRoute: AppRouter.chat,
          );
          if (opened) _markNavigationHandled(navigationKey);
          return opened;
        }
        _markNavigationHandled(navigationKey);
        return true;
      }

      final opened = await _startNavigation(
        Get.offNamed(AppRouter.chat, arguments: _buildChatArguments(payload)),
        expectedRoute: AppRouter.chat,
      );
      if (opened) _markNavigationHandled(navigationKey);
      return opened;
    }

    final opened = await _startNavigation(
      Get.toNamed(AppRouter.chat, arguments: _buildChatArguments(payload)),
      expectedRoute: AppRouter.chat,
    );
    if (opened) _markNavigationHandled(navigationKey);
    return opened;
  }

  Future<bool> _startNavigation(
    Future<dynamic>? navigation, {
    required String expectedRoute,
  }) async {
    if (navigation == null) return false;
    unawaited(navigation.catchError((_) => null));

    for (var attempt = 0; attempt < 12; attempt++) {
      if (Get.currentRoute == expectedRoute) return true;
      await Future.delayed(const Duration(milliseconds: 50));
    }
    return Get.currentRoute == expectedRoute;
  }

  void _addPendingNavigation(ChatNotificationPayload payload) {
    final key = '${payload.roomId}:${payload.messageId ?? ''}';
    final alreadyQueued = _pendingNavigations.any(
      (item) => '${item.roomId}:${item.messageId ?? ''}' == key,
    );
    if (!alreadyQueued) _pendingNavigations.addLast(payload);
  }

  Future<void> setForegroundState(bool isForeground) async {
    _isForeground = isForeground;
    await PresenceService.updateDeviceContext(
      appState: isForeground ? 'foreground' : 'background',
      screen: _screenContextValue,
      roomId: _activeRoomId,
      online: true,
    );
  }

  void setMainTabIndex(int index) {
    if (Get.currentRoute == AppRouter.chat) return;

    if (index == 3) {
      enterChatList();
      return;
    }

    enterOtherScreen();
  }

  void enterChatList() {
    _screenContext = NotificationScreenContext.chatList;
    _activeRoomId = null;
    unawaited(_syncDeviceContext());
  }

  void leaveChatList() {
    if (_screenContext != NotificationScreenContext.chatList) return;
    enterOtherScreen();
  }

  void enterChatRoom(String roomId) {
    _screenContext = NotificationScreenContext.chatRoom;
    _activeRoomId = roomId;
    unawaited(_syncDeviceContext());
  }

  void restoreAfterChatClosed(String roomId) {
    if (_activeRoomId != roomId) return;

    _activeRoomId = null;

    final shouldReturnToChatList =
        (Get.isRegistered<MainController>() &&
            Get.find<MainController>().currentIndex.value == 3) ||
        Get.currentRoute == AppRouter.chatList;

    if (shouldReturnToChatList) {
      enterChatList();
      return;
    }

    enterOtherScreen();
  }

  void enterOtherScreen() {
    _screenContext = NotificationScreenContext.other;
    _activeRoomId = null;
    unawaited(_syncDeviceContext());
  }

  Future<void> _syncDeviceContext() async {
    await PresenceService.updateDeviceContext(
      appState: _isForeground ? 'foreground' : 'background',
      screen: _screenContextValue,
      roomId: _activeRoomId,
      online: true,
    );
  }

  bool _shouldSuppressNotification(String roomId) {
    if (_screenContext == NotificationScreenContext.chatList) {
      return true;
    }

    return _screenContext == NotificationScreenContext.chatRoom &&
        _activeRoomId == roomId;
  }

  String get _screenContextValue {
    switch (_screenContext) {
      case NotificationScreenContext.chatList:
        return 'chat_list';
      case NotificationScreenContext.chatRoom:
        return 'chat_room';
      case NotificationScreenContext.other:
        return 'other';
    }
  }

  static String _platformName() {
    if (kIsWeb) return 'web';

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  void _markNavigationHandled(String navigationKey) {
    if (_pendingNavigations.isNotEmpty) {
      _pendingNavigations.removeFirst();
    }
    _lastHandledNavigationKey = navigationKey;
    _lastHandledNavigationAtMs = DateTime.now().millisecondsSinceEpoch;
  }

  Map<String, dynamic> _buildChatArguments(ChatNotificationPayload payload) {
    final args = <String, dynamic>{'roomId': payload.roomId};
    final messageId = payload.messageId?.trim();
    if (messageId != null && messageId.isNotEmpty) {
      args['messageId'] = messageId;
    }
    return args;
  }

  @override
  void onClose() {
    _authSub?.cancel();
    _tokenRefreshSub?.cancel();
    _foregroundMessageSub?.cancel();
    _messageOpenedSub?.cancel();
    unawaited(_activeNotificationSnackbar?.close() ?? Future<void>.value());
    super.onClose();
  }
}
