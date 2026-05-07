import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:matchu_app/firebase_options.dart';
import 'package:matchu_app/models/chat_notification_payload.dart';
import 'package:matchu_app/theme/app_theme.dart';

typedef NotificationTapHandler =
    Future<void> Function(ChatNotificationPayload payload);

class AppNotificationService {
  AppNotificationService._();

  static const String androidNotificationIcon = 'ic_stat_matchu';
  static const String _androidLargeIcon = 'matchu_notification_large_icon';
  static const String _fallbackTitle = 'Tin nh\u1EAFn m\u1EDBi';
  static const String _fallbackBody = 'B\u1EA1n c\u00F3 tin nh\u1EAFn m\u1EDBi';

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
    ChatNotificationPayload payload, {
    DateTime? sentAt,
  }) async {
    if (!isSupportedPlatform) return;
    if (!_initialized) {
      await initialize(onTap: (_) async {});
    }

    final receivedAt = (sentAt ?? DateTime.now()).toLocal();
    final title = _resolveNotificationTitle(payload);
    final body = _resolveNotificationBody(payload);
    final sender = Person(
      name: title,
      key: payload.senderUid,
      important: true,
      icon: const DrawableResourceAndroidIcon(_androidLargeIcon),
    );

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
          color: AppTheme.primaryColor,
          largeIcon: const DrawableResourceAndroidBitmap(_androidLargeIcon),
          showWhen: true,
          when: receivedAt.millisecondsSinceEpoch,
          number: payload.pendingCount > 1 ? payload.pendingCount : null,
          shortcutId: payload.roomId,
          tag: payload.roomId,
          groupKey: 'matchu_chat_messages',
          ticker: '$title: $body',
          styleInformation: MessagingStyleInformation(
            const Person(name: 'MatchU', key: 'matchu'),
            conversationTitle: title,
            groupConversation: false,
            messages: [Message(body, receivedAt, sender)],
          ),
        ),
        iOS: DarwinNotificationDetails(
          threadIdentifier: payload.roomId,
          subtitle: title,
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

  static String _resolveNotificationTitle(ChatNotificationPayload payload) {
    final senderName = _normalizeNotificationText(payload.senderName);
    if (senderName != null && senderName.isNotEmpty) {
      return senderName;
    }

    final title = _normalizeNotificationText(payload.title);
    if (title != null && title.isNotEmpty) {
      return title;
    }

    return _fallbackTitle;
  }

  static String _resolveNotificationBody(ChatNotificationPayload payload) {
    final body = _normalizeNotificationText(payload.body);
    if (body != null && body.isNotEmpty) {
      return body;
    }

    return _fallbackBody;
  }

  static String? _normalizeNotificationText(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return _repairUtf8Mojibake(trimmed);
  }

  static String _repairUtf8Mojibake(String input) {
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

  static bool _looksLikeMojibake(String text) {
    return text.contains('Ã') ||
        text.contains('Æ') ||
        text.contains('Ð') ||
        text.contains('â€') ||
        text.contains('áº') ||
        text.contains('á»') ||
        text.contains('\uFFFD');
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!AppNotificationService.isSupportedPlatform) return;

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final payload = ChatNotificationPayload.fromRemoteMessage(message);
  if (payload == null) return;

  if (message.notification == null) {
    await AppNotificationService.showLocalChatNotification(
      payload,
      sentAt: message.sentTime,
    );
  }
}
