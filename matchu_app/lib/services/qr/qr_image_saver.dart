import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class QrImageSaver {
  const QrImageSaver();

  static const MethodChannel _channel = MethodChannel(
    'matchu_app/qr_image_saver',
  );

  Future<SavedQrImage> savePng({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final normalizedFileName = _normalizePngFileName(fileName);

    if (Platform.isAndroid || Platform.isIOS) {
      if (Platform.isAndroid) {
        try {
          return await _saveWithNativeChannel(bytes, normalizedFileName);
        } on PlatformException catch (error) {
          if (error.code != 'STORAGE_PERMISSION_REQUIRED') rethrow;

          final status = await Permission.storage.request();
          if (!status.isGranted) rethrow;

          return _saveWithNativeChannel(bytes, normalizedFileName);
        }
      }

      return _saveWithNativeChannel(bytes, normalizedFileName);
    }

    final directory =
        await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}$normalizedFileName',
    );
    await file.writeAsBytes(bytes, flush: true);

    return SavedQrImage(location: file.path, savedToGallery: false);
  }

  Future<SavedQrImage> _saveWithNativeChannel(
    Uint8List bytes,
    String fileName,
  ) async {
    final savedUri = await _channel.invokeMethod<String>('savePng', {
      'bytes': bytes,
      'fileName': fileName,
    });

    if (savedUri == null || savedUri.isEmpty) {
      throw StateError('Native image saver did not return a saved uri.');
    }

    return SavedQrImage(location: savedUri, savedToGallery: true);
  }

  String _normalizePngFileName(String fileName) {
    final trimmed = fileName.trim();
    final safeName =
        trimmed.isEmpty
            ? 'matchu_qr.png'
            : trimmed.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

    return safeName.toLowerCase().endsWith('.png') ? safeName : '$safeName.png';
  }
}

class SavedQrImage {
  const SavedQrImage({required this.location, required this.savedToGallery});

  final String location;
  final bool savedToGallery;
}
