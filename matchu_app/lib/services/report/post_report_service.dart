import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:matchu_app/models/post_report_model.dart';
import 'package:matchu_app/services/report/report_evidence_storage_helper.dart';

class PostReportService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> submitReport(
    PostReportModel report, {
    List<File> evidenceImages = const [],
  }) async {
    final fromUid = report.fromUid.trim();
    final toUid = report.toUid.trim();
    final postId = report.postId.trim();

    if (fromUid.isEmpty || toUid.isEmpty || postId.isEmpty) {
      throw StateError('Thiếu thông tin báo cáo bài viết.');
    }

    if (fromUid == toUid) {
      throw StateError('Bạn không thể báo cáo bài viết của chính mình.');
    }

    final reportRef = _db.collection('postReports').doc();
    final userRef = _db.collection('users').doc(toUid);
    final postRef = _db.collection('posts').doc(postId);
    final uploadedRefs = <Reference>[];

    try {
      final uploadedUrls = await ReportEvidenceStorageHelper.uploadEvidenceImages(
        reportId: reportRef.id,
        files: evidenceImages,
        uploadedRefs: uploadedRefs,
        targetPathBuilder:
            (index) =>
                'postReports/$fromUid/$toUid/$postId/${reportRef.id}/image_$index.jpg',
      );

      await _db.runTransaction((tx) async {
        final userSnap = await tx.get(userRef);
        if (!userSnap.exists) {
          throw StateError('Không tìm thấy người dùng này.');
        }

        final postSnap = await tx.get(postRef);
        if (!postSnap.exists) {
          throw StateError('Bài viết không còn tồn tại.');
        }

        final postData = postSnap.data() ?? const <String, dynamic>{};
        final authorId = (postData['authorId'] ?? '').toString().trim();
        if (authorId.isNotEmpty && authorId != toUid) {
          throw StateError('Thông tin tác giả bài viết không khớp.');
        }

        if (postData['deletedAt'] != null) {
          throw StateError('Bài viết này đã bị xóa.');
        }

        final rawTotal = userSnap.data()?['totalReports'];
        final oldReports = rawTotal is num ? rawTotal.toInt() : 0;

        tx.set(reportRef, report.toJson(imageUrlsOverride: uploadedUrls));
        tx.update(userRef, {'totalReports': oldReports + 1});
      });
    } catch (_) {
      await ReportEvidenceStorageHelper.deleteUploadedRefs(uploadedRefs);
      rethrow;
    }
  }
}
