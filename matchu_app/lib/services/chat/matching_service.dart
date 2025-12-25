import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:matchu_app/models/queue_user_model.dart';

class MatchingService {
  final _rtdb = FirebaseDatabase.instance.ref();
  final _firestore = FirebaseFirestore.instance;

  static const queuePath = "queues/unifiedQueue";
  static const indexPath = "queues/indexByUid";

  final int scanLimit = 10;
  final int ttlMs = 60 * 1000;

  String get baseUrl =>
      "https://matchu-5bd75-default-rtdb.asia-southeast1.firebasedatabase.app";

  // =========================================================
  // PUBLIC
  // =========================================================
  Future<String?> matchUser(
    QueueUserModel seeker, {
    required String myAnonymousAvatar,
    required String sessionId,
  }) async {
    await _lockSoft(seeker.uid);

    final room = await _tryMatch(seeker, myAnonymousAvatar, sessionId);
    if (room != null) {
      // await _unlock(seeker.uid);
      return room;
    }

    await enqueue(seeker);
    // await _unlock(seeker.uid);
    return null;
  }


  // =========================================================
  // CORE MATCH
  // =========================================================
  Future<String?> _tryMatch(QueueUserModel seeker, String myAnonymousAvatar,String sessionId) async {
    final snap = await _rtdb.child(queuePath).get();
    if (!snap.exists || snap.value is! Map) return null;

    final now = DateTime.now().millisecondsSinceEpoch;

    for (final child in snap.children.take(scanLimit)) {
      if (child.value is! Map) continue;

      final data = Map<String, dynamic>.from(child.value as Map);
      final oppUid = data["uid"];
      final oppSessionId = data["sessionId"];
      final createdAt = data["createdAt"] ?? 0;

      if (oppUid == null ||
          oppUid == seeker.uid ||
          now - createdAt > ttlMs ||
          !_mutual(seeker, data)) {
        continue;
      }

      final url = "$baseUrl/$queuePath/${child.key}.json";

      final getRes = await http.get(
        Uri.parse(url),
        headers: {"X-Firebase-ETag": "true"},
      );

      final etag = getRes.headers["etag"];
      if (etag == null) continue;

      final node = jsonDecode(getRes.body);
      if (node["claimedBy"] != null) continue;

      node["claimedBy"] = seeker.uid;

      final putRes = await http.put(
        Uri.parse(url),
        headers: {
          "If-Match": etag,
          "Content-Type": "application/json",
        },
        body: jsonEncode(node),
      );

      if (putRes.statusCode != 200) continue;

      final roomId = await _createNewRoom(
        seeker.uid,
        oppUid,
        sessionId,        // session của A
        oppSessionId,     // session của B
      );

      await _cleanupAfterMatch(seeker.uid, oppUid, child.key!);
      return roomId;
    }

    return null;
  }

  // =========================================================
  bool _mutual(QueueUserModel A, Map<String, dynamic> B) {
    bool ok(String t, String g) => t == "random" || t == g;
    return ok(A.targetGender, B["gender"]) &&
        ok(B["targetGender"], A.gender);
  }

  // =========================================================
  Future<void> enqueue(QueueUserModel q) async {
    final queueRef = _rtdb.child(queuePath).push();
    final indexRef = _rtdb.child(indexPath).child(q.uid);

    // 1️⃣ set queue
    await queueRef.set({
      "uid": q.uid,
      "gender": q.gender,
      "targetGender": q.targetGender,
      "createdAt": DateTime.now().millisecondsSinceEpoch,
      "claimedBy": null,
      "sessionId": q.sessionId,
    });

    // 2️⃣ set index
    await indexRef.set(queueRef.key);

    // 3️⃣ 🔥 AUTO CLEANUP KHI APP KILL
    queueRef.onDisconnect().remove();
    indexRef.onDisconnect().remove();
  }


  Future<void> dequeue(String uid) async {
    final snap = await _rtdb.child(indexPath).child(uid).get();
    if (!snap.exists) return;

    final key = snap.value.toString();
    await _rtdb.child(queuePath).child(key).remove();
    await _rtdb.child(indexPath).child(uid).remove();
    await _unlock(uid);
  }

  // =========================================================
  Future<void> _lockSoft(String uid) async {
    await _firestore.collection("users").doc(uid).set(
      {"isMatching": true},
      SetOptions(merge: true),
    );
  }

  Future<void> _unlock(String uid) async {
    await _firestore.collection("users").doc(uid).set(
      {"isMatching": false},
      SetOptions(merge: true),
    );
  }

  // =========================================================
  Future<String> _createNewRoom(
    String a,
    String b,
    String sessionA,
    String sessionB,
  ) async {
    final ref = _firestore.collection("tempChats").doc();
    await ref.set({
      "roomId": ref.id,
      "userA": a,
      "userB": b,
      "participants": [a, b],
      "createdAt": FieldValue.serverTimestamp(),
      "sessionA": sessionA, // của userA
      "sessionB": sessionB, // của userB
      "sessionIds": [sessionA, sessionB],
      "status": "active",
      "permanentRoomId": null,
      "anonymousAvatars": {},
    });
    return ref.id;
  }


  Future<void> _cleanupAfterMatch(
      String a, String b, String queueKey) async {
    // Xóa queue entry (của user B)
    await _rtdb.child(queuePath).child(queueKey).remove();
    // Xóa index của cả user A và user B
    await _rtdb.child(indexPath).child(a).remove();
    await _rtdb.child(indexPath).child(b).remove();
    // Chỉ unlock user A (người đang match)
    // User B sẽ tự unlock khi nhận được room mới qua stream listener
    await _unlock(a);
    // Không unlock user B ở đây vì không có quyền ghi vào document của user B
    // User B sẽ tự unlock trong matching_controller khi nhận được room
  }

  // MatchingService.dart
  Future<void> forceUnlock(String uid) async {
    await _firestore.collection("users").doc(uid).set(
      {"isMatching": false},
      SetOptions(merge: true),
    );
  }

}
