import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

class AnonymousAvatarController extends GetxController{
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  
  final avatars = const [
    "avt_01",
    "avt_02",
    "avt_03",
    "avt_04",
    "avt_05",
    "avt_06",
    "avt_07",
    "avt_08",
    "avt_09",
    "avt_10",
    "avt_11",
    "avt_12",
  ];

  final selectedAvatar = RxnString();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> selectAndSave(String avatarKey) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // 1️⃣ Update local state (UI đổi ngay)
    selectedAvatar.value = avatarKey;

    // 2️⃣ Save Firestore ngay lập tức
    await _db.collection("users").doc(uid).update({
      "anonymousAvatar": avatarKey,
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }


  bool get isSelected => selectedAvatar.value != null;

  Future<void> load() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final snap = await _db.collection("users").doc(uid).get();
    if (!snap.exists) return;

    selectedAvatar.value = snap.data()?["anonymousAvatar"];
  }

}