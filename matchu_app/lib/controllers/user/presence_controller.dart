import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:get/get.dart';

class PresenceController extends GetxController {
  final _db = FirebaseDatabase.instance.ref();

  final RxMap<String, bool> _onlineMap = <String, bool>{}.obs;
  final Map<String, StreamSubscription<DatabaseEvent>> _subs = {};

  void listen(String uid) {
    if (uid.isEmpty) return;
    if (_subs.containsKey(uid)) return;

    final sub = _db
        .child('status/$uid/online')
        .onValue
        .listen((event) {
      final val = event.snapshot.value;
      _onlineMap[uid] = val == true;
    });

    _subs[uid] = sub;
  }

  bool isOnline(String uid) => _onlineMap[uid] ?? false;

  void unlistenExcept(Set<String> aliveUids) {
    final remove = _subs.keys
        .where((uid) => !aliveUids.contains(uid))
        .toList();

    for (final uid in remove) {
      _subs[uid]?.cancel();
      _subs.remove(uid);
      _onlineMap.remove(uid);
    }
  }

  /// 🔥 CALL WHEN LOGOUT / SWITCH ACCOUNT
  void cleanup() {
    for (final sub in _subs.values) {
      sub.cancel();
    }
    _subs.clear();
    _onlineMap.clear();
  }

  @override
  void onClose() {
    cleanup();
    super.onClose();
  }
}
