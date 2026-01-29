import 'dart:async';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:matchu_app/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class ProfileController extends GetxController{
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final Rx<UserModel?> user = Rxn<UserModel>();
  final isLoading = true.obs;
  
  StreamSubscription<DocumentSnapshot>? _userSub;
  StreamSubscription<User?>? _authSub;
  Timer? _retryTimer;
  
  @override
  void onInit(){
    super.onInit();
    _authSub = _auth.authStateChanges().listen((firebaseUser) {
      if (firebaseUser == null) {
        cleanup();
        return;
      }
      _listenUserProfile(firebaseUser.uid);
    });

    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      _listenUserProfile(currentUser.uid);
    } else {
      isLoading.value = false;
    }
  }

  void _listenUserProfile([String? uid]){
    _userSub?.cancel();
    
    final targetUid = uid ?? _auth.currentUser?.uid;
    if (targetUid == null) {
      isLoading.value = false;
      return;
    }

    isLoading.value = true;
    _userSub = _db.collection('users').doc(targetUid).snapshots().listen(
      (doc) {
        if (doc.data() != null) {
          user.value = UserModel.fromJson(doc.data()!, doc.id);
        } else {
          user.value = null;
        }
        isLoading.value = false;
      },
      onError: (error) {
        // Handle permission or transient errors.
        _userSub?.cancel();
        _userSub = null;
        user.value = null;
        isLoading.value = false;
        if (_retryTimer != null) return;

        final retryUid = _auth.currentUser?.uid;
        if (retryUid == null) return;

        _retryTimer = Timer(const Duration(seconds: 2), () {
          _retryTimer = null;
          if (isClosed) return;
          _listenUserProfile(retryUid);
        });
      },
      cancelOnError: false,
    );
  }

  String get fullName{
    final u = user.value;
    return u?.fullname ?? "";
  }

  String get nickName{
    final u = user.value;
    return u?.nickname ?? "";
  }

  String get getAge {
    final u = user.value;

    if (u == null || u.birthday == null) {
      return "";
    }

    final now = DateTime.now();
    int age = now.year - u.birthday!.year;
    if (now.month < u.birthday!.month ||
      (now.month == u.birthday!.month && now.day < u.birthday!.day)) {
      age--;
    }

    return age.toString();
  }

  double get reputationPercent{
    final u = user.value;
    if(u == null){
      return 0.0;
    }
    final score = u.reputationScore.clamp(0,100);
    return score/100;
  }

  String get reputationLabel {
    final u = user.value;
    if (u == null) return "";
    final score = u.reputationScore;
    if (score >= 85) return "Tuyệt vời";
    if (score >= 70) return "Tốt";
    if (score >= 50) return "Trung bình";
    return "Thấp";
  }

  String get bio {
    final u = user.value;
    if (u == null || u.bio.isEmpty) {
      return "Chưa có mô tả bản thân.";
    }
    return u.bio;
  }

  int get followersCount => user.value?.followers.length ?? 0;
  int get followingCount => user.value?.following.length ?? 0;
  int get rank => user.value?.rank ?? 1;

  Future<void> updateBio(String newBio) async{
    final uid = _auth.currentUser?.uid;
    if(uid == null){
      return;
    }
    await _db.collection("users").doc(uid).update({
      "bio": newBio.trim(),
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  // ====================================================
  // 🔥 CLEANUP FOR LOGOUT
  // ====================================================
  void cleanup() {
    _userSub?.cancel();
    _userSub = null;
    user.value = null;
    isLoading.value = false;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  Future<void> cleanupAsync() async {
    final sub = _userSub;
    _userSub = null;
    if (sub != null) {
      await sub.cancel();
    }
    user.value = null;
    isLoading.value = false;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  @override
  void onClose() {
    _authSub?.cancel();
    _authSub = null;
    cleanup();
    super.onClose();
  }
}
