import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AvatarService {
  static final _storage = FirebaseStorage.instance;
  static final _auth = FirebaseAuth.instance;

  static Reference _ref() {
    final uid = _auth.currentUser!.uid;
    return _storage.ref("avatars/$uid/avatar.jpg");
  }

  static Future<String> uploadAvatar(File file) async {
    final ref = _ref();
    await ref.putFile(
      file,
      SettableMetadata(contentType: "image/jpeg"),
    );
    return await ref.getDownloadURL();
  }

  static Future<void> deleteAvatar() async {
    try{
      await _ref().delete();
    } catch (_){}
  }
}