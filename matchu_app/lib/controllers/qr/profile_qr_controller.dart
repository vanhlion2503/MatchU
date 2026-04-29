import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:matchu_app/controllers/user/user_controller.dart';
import 'package:matchu_app/models/user_model.dart';
import 'package:matchu_app/services/user/user_service.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/profile/other_profile_view.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';

class ProfileQrController extends GetxController {
  ProfileQrController();

  static const String _scheme = 'matchu';
  static const String _profileHost = 'profile';
  static const String _legacyPrefix = 'matchu:user:';

  final UserService _userService = UserService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _imagePicker = ImagePicker();

  final selectedTabIndex = 0.obs;
  final isResolvingQr = false.obs;
  final isSavingQr = false.obs;
  final GlobalKey qrBoundaryKey = GlobalKey();

  final MobileScannerController scannerController = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
    autoZoom: true,
  );

  final Rxn<UserModel> _fallbackUserRx = Rxn<UserModel>();

  Rxn<UserModel> get currentUserRx {
    if (Get.isRegistered<UserController>()) {
      return Get.find<UserController>().userRx;
    }
    return _fallbackUserRx;
  }

  String get currentUid {
    if (Get.isRegistered<UserController>()) {
      final uid = Get.find<UserController>().uid;
      if (uid.isNotEmpty) return uid;
    }
    return _auth.currentUser?.uid ?? '';
  }

  String get qrPayload => buildProfileQrPayload(currentUid);

  @override
  void onInit() {
    super.onInit();
    _loadFallbackUserIfNeeded();
  }

  @override
  void onClose() {
    unawaited(scannerController.dispose());
    super.onClose();
  }

  static String buildProfileQrPayload(String uid) {
    return '$_scheme://$_profileHost/${Uri.encodeComponent(uid)}';
  }

  void changeTab(int index) {
    if (selectedTabIndex.value == index) return;

    selectedTabIndex.value = index;
    if (index == 0) {
      _restartScannerIfNeeded();
    } else {
      unawaited(scannerController.stop());
    }
  }

  Future<void> toggleTorch() async {
    try {
      await scannerController.toggleTorch();
    } catch (_) {
      _showSnack(
        title: 'Không bật được đèn',
        message: 'Thiết bị hiện không hỗ trợ hoặc camera chưa sẵn sàng.',
        isError: true,
      );
    }
  }

  Future<void> handleBarcodeCapture(BarcodeCapture capture) async {
    if (isResolvingQr.value) return;

    final rawValue = _firstBarcodeValue(capture);
    if (rawValue == null) return;

    await _resolveScannedValue(rawValue);
  }

  Future<void> pickQrFromGallery() async {
    if (isResolvingQr.value) return;

    final pickedImage = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );
    if (pickedImage == null) return;

    isResolvingQr.value = true;
    try {
      final capture = await scannerController.analyzeImage(
        pickedImage.path,
        formats: const [BarcodeFormat.qrCode],
      );
      final rawValue = capture == null ? null : _firstBarcodeValue(capture);

      if (rawValue == null) {
        _showSnack(
          title: 'Không tìm thấy QR',
          message: 'Ảnh này không có mã QR hợp lệ của MatchU.',
          isError: true,
        );
        return;
      }

      await _openProfileFromRawValue(rawValue);
    } catch (_) {
      _showSnack(
        title: 'Không quét được ảnh',
        message: 'Hãy thử chọn ảnh QR rõ hơn.',
        isError: true,
      );
    } finally {
      isResolvingQr.value = false;
      _restartScannerIfNeeded();
    }
  }

  Future<void> copyQrPayload() async {
    if (currentUid.isEmpty) {
      _showSnack(
        title: 'Chưa có dữ liệu',
        message: 'Không tìm thấy tài khoản hiện tại.',
        isError: true,
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: qrPayload));
    _showSnack(
      title: 'Đã sao chép',
      message: 'Mã QR của bạn đã được sao chép để chia sẻ.',
    );
  }

  Future<void> saveQrImage() async {
    if (isSavingQr.value) return;
    if (currentUid.isEmpty) {
      _showSnack(
        title: 'Chưa có dữ liệu',
        message: 'Không tìm thấy tài khoản hiện tại.',
        isError: true,
      );
      return;
    }

    isSavingQr.value = true;
    try {
      final path = await _writeQrImageToFile();
      await Clipboard.setData(ClipboardData(text: path));
      _showSnack(
        title: 'Đã lưu ảnh QR',
        message: 'Đường dẫn ảnh đã được sao chép vào bộ nhớ tạm.',
      );
    } catch (_) {
      _showSnack(
        title: 'Không lưu được ảnh',
        message: 'Vui lòng mở lại tab Mã của tôi rồi thử lại.',
        isError: true,
      );
    } finally {
      isSavingQr.value = false;
    }
  }

  Future<void> _resolveScannedValue(String rawValue) async {
    isResolvingQr.value = true;
    try {
      await scannerController.stop();
      await _openProfileFromRawValue(rawValue);
    } finally {
      isResolvingQr.value = false;
      _restartScannerIfNeeded();
    }
  }

  Future<void> _openProfileFromRawValue(String rawValue) async {
    final targetUid = parseProfileUid(rawValue);
    if (targetUid == null) {
      _showSnack(
        title: 'QR không hợp lệ',
        message: 'Mã này không phải mã hồ sơ MatchU.',
        isError: true,
      );
      return;
    }

    UserModel? user;
    try {
      user = await _userService.getUser(targetUid);
    } catch (_) {
      _showSnack(
        title: 'Không mở được hồ sơ',
        message: 'Vui lòng kiểm tra kết nối rồi thử lại.',
        isError: true,
      );
      return;
    }

    if (user == null) {
      _showSnack(
        title: 'Không tìm thấy hồ sơ',
        message: 'Tài khoản trong mã QR không còn tồn tại.',
        isError: true,
      );
      return;
    }

    await Get.to(
      () => OtherProfileView(userId: targetUid),
      transition: Transition.cupertino,
    );
  }

  String? parseProfileUid(String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty) return null;

    final uri = Uri.tryParse(value);
    if (uri != null &&
        uri.scheme == _scheme &&
        uri.host == _profileHost &&
        uri.pathSegments.isNotEmpty) {
      return Uri.decodeComponent(uri.pathSegments.first);
    }

    if (value.startsWith(_legacyPrefix)) {
      final uid = value.substring(_legacyPrefix.length).trim();
      return uid.isEmpty ? null : uid;
    }

    final looksLikeFirebaseUid = RegExp(r'^[A-Za-z0-9_-]{16,}$');
    if (looksLikeFirebaseUid.hasMatch(value)) return value;

    return null;
  }

  String? _firstBarcodeValue(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  Future<void> _restartScannerIfNeeded() async {
    if (selectedTabIndex.value != 0 || isResolvingQr.value) return;

    try {
      await scannerController.start();
    } catch (_) {
      // MobileScanner may already be running or not attached yet.
    }
  }

  Future<void> _loadFallbackUserIfNeeded() async {
    if (Get.isRegistered<UserController>()) return;

    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    try {
      _fallbackUserRx.value = await _userService.getUser(uid);
    } catch (_) {}
  }

  Future<String> _writeQrImageToFile() async {
    final boundaryContext = qrBoundaryKey.currentContext;
    final renderObject = boundaryContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw StateError('QR boundary is not ready.');
    }

    final image = await renderObject.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Unable to encode QR image.');
    }

    final directory = await getApplicationDocumentsDirectory();
    final safeUid = currentUid.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    final file = File(
      '${directory.path}${Platform.pathSeparator}matchu_qr_$safeUid.png',
    );

    await file.writeAsBytes(byteData.buffer.asUint8List());
    return file.path;
  }

  void _showSnack({
    required String title,
    required String message,
    bool isError = false,
  }) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      backgroundColor:
          isError
              ? AppTheme.errorColor.withValues(alpha: 0.92)
              : AppTheme.primaryColor.withValues(alpha: 0.92),
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }
}
