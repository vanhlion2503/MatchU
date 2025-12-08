import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:matchu_app/models/user_model.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<UserModel> streamUser(String uid){
    return _db.collection("users").doc(uid).snapshots().map((doc){
      return UserModel.fromJson(doc.data() ?? {}, doc.id);
    });
  }
  Future<UserModel?> getUser(String uid) async{
    final doc = await _db.collection("users").doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromJson(doc.data()!, doc.id);
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _db.collection("users").doc(uid).update(data);
  }

  Future<List<UserModel>> searchUsersByNickname(String query) async {
    if (query.trim().isEmpty) return [];

    final result = await _db
        .collection("users")
        .where("nickname", isGreaterThanOrEqualTo: query)
        .where("nickname", isLessThan: query + '\uf8ff')
        .limit(20)
        .get();

    return result.docs
        .map((doc) => UserModel.fromJson(doc.data(), doc.id))
        .toList();
  }
} 
