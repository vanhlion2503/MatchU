import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class ReportEvidenceStorageHelper {
  ReportEvidenceStorageHelper._();

  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static Future<List<String>> uploadEvidenceImages({
    required String reportId,
    required List<File> files,
    required List<Reference> uploadedRefs,
    required String Function(int index) targetPathBuilder,
  }) async {
    if (files.isEmpty) return const [];

    final urls = <String>[];
    for (var index = 0; index < files.length; index++) {
      final preparedFile = await _prepareImageFile(
        reportId: reportId,
        source: files[index],
        index: index,
      );
      final ref = _storage.ref(targetPathBuilder(index));

      await ref.putFile(
        preparedFile,
        SettableMetadata(contentType: 'image/jpeg', cacheControl: 'no-store'),
      );

      uploadedRefs.add(ref);
      urls.add(await ref.getDownloadURL());
    }

    return urls;
  }

  static Future<void> deleteUploadedRefs(List<Reference> refs) async {
    for (final ref in refs) {
      try {
        await ref.delete();
      } catch (_) {}
    }
  }

  static Future<File> _prepareImageFile({
    required String reportId,
    required File source,
    required int index,
  }) async {
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
}
