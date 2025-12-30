import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PresenceService {
  static final _db = FirebaseDatabase.instance.ref();
  static final _auth = FirebaseAuth.instance;

  static String get uid => _auth.currentUser!.uid;

  static DatabaseReference get _statusRef => _db.child('status/$uid');

  /// gọi khi app mở
  static Future<void> setOnline() async {
    await _statusRef.set({
      'online': true,
      'lastChanged': ServerValue.timestamp,
    });

    _statusRef.onDisconnect().set({
      'online': false,
      'lastChanged': ServerValue.timestamp,
    });
  }

  /// gọi khi logout (optional)
  static Future<void> setOffline() async {
    await _statusRef.set({
      'online': false,
      'lastChanged': ServerValue.timestamp,
    });
  }
}