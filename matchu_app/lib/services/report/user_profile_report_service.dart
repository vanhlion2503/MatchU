import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:matchu_app/models/user_profile_report_model.dart';
import 'package:path_provider/path_provider.dart';

class UserProfileReportService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static Future<void> submitReport(
    UserProfileReportModel report, {
    List<File> evidenceImages = const [],
  }) async {
    final fromUid = report.fromUid.trim();
    final toUid = report.toUid.trim();

    if (fromUid.isEmpty || toUid.isEmpty) {
      throw StateError('Thiếu thông tin báo cáo.');
    }

    if (fromUid == toUid) {
      throw StateError('Bạn không thể báo cáo chính mình.');
    }

    final reportRef = _db.collection('userProfileReports').doc();
    final userRef = _db.collection('users').doc(toUid);
    final uploadedRefs = <Reference>[];

    try {
      final uploadedUrls = await _uploadEvidenceImages(
        reportId: reportRef.id,
        fromUid: fromUid,
        toUid: toUid,
        files: evidenceImages,
        uploadedRefs: uploadedRefs,
      );

      await _db.runTransaction((tx) async {
        final userSnap = await tx.get(userRef);
        if (!userSnap.exists) {
          throw StateError('Không tìm thấy người dùng này.');
        }

        final rawTotal = userSnap.data()?['totalReports'];
        final oldReports = rawTotal is num ? rawTotal.toInt() : 0;

        tx.set(reportRef, report.toJson(imageUrlsOverride: uploadedUrls));
        tx.update(userRef, {'totalReports': oldReports + 1});
      });
    } catch (_) {
      await _deleteUploadedRefs(uploadedRefs);
      rethrow;
    }
  }

  static Future<List<String>> _uploadEvidenceImages({
    required String reportId,
    required String fromUid,
    required String toUid,
    required List<File> files,
    required List<Reference> uploadedRefs,
  }) async {
    if (files.isEmpty) return const [];

    final urls = <String>[];
    for (var index = 0; index < files.length; index++) {
      final preparedFile = await _prepareImageFile(
        reportId,
        files[index],
        index,
      );
      final ref = _storage.ref(
        'userProfileReports/$fromUid/$toUid/$reportId/image_$index.jpg',
      );

      await ref.putFile(
        preparedFile,
        SettableMetadata(contentType: 'image/jpeg', cacheControl: 'no-store'),
      );

      uploadedRefs.add(ref);
      urls.add(await ref.getDownloadURL());
    }

    return urls;
  }

  static Future<File> _prepareImageFile(
    String reportId,
    File source,
    int index,
  ) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/report_${reportId}_$index.jpg';
      final Uint8List? bytes = await FlutterImageCompress.compressWithFile(
        source.path,
        quality: 78,
        format: CompressFormat.jpeg,
      );

      if (bytes == null) return source;

      final file = File(targetPath);
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (_) {
      return source;
    }
  }

  static Future<void> _deleteUploadedRefs(List<Reference> refs) async {
    for (final ref in refs) {
      try {
        await ref.delete();
      } catch (_) {}
    }
  }
}
