import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:matchu_app/firebase_options.dart';
import 'package:matchu_app/models/chat_notification_payload.dart';

typedef NotificationTapHandler =
    Future<void> Function(ChatNotificationPayload payload);

class AppNotificationService {
  AppNotificationService._();

  static const String androidNotificationIcon = 'ic_stat_matchu';

  static const AndroidNotificationChannel chatChannel =
      AndroidNotificationChannel(
        'chat_messages',
        'Chat Messages',
        description: 'Thong bao tin nhan MatchU',
        importance: Importance.high,
      );

  static final FlutterLocalNotificationsPlugin localNotifications =
      FlutterLocalNotificationsPlugin();

  static NotificationTapHandler? _tapHandler;
  static bool _initialized = false;

  static bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> initialize({
    required NotificationTapHandler onTap,
  }) async {
    _tapHandler = onTap;

    if (!isSupportedPlatform || _initialized) {
      return;
    }

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings(androidNotificationIcon),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        defaultPresentAlert: true,
        defaultPresentBadge: true,
        defaultPresentBanner: true,
        defaultPresentList: true,
        defaultPresentSound: true,
      ),
    );

    await localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (response) async {
        final payload = ChatNotificationPayload.fromPayloadString(
          response.payload,
        );
        if (payload == null) return;
        await _tapHandler?.call(payload);
      },
    );

    await localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(chatChannel);

    _initialized = true;
  }

  static Future<void> showLocalChatNotification(
    ChatNotificationPayload payload,
  ) async {
    if (!isSupportedPlatform) return;
    if (!_initialized) {
      await initialize(onTap: (_) async {});
    }

    final title = payload.title ?? payload.senderName ?? 'Tin nhan moi';
    final body = payload.body ?? 'Ban co tin nhan moi';

    await localNotifications.show(
      id: payload.roomId.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          chatChannel.id,
          chatChannel.name,
          icon: androidNotificationIcon,
          channelDescription: chatChannel.description,
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.message,
          tag: payload.roomId,
          groupKey: 'matchu_chat_messages',
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: DarwinNotificationDetails(
          threadIdentifier: payload.roomId,
          presentAlert: true,
          presentBadge: true,
          presentBanner: true,
          presentList: true,
          presentSound: true,
        ),
      ),
      payload: payload.toPayloadString(),
    );
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!AppNotificationService.isSupportedPlatform) return;

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final payload = ChatNotificationPayload.fromRemoteMessage(message);
  if (payload == null) return;

  if (message.notification == null) {
    await AppNotificationService.showLocalChatNotification(payload);
  }
}
