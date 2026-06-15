import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:get/get.dart';

class PresenceController extends GetxController {
  final _db = FirebaseDatabase.instance.ref();
  static const String defaultOwner = 'default';

  final RxMap<String, bool> _onlineMap = <String, bool>{}.obs;
  final Map<String, StreamSubscription<DatabaseEvent>> _subs = {};
  final Map<String, Set<String>> _ownersByUid = {};

  void listen(String uid, {String owner = defaultOwner}) {
    if (uid.isEmpty) return;
    final owners = _ownersByUid.putIfAbsent(uid, () => <String>{});
    owners.add(owner);

    if (_subs.containsKey(uid)) return;

    final sub = _db.child('status/$uid/online').onValue.listen((event) {
      final val = event.snapshot.value;
      _onlineMap[uid] = val == true;
    });

    _subs[uid] = sub;
  }

  bool isOnline(String uid) => _onlineMap[uid] ?? false;

  void unlistenExcept(Set<String> aliveUids, {String owner = defaultOwner}) {
    final remove =
        _ownersByUid.entries
            .where((entry) => entry.value.contains(owner))
            .map((entry) => entry.key)
            .where((uid) => !aliveUids.contains(uid))
            .toList();

    for (final uid in remove) {
      _removeOwner(uid, owner);
    }
  }

  void unlistenOwner(String owner) {
    final remove =
        _ownersByUid.entries
            .where((entry) => entry.value.contains(owner))
            .map((entry) => entry.key)
            .toList();

    for (final uid in remove) {
      _removeOwner(uid, owner);
    }
  }

  void _removeOwner(String uid, String owner) {
    final owners = _ownersByUid[uid];
    if (owners == null) return;

    owners.remove(owner);
    if (owners.isNotEmpty) return;

    _ownersByUid.remove(uid);
    _subs[uid]?.cancel();
    _subs.remove(uid);
    _onlineMap.remove(uid);
  }

  /// 🔥 CALL WHEN LOGOUT / SWITCH ACCOUNT
  void cleanup() {
    for (final sub in _subs.values) {
      sub.cancel();
    }
    _subs.clear();
    _ownersByUid.clear();
    _onlineMap.clear();
  }

  @override
  void onClose() {
    cleanup();
    super.onClose();
  }
}
