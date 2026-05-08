import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:matchu_app/models/user_model.dart';
import 'package:matchu_app/services/user/avatar_service.dart';

class AvatarController extends GetxController {
  // ===== STATE =====
  final user = Rxn<UserModel>();
  final isUploadingAvatar = false.obs;

  static const String defaultAvatarUrl =
      "https://firebasestorage.googleapis.com/v0/b/matchu-5bd75.firebasestorage.app/o/avatars%2Fplaceholder.png?alt=media";

  // ===== SERVICES =====
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _picker = ImagePicker();

  StreamSubscription<DocumentSnapshot>? _userSub;
  StreamSubscription<User?>? _authSub;
  String? get _uid => _auth.currentUser?.uid;

  // ================= INIT =================
  @override
  void onInit() {
    super.onInit();
    _authSub = _auth.authStateChanges().listen((u) {
      if (u != null) {
        _listenUserRealtime(u.uid);
      } else {
        cleanup();
      }
    });

    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      _listenUserRealtime(currentUser.uid);
    }
  }

  // ================= LOAD USER =================
  void _listenUserRealtime([String? uid]) {
    _userSub?.cancel();

    final targetUid = uid ?? _uid;
    if (targetUid == null) return;

    _userSub = _db
        .collection("users")
        .doc(targetUid)
        .snapshots()
        .listen(
          (snap) {
            if (!snap.exists) return;

            user.value = UserModel.fromJson(snap.data()!, snap.id);
          },
          onError: (error) {
            // 🔒 Handle permission denied và các lỗi khác
            _userSub?.cancel();
            _userSub = null;
            user.value = null;
          },
          cancelOnError: false,
        );
  }

  // ================= PICK AVATAR =================
  Future<void> pickAvatar(ImageSource source) async {
    if (_auth.currentUser == null) return;

    final picked = await _picker.pickImage(source: source, imageQuality: 100);
    if (picked == null) return;

    final cropped = await _crop(File(picked.path));
    if (cropped == null) return;

    final compressed = await _compress(cropped);
    if (compressed == null) return;

    await _upload(compressed);
  }

  // ================= CROP =================
  Future<File?> _crop(File file) async {
    final result = await ImageCropper().cropImage(
      sourcePath: file.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.jpg,
      uiSettings: [
        AndroidUiSettings(toolbarTitle: 'Cắt ảnh', lockAspectRatio: true),
        IOSUiSettings(title: 'Cắt ảnh', aspectRatioLockEnabled: true),
      ],
    );

    return result == null ? null : File(result.path);
  }

  // ================= COMPRESS =================
  Future<File?> _compress(File file) async {
    final dir = await getTemporaryDirectory();
    final targetPath = "${dir.path}/avatar_$_uid.jpg";

    final Uint8List? bytes = await FlutterImageCompress.compressWithFile(
      file.path,
      quality: 75,
      format: CompressFormat.jpeg,
    );

    if (bytes == null) return null;

    final compressed = File(targetPath);
    await compressed.writeAsBytes(bytes);
    return compressed;
  }

  // ================= UPLOAD =================
  Future<void> _upload(File file) async {
    isUploadingAvatar.value = true;

    try {
      // 1️⃣ Upload storage
      final avatarUpdatedAt = DateTime.now().toUtc();
      final avatarUrl = await AvatarService.uploadAvatar(file);

      if (_uid == null) return;
      // 2️⃣ Update Firestore
      await _db.collection("users").doc(_uid).update({
        "avatarUrl": avatarUrl,
        "avatarUpdatedAt": Timestamp.fromDate(avatarUpdatedAt),
        "updatedAt": FieldValue.serverTimestamp(),
      });

      user.value = user.value?.copyWith(
        avatarUrl: avatarUrl,
        avatarUpdatedAt: avatarUpdatedAt,
        updatedAt: avatarUpdatedAt,
      );
      user.refresh();

      Get.snackbar("Thành công", "Cập nhật avatar thành công");
    } catch (e) {
      Get.snackbar("Lỗi", e.toString());
    } finally {
      isUploadingAvatar.value = false;
    }
  }

  // ================= DELETE =================
  Future<void> deleteAvatar() async {
    if (_auth.currentUser == null) return;

    isUploadingAvatar.value = true;

    try {
      // ❗ Optional: nếu bạn muốn xoá file avatar cũ trên Storage
      await AvatarService.deleteAvatar();

      // ✅ SET avatar mặc định
      final avatarUpdatedAt = DateTime.now().toUtc();
      await _db.collection("users").doc(_uid).update({
        "avatarUrl": defaultAvatarUrl,
        "avatarUpdatedAt": Timestamp.fromDate(avatarUpdatedAt),
        "updatedAt": FieldValue.serverTimestamp(),
      });

      // ✅ Update local state
      user.value = user.value?.copyWith(
        avatarUrl: defaultAvatarUrl,
        avatarUpdatedAt: avatarUpdatedAt,
        updatedAt: avatarUpdatedAt,
      );
      user.refresh();

      Get.snackbar("Thành công", "Đã khôi phục avatar mặc định");
    } catch (e) {
      Get.snackbar("Lỗi", e.toString());
    } finally {
      isUploadingAvatar.value = false;
    }
  }

  // ====================================================
  // 🔥 CLEANUP FOR LOGOUT
  // ====================================================
  void cleanup() {
    _userSub?.cancel();
    _userSub = null;
    user.value = null;
  }

  Future<void> cleanupAsync() async {
    final sub = _userSub;
    _userSub = null;
    if (sub != null) {
      await sub.cancel();
    }
    user.value = null;
  }

  @override
  void onClose() {
    _authSub?.cancel();
    _authSub = null;
    cleanup();
    super.onClose();
  }
}
