import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

class AnonymousAvatarController extends GetxController {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// ===== AVATAR + TÊN (KEY KỸ THUẬT → TÊN HIỂN THỊ) =====
  static const Map<String, String> male = {
    "avt_01": "Bạch Dương (Aries)",
    "avt_02": "Kim Ngưu (Taurus)",
    "avt_03": "Cự Giải (Cancer)",
    "avt_04": "Bảo Bình (Aquarius)",
    "avt_05": "Song Tử (Gemini)",
    "avt_06": "Thiên Bình (Libra)",
    "avt_07": "Sư Tử (Leo)",
    "avt_08": "Song Ngư (Pisces)",
    "avt_09": "Xử Nữ (Virgo)",
    "avt_10": "Bọ Cạp (Scorpio)",
    "avt_11": "Ma Kết (Capricorn)",
    "avt_12": "Nhân Mã (Sagittarius)",
  };

  static const Map<String, String> female = {
    "avt_13": "Bạch Dương (Aries)",
    "avt_14": "Kim Ngưu (Taurus)",
    "avt_15": "Cự Giải (Cancer)",
    "avt_16": "Song Tử (Gemini)",
    "avt_17": "Song Ngư (Pisces)",
    "avt_18": "Thiên Bình (Libra)",
    "avt_19": "Xử Nữ (Virgo)",
    "avt_20": "Sư Tử (Leo)",
    "avt_21": "Ma Kết (Capricorn)",
    "avt_22": "Bọ Cạp (Scorpio)",
    "avt_23": "Ma Kết (Capricorn)",
    "avt_24": "Bảo Bình (Aquarius)",
  };

  /// ===== AVATAR DÙNG TRONG UI =====
  final RxList<String> avatars = <String>[].obs;
  final selectedAvatar = RxnString();
  final RxnString gender = RxnString();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  String? _pendingAvatarKey;

  bool get isSelected => selectedAvatar.value != null;

  @override
  void onInit() {
    super.onInit();

    // ✅ CHỈ MỘT LISTENER DUY NHẤT
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        _reset();
      } else {
        load();
      }
    });

    ever<String?>(gender, (g) {
      if (g == null) return;

      _applyGender(g);
    });
  }

  void _applyGender(String g) {
    avatars.clear();

    if (g == "male" || g == "nam") {
      avatars.assignAll(male.keys.toList());
    } else if (g == "female" || g == "nữ" || g == "nu") {
      avatars.assignAll(female.keys.toList());
    } else {
      avatars.assignAll(male.keys.toList()); // fallback
    }

    if (avatars.isNotEmpty) {
      final current = selectedAvatar.value;
      if (current == null || !avatars.contains(current)) {
        selectedAvatar.value = avatars.first;
      }
    }
  }

  void _reset() {
    avatars.clear();
    selectedAvatar.value = null;
    gender.value = null;
    _pendingAvatarKey = null;
    _userSub?.cancel();
    _userSub = null;
  }

  // ====================================================
  // 🔥 CLEANUP FOR LOGOUT
  // ====================================================
  void reset() {
    _reset();
  }

  Future<void> resetAsync() async {
    final sub = _userSub;
    _userSub = null;
    if (sub != null) {
      await sub.cancel();
    }
    avatars.clear();
    selectedAvatar.value = null;
    gender.value = null;
    _pendingAvatarKey = null;
  }

  /// ===== LOAD USER + SET AVATAR LIST =====
  Future<void> load() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final snap = await _db.collection("users").doc(uid).get();
    if (!snap.exists) return;

    final rawGender = snap.data()?["gender"];
    final newGender = rawGender?.toString().toLowerCase().trim();

    if (newGender != null && newGender != gender.value) {
      gender.value = newGender; // 🔥 trigger ever()
    }

    final savedAvatar = snap.data()?["anonymousAvatar"];
    if (savedAvatar != null && avatars.contains(savedAvatar)) {
      selectedAvatar.value = savedAvatar;
    }

    if (_pendingAvatarKey != null) {
      await _commitPendingAvatar(uid);
    }

    _listenUserDoc(uid);
  }

  /// ===== CHỌN + LƯU AVATAR =====
  Future<void> selectAndSave(String avatarKey) async {
    selectedAvatar.value = avatarKey;
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      _pendingAvatarKey = avatarKey;
      return;
    }

    _pendingAvatarKey = null;

    await _db.collection("users").doc(uid).update({
      "anonymousAvatar": avatarKey,
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  /// ===== LẤY TÊN HIỂN THỊ (UI GỌI HÀM NÀY) =====

  void _listenUserDoc(String uid) {
    _userSub?.cancel();
    _userSub = _db.collection("users").doc(uid).snapshots().listen((snap) {
      if (!snap.exists) return;
      final data = snap.data();
      if (data == null) return;

      final rawGender = data["gender"];
      final newGender = rawGender?.toString().toLowerCase().trim();
      if (newGender != null && newGender != gender.value) {
        gender.value = newGender;
      }

      final savedAvatar = data["anonymousAvatar"];
      if (savedAvatar != null && avatars.contains(savedAvatar)) {
        selectedAvatar.value = savedAvatar;
      }
    });
  }

  Future<void> _commitPendingAvatar(String uid) async {
    final pending = _pendingAvatarKey;
    if (pending == null) return;

    _pendingAvatarKey = null;
    selectedAvatar.value = pending;

    await _db.collection("users").doc(uid).update({
      "anonymousAvatar": pending,
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  // Display name for avatar key
  String getAvatarName(String avatarKey) {
    if (gender.value == "male" || gender.value == "nam") {
      return male[avatarKey] ?? "Avatar ẩn danh";
    }

    if (gender.value == "female" ||
        gender.value == "nữ" ||
        gender.value == "nu") {
      return female[avatarKey] ?? "Avatar ẩn danh";
    }

    return "Avatar ẩn danh";
  }
}
