import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/translations/post_translations.dart';
import 'package:matchu_app/controllers/feed/post_restrictions_controller.dart';
import 'package:matchu_app/models/feed/post_model.dart';
import 'package:matchu_app/services/user/user_service.dart';

class PostAuthorBlockHelper {
  PostAuthorBlockHelper._();

  static final UserService _userService = UserService();

  static Future<bool> blockAuthor(PostModel post) async {
    final authorId = post.authorId.trim();
    if (authorId.isEmpty) {
      _showError('Không tìm thấy tác giả để chặn.');
      return false;
    }

    final targetUser = await _userService.getUser(authorId);
    if (targetUser == null) {
      _showError('Không tìm thấy người dùng này.');
      return false;
    }

    final restrictionsController =
        Get.isRegistered<PostRestrictionsController>()
            ? Get.find<PostRestrictionsController>()
            : Get.put(PostRestrictionsController());

    return restrictionsController.blockUser(targetUser);
  }

  static void _showError(String message) {
    Get.snackbar(
      PostTranslationKeys.error.tr,
      postTr(message),
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
    );
  }
}
