import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:matchu_app/models/chat_mute_setting.dart';

class ChatPreferencesRepository {
  ChatPreferencesRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get uid => _auth.currentUser?.uid.trim() ?? '';

  CollectionReference<Map<String, dynamic>> _mutedUsersRef(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('mutedChatUsers');
  }

  Stream<List<ChatMuteSetting>> watchMutedUsers() {
    final currentUid = uid;
    if (currentUid.isEmpty) {
      return Stream<List<ChatMuteSetting>>.value(const <ChatMuteSetting>[]);
    }

    return _mutedUsersRef(currentUid).snapshots().map(
      (snapshot) => snapshot.docs
          .map(ChatMuteSetting.fromDoc)
          .where((setting) => setting.userId.isNotEmpty)
          .toList(growable: false),
    );
  }

  Future<void> muteUser(String userId, {Duration? duration}) async {
    final currentUid = uid;
    final normalizedUserId = userId.trim();
    if (currentUid.isEmpty || normalizedUserId.isEmpty) return;
    if (currentUid == normalizedUserId) {
      throw StateError('Bạn không thể tắt thông báo của chính mình.');
    }

    final now = DateTime.now();
    await _mutedUsersRef(currentUid).doc(normalizedUserId).set({
      'userId': currentUid,
      'mutedUserId': normalizedUserId,
      'mutedAt': FieldValue.serverTimestamp(),
      'mutedUntil':
          duration == null ? null : Timestamp.fromDate(now.add(duration)),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unmuteUser(String userId) async {
    final currentUid = uid;
    final normalizedUserId = userId.trim();
    if (currentUid.isEmpty || normalizedUserId.isEmpty) return;

    await _mutedUsersRef(currentUid).doc(normalizedUserId).delete();
  }
}
