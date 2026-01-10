import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PresenceService {
  static final _db = FirebaseDatabase.instance.ref();
  static final _auth = FirebaseAuth.instance;

  static String get uid => _auth.currentUser!.uid;

  static DatabaseReference _statusRefFor(String uid) => _db.child('status/$uid');

  /// gọi khi app mở
  static Future<void> setOnline() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    final statusRef = _statusRefFor(user.uid);
    
    await statusRef.set({
      'online': true,
      'lastChanged': ServerValue.timestamp,
    });

    statusRef.onDisconnect().set({
      'online': false,
      'lastChanged': ServerValue.timestamp,
    });
  }

  /// 🔥 GỌI KHI LOGOUT - QUAN TRỌNG!
  /// Set offline status trên Realtime Database TRƯỚC KHI signOut
  static Future<void> setOffline() async {
    final user = _auth.currentUser;
    if (user == null) return; // 🔒 Đã logout rồi thì không cần set offline
    
    final statusRef = _statusRefFor(user.uid);
    
    try {
      // 🔥 Set offline status TRƯỚC
      await statusRef.set({
        'online': false,
        'lastChanged': ServerValue.timestamp,
      });
      
      // 🔥 Sau đó cancel onDisconnect handler để tránh conflict
      await statusRef.onDisconnect().cancel();
    } catch (e) {
      // Nếu có lỗi, thử set offline một lần nữa (có thể đã disconnect)
      try {
        await statusRef.set({
          'online': false,
          'lastChanged': ServerValue.timestamp,
        });
      } catch (_) {
        // Ignore - có thể đã disconnect hoàn toàn
      }
    }
  }
  
  /// 🔥 Set offline với uid cụ thể (dùng khi đã logout nhưng cần set offline)
  static Future<void> setOfflineForUid(String uid) async {
    final statusRef = _statusRefFor(uid);
    
    try {
      await statusRef.set({
        'online': false,
        'lastChanged': ServerValue.timestamp,
      });
      
      await statusRef.onDisconnect().cancel();
    } catch (e) {
      // Ignore errors
    }
  }
}