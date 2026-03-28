import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/chat/chat_controller.dart';
import 'package:matchu_app/controllers/chat/chat_user_cache_controller.dart';
import 'package:matchu_app/controllers/main/main_controller.dart';
import 'package:matchu_app/models/chat_notification_payload.dart';
import 'package:matchu_app/routes/app_router.dart';
import 'package:matchu_app/services/notification/app_notification_service.dart';
import 'package:matchu_app/services/security/device_service.dart';
import 'package:matchu_app/services/user/presence_service.dart';

enum NotificationScreenContext { other, chatList, chatRoom }

class NotificationController extends GetxController {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundMessageSub;
  StreamSubscription<RemoteMessage>? _messageOpenedSub;

  NotificationScreenContext _screenContext = NotificationScreenContext.other;
  String? _activeRoomId;
  bool _isForeground = true;
  bool _isInitialized = false;
  bool _initialMessageChecked = false;

  ChatNotificationPayload? _pendingNavigation;
  String? _lastHandledNavigationKey;
  int? _lastHandledNavigationAtMs;

  static const int _navigationDedupWindowMs = 1500;

  bool get supportsNotifications => AppNotificationService.isSupportedPlatform;

  Future<void> initialize() async {
    if (_isInitialized || !supportsNotifications) {
      return;
    }

    _isInitialized = true;

    await AppNotificationService.initialize(onTap: _handleLocalTap);
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
      _pendingNavigation = localLaunchPayload;
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
      if (payload == null) return;
      _enqueueNavigation(payload, allowImmediateRedirect: true);
    });

    if (!_initialMessageChecked) {
      _initialMessageChecked = true;
      final initialMessage = await _messaging.getInitialMessage();
      final payload =
          initialMessage == null
              ? null
              : ChatNotificationPayload.fromRemoteMessage(initialMessage);
      if (payload != null) {
        _pendingNavigation = payload;
      }
    }

    _authSub = _auth.authStateChanges().listen(_handleAuthChanged);

    if (_auth.currentUser != null) {
      await _handleAuthChanged(_auth.currentUser);
    }
  }

  Future<void> _handleAuthChanged(User? user) async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;

    if (user == null || !supportsNotifications) {
      return;
    }

    final settings = await _requestPermissionAndReadSettings();
    await _syncCurrentToken(settings: settings);

    _tokenRefreshSub = _messaging.onTokenRefresh.listen((token) async {
      final latestSettings = await _messaging.getNotificationSettings();
      await _upsertDeviceNotificationState(
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
    required NotificationSettings settings,
  }) async {
    final token = await _messaging.getToken();
    await _upsertDeviceNotificationState(token: token, settings: settings);
  }

  Future<void> _upsertDeviceNotificationState({
    required NotificationSettings settings,
    String? token,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final deviceId = await DeviceService.getDeviceId();
    final pushEnabled = _isPushAuthorized(settings.authorizationStatus);

    await _db
        .collection('users')
        .doc(user.uid)
        .collection('devices')
        .doc(deviceId)
        .set({
          'platform': _platformName(),
          'pushEnabled': pushEnabled,
          'notificationPermission': _authorizationStatusToString(
            settings.authorizationStatus,
          ),
          'notificationUpdatedAt': FieldValue.serverTimestamp(),
          'lastActiveAt': FieldValue.serverTimestamp(),
          if (token != null && token.isNotEmpty) 'fcmToken': token,
          if (token != null && token.isNotEmpty)
            'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final payload = ChatNotificationPayload.fromRemoteMessage(message);
    if (payload == null) return;
    if (_shouldSuppressNotification(payload.roomId)) return;

    final resolvedPayload = payload.copyWith(
      title:
          payload.title ??
          message.notification?.title ??
          payload.senderName ??
          'Tin nhan moi',
      body: payload.body ?? message.notification?.body ?? 'Ban co tin nhan moi',
    );

    _showForegroundSnackbar(resolvedPayload);
  }

  void _showForegroundSnackbar(ChatNotificationPayload payload) {
    final context = Get.context;
    if (context == null) {
      unawaited(AppNotificationService.showLocalChatNotification(payload));
      return;
    }

    Get.closeAllSnackbars();
    Get.snackbar(
      payload.title ?? 'Tin nhan moi',
      payload.body ?? 'Ban co tin nhan moi',
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 4),
      backgroundColor: Theme.of(context).colorScheme.surface,
      colorText: Theme.of(context).colorScheme.onSurface,
      margin: const EdgeInsets.all(12),
      borderRadius: 16,
      onTap: (_) {
        _enqueueNavigation(payload, allowImmediateRedirect: true);
      },
      mainButton: TextButton(
        onPressed: () {
          _enqueueNavigation(payload, allowImmediateRedirect: true);
        },
        child: Text(
          'Mo',
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }

  Future<void> _handleLocalTap(ChatNotificationPayload payload) async {
    _enqueueNavigation(payload, allowImmediateRedirect: true);
  }

  void _enqueueNavigation(
    ChatNotificationPayload payload, {
    required bool allowImmediateRedirect,
  }) {
    _pendingNavigation = payload;
    if (allowImmediateRedirect) {
      unawaited(flushPendingNavigation(allowMainRedirect: true));
    }
  }

  Future<void> flushPendingNavigation({
    bool allowMainRedirect = false,
    int retries = 8,
  }) async {
    final payload = _pendingNavigation;
    if (payload == null || _auth.currentUser == null) return;

    final navigationKey = '${payload.roomId}:${payload.messageId ?? ''}';
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_lastHandledNavigationKey == navigationKey &&
        _lastHandledNavigationAtMs != null &&
        nowMs - _lastHandledNavigationAtMs! < _navigationDedupWindowMs) {
      return;
    }

    final hasMainDeps =
        Get.isRegistered<MainController>() &&
        Get.isRegistered<ChatUserCacheController>();

    if (!hasMainDeps) {
      if (!allowMainRedirect) return;

      if (Get.currentRoute != AppRouter.main) {
        await Get.offAllNamed(AppRouter.main);
      }

      if (retries <= 0) return;
      await Future.delayed(const Duration(milliseconds: 350));
      await flushPendingNavigation(
        allowMainRedirect: true,
        retries: retries - 1,
      );
      return;
    }

    final mainController = Get.find<MainController>();
    if (mainController.currentIndex.value != 3) {
      mainController.changePage(3);
    }

    await Future.delayed(const Duration(milliseconds: 120));

    final currentArgs = Get.arguments;
    final currentRoomId =
        currentArgs is Map ? currentArgs['roomId']?.toString() : null;

    _markNavigationHandled(navigationKey);

    if (Get.currentRoute == AppRouter.chat) {
      if (currentRoomId == payload.roomId) {
        final messageId = payload.messageId?.trim();
        if (messageId != null && messageId.isNotEmpty) {
          if (Get.isRegistered<ChatController>(tag: payload.roomId)) {
            Get.find<ChatController>(
              tag: payload.roomId,
            ).focusMessageFromNotification(messageId);
            return;
          }

          await Get.offNamed(
            AppRouter.chat,
            arguments: _buildChatArguments(payload),
          );
        }
        return;
      }

      await Get.offNamed(
        AppRouter.chat,
        arguments: _buildChatArguments(payload),
      );
      return;
    }

    await Get.toNamed(AppRouter.chat, arguments: _buildChatArguments(payload));
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

  static bool _isPushAuthorized(AuthorizationStatus status) {
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  static String _authorizationStatusToString(AuthorizationStatus status) {
    switch (status) {
      case AuthorizationStatus.authorized:
        return 'authorized';
      case AuthorizationStatus.denied:
        return 'denied';
      case AuthorizationStatus.provisional:
        return 'provisional';
      case AuthorizationStatus.notDetermined:
        return 'not_determined';
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
    _pendingNavigation = null;
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
    super.onClose();
  }
}
