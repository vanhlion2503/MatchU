import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:matchu_app/models/notification/app_notification_model.dart';

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
