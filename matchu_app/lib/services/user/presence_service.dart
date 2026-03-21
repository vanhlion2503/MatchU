import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:matchu_app/services/security/device_service.dart';

class PresenceService {
  static final _db = FirebaseDatabase.instance.ref();
  static final _auth = FirebaseAuth.instance;

  static String get uid => _auth.currentUser!.uid;

  static DatabaseReference _statusRefFor(String uid) => _db.child('status/$uid');

  static DatabaseReference _deviceStatusRefFor(String uid, String deviceId) =>
      _statusRefFor(uid).child('devices/$deviceId');

  static Map<String, dynamic> _devicePayload({
    required bool online,
    required String appState,
    required String screen,
    String? roomId,
  }) {
    return {
      'online': online,
      'appState': appState,
      'screen': screen,
      'roomId': roomId,
      'lastChanged': ServerValue.timestamp,
      'updatedAt': ServerValue.timestamp,
    };
  }

  static Future<void> setOnline() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final statusRef = _statusRefFor(user.uid);
    final deviceId = await DeviceService.getDeviceId();
    final deviceRef = _deviceStatusRefFor(user.uid, deviceId);

    await statusRef.set({
      'online': true,
      'lastChanged': ServerValue.timestamp,
    });
    await deviceRef.set(
      _devicePayload(
        online: true,
        appState: 'foreground',
        screen: 'other',
      ),
    );

    statusRef.onDisconnect().set({
      'online': false,
      'lastChanged': ServerValue.timestamp,
    });
    deviceRef.onDisconnect().set(
      _devicePayload(
        online: false,
        appState: 'background',
        screen: 'other',
      ),
    );
  }

  static Future<void> updateDeviceContext({
    required String appState,
    required String screen,
    String? roomId,
    bool online = true,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final statusRef = _statusRefFor(user.uid);
    final deviceId = await DeviceService.getDeviceId();
    final deviceRef = _deviceStatusRefFor(user.uid, deviceId);

    await deviceRef.set(
      _devicePayload(
        online: online,
        appState: appState,
        screen: screen,
        roomId: roomId,
      ),
    );

    if (online) {
      await statusRef.update({
        'online': true,
        'lastChanged': ServerValue.timestamp,
      });
    }
  }

  static Future<void> setOffline() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final statusRef = _statusRefFor(user.uid);
    final deviceId = await DeviceService.getDeviceId();
    final deviceRef = _deviceStatusRefFor(user.uid, deviceId);

    try {
      await statusRef.set({
        'online': false,
        'lastChanged': ServerValue.timestamp,
      });
      await deviceRef.set(
        _devicePayload(
          online: false,
          appState: 'background',
          screen: 'other',
        ),
      );

      await statusRef.onDisconnect().cancel();
      await deviceRef.onDisconnect().cancel();
    } catch (_) {
      try {
        await statusRef.set({
          'online': false,
          'lastChanged': ServerValue.timestamp,
        });
        await deviceRef.set(
          _devicePayload(
            online: false,
            appState: 'background',
            screen: 'other',
          ),
        );
      } catch (_) {}
    }
  }

  static Future<void> setOfflineForUid(String uid) async {
    final statusRef = _statusRefFor(uid);

    try {
      await statusRef.set({
        'online': false,
        'lastChanged': ServerValue.timestamp,
      });

      await statusRef.onDisconnect().cancel();
    } catch (_) {}
  }
}
