import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:matchu_app/models/queue_user_model.dart';

class MatchingService {
  final _rtdb = FirebaseDatabase.instance.ref();
  final _firestore = FirebaseFirestore.instance;

  String get baseUrl =>
      "https://matchu-5bd75-default-rtdb.asia-southeast1.firebasedatabase.app";

  // ================= CONFIG =================
  final int nodeTtlMs = 60 * 1000; // 60s
  final int scanLimit = 15; // top-N scan

  static const String queuePath = "queues/unifiedQueue";

  // =========================================================
  // PUBLIC: MATCH OR ENQUEUE
  // =========================================================
  Future<String?> matchUser(QueueUserModel seeker) async {
    final room = await _tryMatch(seeker);
    if (room != null) return room;

    await enqueue(seeker);
    return null;
  }

  // =========================================================
  // CORE MATCH LOGIC (single queue)
  // =========================================================
  Future<String?> _tryMatch(QueueUserModel seeker) async {
    DataSnapshot snap;

    // Always cleanup first to remove invalid entries
    final cleanedCount = await cleanupQueue();
    if (cleanedCount > 0) {
      print("🧹 Cleaned $cleanedCount invalid entries");
    }

    // Read all entries without orderBy (safer, avoids type errors)
    try {
      snap = await _rtdb.child(queuePath).get();
    } catch (e) {
      print("❌ Read queue error → $e");
      return null;
    }

    if (!snap.exists) return null;
    
    // Additional safety check: if snap.value is a String, something is wrong
    if (snap.value is String) {
      print("⚠️ Queue data is corrupted at root level (String instead of Map)");
      return null;
    }

    // Collect and sort entries (always use manual sorting to avoid orderBy errors)
    List<MapEntry<DataSnapshot, Map<String, dynamic>>> validEntries = [];
    
    // Collect all valid entries
    for (final child in snap.children) {
        try {
          dynamic raw = child.value;
          
          // Handle null
          if (raw == null) {
            await child.ref.remove();
            continue;
          }
          
          // Handle invalid data types (String, null, etc.)
          if (raw is String) {
            // Try to parse if it's a JSON string
            try {
              raw = jsonDecode(raw);
            } catch (_) {
              // Invalid JSON string, remove it
              await child.ref.remove();
              continue;
            }
          }
          
          // Ensure we have a Map after parsing
          if (raw is! Map) {
            await child.ref.remove();
            continue;
          }

          // Safely convert to Map<String, dynamic>
          try {
            final data = Map<String, dynamic>.from(raw);
            final createdAt = data["createdAt"] ?? 0;
            // Only add if not expired
            if (DateTime.now().millisecondsSinceEpoch - createdAt <= nodeTtlMs) {
              validEntries.add(MapEntry(child, data));
            } else {
              await child.ref.remove();
            }
          } catch (e) {
            // Failed to convert, remove invalid entry
            print("⚠️ Failed to convert queue entry to Map: $e");
            await child.ref.remove();
            continue;
          }
        } catch (e) {
          print("❌ Error processing queue entry: $e");
          try {
            await child.ref.remove();
          } catch (_) {}
          continue;
        }
      }
      
    // Sort by createdAt and take only scanLimit
    validEntries.sort((a, b) {
      final aTime = a.value["createdAt"] ?? 0;
      final bTime = b.value["createdAt"] ?? 0;
      return aTime.compareTo(bTime);
    });
    validEntries = validEntries.take(scanLimit).toList();

    try {
      // Process entries
      final childrenToProcess = validEntries.map((e) => e.key).toList();
      
      for (final child in childrenToProcess) {
      try {
        // Data is already extracted and validated in validEntries
        Map<String, dynamic> data;
        try {
          final entry = validEntries.firstWhere((e) => e.key == child);
          data = entry.value;
        } catch (_) {
          // Entry not found in validEntries, skip
          continue;
        }
        
        final oppUid = data["uid"];

        if (oppUid == null || oppUid == seeker.uid) continue;

        // TTL
        final createdAt = data["createdAt"] ?? 0;
        if (DateTime.now().millisecondsSinceEpoch - createdAt > nodeTtlMs) {
          await child.ref.remove();
          continue;
        }

        // mutual condition
        if (!_mutualMatch(seeker, data)) continue;

        final url = "$baseUrl/$queuePath/${child.key}.json";

        // --- GET with ETag ---
        final getRes = await _retryHttp(() => http.get(
              Uri.parse("$url?print=pretty"),
              headers: {"X-Firebase-ETag": "true"},
            ));

        if (getRes == null || getRes.statusCode != 200) continue;

        final etag = getRes.headers["etag"];
        if (etag == null || etag == "null") continue;

        dynamic node;
        try {
          node = jsonDecode(getRes.body);
        } catch (e) {
          print("⚠️ Failed to parse HTTP response: $e");
          continue;
        }
        
        if (node is! Map || node["claimedBy"] != null) continue;

        // --- CLAIM ---
        node["claimedBy"] = seeker.uid;
        node["claimedAt"] = DateTime.now().millisecondsSinceEpoch;

        final putRes = await _retryHttp(() => http.put(
              Uri.parse(url),
              headers: {
                "Content-Type": "application/json",
                "If-Match": etag,
              },
              body: jsonEncode(node),
            ));

        if (putRes == null || putRes.statusCode != 200) continue;

        print("🎯 CLAIM SUCCESS: ${seeker.uid} ↔ $oppUid");

        // online check
        if (!await _isUserAvailable(oppUid)) {
          await _retryHttp(
              () => http.delete(Uri.parse(url), headers: {"If-Match": etag}));
          continue;
        }

        final roomId = await _createTempChat(seeker.uid, oppUid);

        // cleanup
        await _retryHttp(
            () => http.delete(Uri.parse(url), headers: {"If-Match": etag}));
        await dequeue(seeker.uid);

        print("🎉 MATCH SUCCESS → $roomId");
        return roomId;
      } catch (e) {
        print("❌ Error processing queue entry: $e");
        // Try to remove the problematic entry
        try {
          await child.ref.remove();
        } catch (_) {}
        continue;
      }
    }
    } catch (e) {
      print("❌ Error iterating queue children: $e");
      return null;
    }

    return null;
  }

  // =========================================================
  // MUTUAL CONDITION (đối xứng)
  // =========================================================
  bool _mutualMatch(QueueUserModel A, Map<String, dynamic> B) {
    final bGender = B["gender"];
    final bTarget = B["targetGender"];
    if (bGender == null || bTarget == null) return false;

    bool accept(String target, String gender) =>
        target == "random" || target == gender;

    return accept(A.targetGender, bGender) &&
        accept(bTarget, A.gender);
  }

  // =========================================================
  // ENQUEUE
  // =========================================================
  Future<void> enqueue(QueueUserModel q) async {
    final ref = _rtdb.child(queuePath).push();
    final now = DateTime.now().millisecondsSinceEpoch;

    final node = {
      "uid": q.uid,
      "gender": q.gender,
      "targetGender": q.targetGender,
      "avgChatRating": q.avgChatRating,
      "interests": q.interests,
      "createdAt": now,
      "claimedBy": null,
    };

    print("📌 ENQUEUE unifiedQueue → ${q.uid}");
    await ref.set(node);
  }

  // =========================================================
  // CLEANUP INVALID QUEUE ENTRIES
  // =========================================================
  Future<int> cleanupQueue() async {
    int cleanedCount = 0;
    try {
      final snap = await _rtdb.child(queuePath).get();
      if (!snap.exists) return 0;

      for (final child in snap.children) {
        try {
          dynamic raw = child.value;
          
          bool shouldRemove = false;
          
          // Check null
          if (raw == null) {
            shouldRemove = true;
          }
          // Check String (invalid format)
          else if (raw is String) {
            // Try to parse JSON
            try {
              raw = jsonDecode(raw);
              // If parsed successfully, check if it's a valid Map
              if (raw is! Map) {
                shouldRemove = true;
              } else {
                // Check if Map has required fields
                try {
                  final data = Map<String, dynamic>.from(raw);
                  final createdAt = data["createdAt"] ?? 0;
                  // Remove if expired or missing uid
                  if (data["uid"] == null || 
                      (createdAt != 0 && DateTime.now().millisecondsSinceEpoch - createdAt > nodeTtlMs)) {
                    shouldRemove = true;
                  }
                } catch (_) {
                  shouldRemove = true;
                }
              }
            } catch (_) {
              // Invalid JSON string
              shouldRemove = true;
            }
          }
          // Check if not Map
          else if (raw is! Map) {
            shouldRemove = true;
          }
          // Check Map validity
          else {
            try {
              final data = Map<String, dynamic>.from(raw);
              final createdAt = data["createdAt"] ?? 0;
              // Remove if expired or missing uid
              if (data["uid"] == null || 
                  (createdAt != 0 && DateTime.now().millisecondsSinceEpoch - createdAt > nodeTtlMs)) {
                shouldRemove = true;
              }
            } catch (_) {
              shouldRemove = true;
            }
          }
          
          if (shouldRemove) {
            await child.ref.remove();
            cleanedCount++;
          }
        } catch (e) {
          // Error processing entry, remove it
          try {
            await child.ref.remove();
            cleanedCount++;
          } catch (_) {}
        }
      }
      
      if (cleanedCount > 0) {
        print("🧹 Cleaned up $cleanedCount invalid queue entries");
      }
    } catch (e) {
      print("❌ Error in cleanupQueue: $e");
    }
    return cleanedCount;
  }

  // =========================================================
  // REMOVE USER FROM QUEUE
  // =========================================================
  Future<void> dequeue(String uid) async {
    try {
      final snap = await _rtdb.child(queuePath).get();
      if (!snap.exists) return;

      for (final child in snap.children) {
        try {
          dynamic raw = child.value;
          
          // Handle null
          if (raw == null) continue;
          
          // Handle String data (try to parse JSON)
          if (raw is String) {
            try {
              raw = jsonDecode(raw);
            } catch (_) {
              // Invalid JSON, skip this entry
              continue;
            }
          }
          
          // Ensure we have a Map before accessing
          if (raw is Map) {
            try {
              final data = Map<String, dynamic>.from(raw);
              if (data["uid"] == uid) {
                await child.ref.remove();
              }
            } catch (e) {
              // Failed to convert, skip
              print("⚠️ Failed to convert queue entry in dequeue: $e");
              continue;
            }
          }
        } catch (e) {
          print("❌ Error processing queue entry in dequeue: $e");
          continue;
        }
      }
    } catch (e) {
      print("❌ Error in dequeue: $e");
    }
  }

  // =========================================================
  // ONLINE CHECK
  // =========================================================
  Future<bool> _isUserAvailable(String uid) async {
    final doc = await _firestore.collection("users").doc(uid).get();
    if (!doc.exists) return false;

    final data = doc.data()!;
    if (data["activeStatus"] == "online") return true;

    final last = data["lastActiveAt"];
    if (last != null) {
      final dt = last.toDate();
      if (DateTime.now().difference(dt).inSeconds <= 120) return true;
    }
    return false;
  }

  // =========================================================
  // CREATE ROOM
  // =========================================================
  Future<String> _createTempChat(String a, String b) async {
    final ref = _firestore.collection("tempChats").doc();

    await ref.set({
      "roomId": ref.id,
      "userA": a,
      "userB": b,
      "createdAt": FieldValue.serverTimestamp(),
      "status": "active",
    });

    return ref.id;
  }

  // =========================================================
  // HTTP RETRY
  // =========================================================
  Future<http.Response?> _retryHttp(
    Future<http.Response> Function() req, {
    int retries = 3,
  }) async {
    for (int i = 0; i < retries; i++) {
      try {
        return await req();
      } catch (_) {
        await Future.delayed(Duration(milliseconds: 150 * (i + 1)));
      }
    }
    return null;
  }
}
