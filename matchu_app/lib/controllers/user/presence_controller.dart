import 'dart:async';
import 'package:get/get.dart';
import 'package:firebase_database/firebase_database.dart';

class PresenceController extends GetxController{
  final _db = FirebaseDatabase.instance.ref();

  final RxMap<String, bool> _onlineMap = <String, bool>{}.obs;
  final Map<String, StreamSubscription> _subs = {};

  void listen(String uid) {
    if (_subs.containsKey(uid)) return;

    final sub = _db
        .child('status/$uid/online')
        .onValue
        .listen((event) {
      _onlineMap[uid] = event.snapshot.value == true;
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

  @override
  void onClose() {
    for (final s in _subs.values) {
      s.cancel();
    }
    _subs.clear();
    super.onClose();
  }
}