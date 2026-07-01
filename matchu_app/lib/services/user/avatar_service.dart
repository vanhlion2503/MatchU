import 'dart:async';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:matchu_app/services/moderation/image_moderation_service.dart';

class AvatarService {
  static final _storage = FirebaseStorage.instance;
  static final _auth = FirebaseAuth.instance;
  static final _imageModerationService = ImageModerationService();

  static Reference _ref() {
    final uid = _auth.currentUser!.uid;
    return _storage.ref("avatars/$uid/avatar.jpg");
  }

  static Future<String> uploadAvatar(File file) async {
    await _ensureImageContentAllowed(file);

    final ref = _ref();
    await ref.putFile(file, SettableMetadata(contentType: "image/jpeg"));
    return await ref.getDownloadURL();
  }

  static Future<void> deleteAvatar() async {
    try {
      await _ref().delete();
    } catch (_) {}
  }

  static Future<void> _ensureImageContentAllowed(File imageFile) async {
    try {
      final result = await _imageModerationService.moderate(imageFile);
      if (!result.isViolation) return;

      final reason = result.reason?.trim();
      throw StateError(
        reason == null || reason.isEmpty
            ? 'Avatar vi phạm tiêu chuẩn cộng đồng.'
            : 'Avatar vi phạm tiêu chuẩn cộng đồng: $reason',
      );
    } on StateError {
      rethrow;
    } on TimeoutException {
      throw StateError(
        'Không thể kiểm duyệt avatar lúc này. Vui lòng thử lại sau.',
      );
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'unauthenticated') {
        throw StateError('Bạn cần đăng nhập để cập nhật avatar.');
      }

      if (error.code == 'invalid-argument') {
        throw StateError('Avatar không hợp lệ.');
      }

      throw StateError(
        'Không thể kiểm duyệt avatar lúc này. Vui lòng thử lại sau.',
      );
    } catch (_) {
      throw StateError(
        'Không thể kiểm duyệt avatar lúc này. Vui lòng thử lại sau.',
      );
    }
  }
}
