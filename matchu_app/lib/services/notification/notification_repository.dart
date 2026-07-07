import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:matchu_app/models/notification/app_notification_model.dart';
import 'package:matchu_app/models/notification/muted_notification_author_model.dart';

class NotificationRepository {
  NotificationRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  static const int defaultLimit = 50;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get uid => _auth.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> _notificationsRef(String userId) =>
      _firestore.collection('users').doc(userId).collection('notifications');

  CollectionReference<Map<String, dynamic>> _mutedAuthorsRef(String userId) =>
      _firestore
          .collection('users')
          .doc(userId)
          .collection('mutedNotificationAuthors');

  Stream<List<AppNotificationModel>> watchNotifications({
    int limit = defaultLimit,
  }) {
    final userId = uid;
    if (userId.isEmpty) return const Stream<List<AppNotificationModel>>.empty();

    return _notificationsRef(userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(AppNotificationModel.fromDoc).toList(),
        );
  }

  Stream<int> watchUnreadCount() {
    final userId = uid;
    if (userId.isEmpty) return const Stream<int>.empty();

    return _notificationsRef(userId)
        .where('readAt', isNull: true)
        .limit(99)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  Future<void> markAsRead(String notificationId) async {
    final userId = uid;
    final normalizedId = notificationId.trim();
    if (userId.isEmpty || normalizedId.isEmpty) return;

    await _notificationsRef(
      userId,
    ).doc(normalizedId).update({'readAt': FieldValue.serverTimestamp()});
  }

  Future<void> markAsUnread(String notificationId) async {
    final userId = uid;
    final normalizedId = notificationId.trim();
    if (userId.isEmpty || normalizedId.isEmpty) return;

    await _notificationsRef(userId).doc(normalizedId).update({'readAt': null});
  }

  Future<void> toggleReadState(AppNotificationModel notification) {
    if (notification.isUnread) {
      return markAsRead(notification.id);
    }
    return markAsUnread(notification.id);
  }

  Future<void> deleteNotification(String notificationId) async {
    final userId = uid;
    final normalizedId = notificationId.trim();
    if (userId.isEmpty || normalizedId.isEmpty) return;

    await _notificationsRef(userId).doc(normalizedId).delete();
  }

  Future<List<MutedNotificationAuthorModel>> fetchMutedAuthors() async {
    final userId = uid;
    if (userId.isEmpty) return const <MutedNotificationAuthorModel>[];

    final snapshot =
        await _mutedAuthorsRef(
          userId,
        ).orderBy('mutedAt', descending: true).get();

    return snapshot.docs
        .map(MutedNotificationAuthorModel.fromDoc)
        .where((item) => item.authorId.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<void> muteAuthorFromNotification(
    AppNotificationModel notification,
  ) async {
    final userId = uid;
    if (userId.isEmpty) {
      throw StateError(
        'B\u1EA1n c\u1EA7n \u0111\u0103ng nh\u1EADp \u0111\u1EC3 t\u1EAFt th\u00F4ng b\u00E1o.',
      );
    }

    final authorId = notification.actorId?.trim() ?? '';
    if (authorId.isEmpty) {
      throw StateError(
        'Kh\u00F4ng t\u00ECm th\u1EA5y ng\u01B0\u1EDDi vi\u1EBFt \u0111\u1EC3 t\u1EAFt th\u00F4ng b\u00E1o.',
      );
    }

    if (authorId == userId) {
      throw StateError(
        'B\u1EA1n kh\u00F4ng th\u1EC3 t\u1EAFt th\u00F4ng b\u00E1o c\u1EE7a ch\u00EDnh m\u00ECnh.',
      );
    }

    await _mutedAuthorsRef(userId).doc(authorId).set({
      'userId': userId,
      'authorId': authorId,
      'displayName': (notification.actorName ?? '').trim(),
      'nickname': (notification.actorNickname ?? '').trim(),
      'avatarUrl': (notification.actorAvatarUrl ?? '').trim(),
      'sourceNotificationId': notification.id.trim(),
      'mutedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> unmuteAuthor(String authorId) async {
    final userId = uid;
    final normalizedAuthorId = authorId.trim();
    if (userId.isEmpty || normalizedAuthorId.isEmpty) return;

    await _mutedAuthorsRef(userId).doc(normalizedAuthorId).delete();
  }

  Future<void> markAllAsRead(List<AppNotificationModel> notifications) async {
    final userId = uid;
    if (userId.isEmpty) return;

    final unread = notifications.where((item) => item.isUnread).toList();
    if (unread.isEmpty) return;

    final batch = _firestore.batch();
    for (final item in unread) {
      batch.update(_notificationsRef(userId).doc(item.id), {
        'readAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}
