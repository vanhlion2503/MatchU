import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:matchu_app/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class ProfileController extends GetxController{
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final Rx<UserModel?> user = Rxn<UserModel>();
  final isLoading = true.obs;
  
  void onInit(){
    super.onInit();
     _listenUserProfile();
  }

  void _listenUserProfile(){
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      isLoading.value = false;
      return;
    }
    _db.collection('users').doc(firebaseUser.uid).snapshots().listen((doc) {
      if (doc.data() != null) {
        user.value = UserModel.fromJson(doc.data()!, doc.id);
      }
      isLoading.value = false;
    });
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
}