import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/controllers/feed/feed_controller.dart';
import 'package:matchu_app/models/feed/hidden_post_author_model.dart';
import 'package:matchu_app/services/feed/post_restriction_service.dart';
import 'package:matchu_app/translates/firebase_error_translator.dart';

enum PostRestrictionsStatus { initial, loading, success, empty, error }

class PostRestrictionsController extends GetxController {
  PostRestrictionsController({PostRestrictionService? restrictionService})
    : _restrictionService = restrictionService ?? PostRestrictionService();

  final PostRestrictionService _restrictionService;

  final RxList<HiddenPostAuthorModel> hiddenPostAuthors =
      <HiddenPostAuthorModel>[].obs;
  final Rx<PostRestrictionsStatus> hiddenAuthorsStatus =
      PostRestrictionsStatus.initial.obs;
  final RxnString errorMessage = RxnString();
  final RxSet<String> unhidingAuthorIds = <String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    unawaited(loadHiddenPostAuthors());
  }

  bool isAuthorUnhiding(String authorId) {
    final normalizedAuthorId = authorId.trim();
    if (normalizedAuthorId.isEmpty) return false;
    return unhidingAuthorIds.contains(normalizedAuthorId);
  }

  Future<void> loadHiddenPostAuthors() async {
    if (hiddenAuthorsStatus.value == PostRestrictionsStatus.loading) return;

    hiddenAuthorsStatus.value = PostRestrictionsStatus.loading;
    errorMessage.value = null;

    try {
      final items = await _restrictionService.fetchHiddenPostAuthors();
      hiddenPostAuthors.assignAll(items);
      hiddenAuthorsStatus.value =
          items.isEmpty
              ? PostRestrictionsStatus.empty
              : PostRestrictionsStatus.success;
    } catch (error) {
      errorMessage.value = _mapError(error);
      hiddenAuthorsStatus.value = PostRestrictionsStatus.error;
    }
  }

  Future<void> unhideAuthor(String authorId) async {
    final normalizedAuthorId = authorId.trim();
    if (normalizedAuthorId.isEmpty ||
        unhidingAuthorIds.contains(normalizedAuthorId)) {
      return;
    }

    unhidingAuthorIds.add(normalizedAuthorId);

    try {
      await _restrictionService.unhidePostAuthor(normalizedAuthorId);
      hiddenPostAuthors.removeWhere(
        (item) => item.authorId.trim() == normalizedAuthorId,
      );

      if (hiddenPostAuthors.isEmpty) {
        hiddenAuthorsStatus.value = PostRestrictionsStatus.empty;
      } else {
        hiddenAuthorsStatus.value = PostRestrictionsStatus.success;
      }

      if (Get.isRegistered<FeedController>()) {
        Get.find<FeedController>().applyHiddenPostAuthorRemoved(
          normalizedAuthorId,
        );
      }

      Get.snackbar(
        'Th\u00F4ng b\u00E1o',
        '\u0110\u00E3 b\u1ECF \u1EA9n b\u00E0i vi\u1EBFt t\u1EEB ng\u01B0\u1EDDi n\u00E0y.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    } catch (error) {
      _showError(_mapError(error));
    } finally {
      unhidingAuthorIds.remove(normalizedAuthorId);
    }
  }

  String _mapError(Object error) {
    if (error is FirebaseException) {
      return firebaseErrorToVietnamese(error.code);
    }

    if (error is StateError) {
      return error.message.toString();
    }

    return 'Kh\u00F4ng th\u1EC3 t\u1EA3i Danh s\u00E1ch h\u1EA1n ch\u1EBF l\u00FAc n\u00E0y. Vui l\u00F2ng th\u1EED l\u1EA1i.';
  }

  void _showError(String message) {
    Get.snackbar(
      'L\u1ED7i',
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
    );
  }
}
