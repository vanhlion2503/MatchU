import 'dart:async';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:matchu_app/controllers/user/user_controller.dart';
import 'package:matchu_app/models/user_model.dart';
import 'package:matchu_app/services/qr/qr_image_saver.dart';
import 'package:matchu_app/services/user/user_service.dart';
import 'package:matchu_app/theme/app_theme.dart';
import 'package:matchu_app/views/profile/other_profile_view.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_plus/share_plus.dart' as share_plus;

class ProfileQrController extends GetxController with WidgetsBindingObserver {
  ProfileQrController();

  static const String _scheme = 'matchu';
  static const String _profileHost = 'profile';
  static const String _legacyPrefix = 'matchu:user:';
  static const Duration _scannerStartDelay = Duration(milliseconds: 80);
  static const Duration _scannerRetryDelay = Duration(milliseconds: 250);
  static const int _scannerStartMaxRetries = 3;

  final UserService _userService = UserService();
  final QrImageSaver _qrImageSaver = const QrImageSaver();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _imagePicker = ImagePicker();

  final selectedTabIndex = 0.obs;
  final isResolvingQr = false.obs;
  final isSavingQr = false.obs;
  final isSharingQr = false.obs;
  final GlobalKey qrBoundaryKey = GlobalKey();

  final MobileScannerController scannerController = MobileScannerController(
    autoStart: false,
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
    autoZoom: true,
  );

  final Rxn<UserModel> _fallbackUserRx = Rxn<UserModel>();
  Timer? _scannerStartTimer;
  int _scannerStartGeneration = 0;
  bool _isClosed = false;

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
    selectedTabIndex.value = _resolveInitialTabIndex(Get.arguments);
    WidgetsBinding.instance.addObserver(this);
    _loadFallbackUserIfNeeded();
  }

  @override
  void onClose() {
    _isClosed = true;
    _cancelPendingScannerStart();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(scannerController.dispose());
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        requestScannerStart();
        return;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _cancelPendingScannerStart();
        unawaited(_stopScanner());
        return;
    }
  }

  static String buildProfileQrPayload(String uid) {
    return '$_scheme://$_profileHost/${Uri.encodeComponent(uid)}';
  }

  int _resolveInitialTabIndex(dynamic args) {
    final rawIndex =
        args is Map ? args['initialTab'] ?? args['tabIndex'] : args;

    if (rawIndex is int && (rawIndex == 0 || rawIndex == 1)) {
      return rawIndex;
    }

    if (rawIndex is String) {
      final parsedIndex = int.tryParse(rawIndex);
      if (parsedIndex != null && (parsedIndex == 0 || parsedIndex == 1)) {
        return parsedIndex;
      }
    }

    return 0;
  }

  void changeTab(int index) {
    if (selectedTabIndex.value == index) return;

    selectedTabIndex.value = index;
    if (index == 0) {
      requestScannerStart();
    } else {
      _cancelPendingScannerStart();
      unawaited(_stopScanner());
    }
  }

  void onScannerTabReady() {
    requestScannerStart();
  }

  void requestScannerStart() {
    if (!_shouldRunScanner) return;

    final generation = ++_scannerStartGeneration;
    _scannerStartTimer?.cancel();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (generation != _scannerStartGeneration || !_shouldRunScanner) {
        return;
      }

      _scannerStartTimer?.cancel();
      _scannerStartTimer = Timer(_scannerStartDelay, () {
        if (generation != _scannerStartGeneration) return;
        unawaited(_startScannerIfNeeded(generation));
      });
    });
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
    _cancelPendingScannerStart();
    await _stopScanner();
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
      requestScannerStart();
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
      final bytes = await _captureQrImageBytes();
      final savedImage = await _qrImageSaver.savePng(
        bytes: bytes,
        fileName: _buildQrImageFileName(),
      );

      _showSnack(
        title: 'Đã lưu ảnh QR',
        message:
            savedImage.savedToGallery
                ? 'Ảnh QR đã được lưu vào thư viện ảnh của máy.'
                : 'Ảnh QR đã được lưu tại ${savedImage.location}.',
      );
    } catch (_) {
      _showSnack(
        title: 'Không lưu được ảnh',
        message:
            'Vui lòng mở lại tab Mã của tôi và cấp quyền lưu ảnh nếu được hỏi.',
        isError: true,
      );
    } finally {
      isSavingQr.value = false;
    }
  }

  Future<void> shareQrImage({Rect? sharePositionOrigin}) async {
    if (isSharingQr.value) return;
    if (currentUid.isEmpty) {
      _showSnack(
        title: 'Chưa có dữ liệu',
        message: 'Không tìm thấy tài khoản hiện tại.',
        isError: true,
      );
      return;
    }

    isSharingQr.value = true;
    try {
      final bytes = await _captureQrImageBytes();
      final fileName = _buildQrImageFileName();
      final result = await share_plus.SharePlus.instance.share(
        share_plus.ShareParams(
          title: 'Chia sẻ mã QR MatchU',
          subject: 'Mã QR MatchU của tôi',
          text: 'Quét mã QR này để thêm tôi làm bạn trên MatchU.',
          files: [
            share_plus.XFile.fromData(
              bytes,
              mimeType: 'image/png',
              name: fileName,
            ),
          ],
          fileNameOverrides: [fileName],
          sharePositionOrigin: sharePositionOrigin,
        ),
      );

      if (result.status == share_plus.ShareResultStatus.unavailable) {
        _showSnack(
          title: 'Không mở được chia sẻ',
          message: 'Thiết bị hiện không hỗ trợ chia sẻ ảnh QR.',
          isError: true,
        );
      }
    } catch (_) {
      _showSnack(
        title: 'Không chia sẻ được mã QR',
        message: 'Vui lòng mở lại tab Mã của tôi rồi thử lại.',
        isError: true,
      );
    } finally {
      isSharingQr.value = false;
    }
  }

  Future<void> _resolveScannedValue(String rawValue) async {
    isResolvingQr.value = true;
    try {
      _cancelPendingScannerStart();
      await _stopScanner();
      await _openProfileFromRawValue(rawValue);
    } finally {
      isResolvingQr.value = false;
      requestScannerStart();
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

  bool get _shouldRunScanner =>
      !_isClosed && selectedTabIndex.value == 0 && !isResolvingQr.value;

  void _cancelPendingScannerStart() {
    _scannerStartGeneration++;
    _scannerStartTimer?.cancel();
    _scannerStartTimer = null;
  }

  Future<void> _startScannerIfNeeded(
    int generation, {
    int retryCount = 0,
  }) async {
    if (generation != _scannerStartGeneration || !_shouldRunScanner) return;

    final scannerState = scannerController.value;
    if (scannerState.isRunning || scannerState.isStarting) return;

    try {
      await scannerController.start();
    } on MobileScannerException catch (error) {
      if (error.errorCode == MobileScannerErrorCode.controllerInitializing ||
          error.errorCode == MobileScannerErrorCode.controllerNotAttached) {
        _retryScannerStart(generation, retryCount);
      }
      return;
    } catch (_) {
      _retryScannerStart(generation, retryCount);
      return;
    }

    if (generation != _scannerStartGeneration || !_shouldRunScanner) {
      await _stopScanner();
    }
  }

  void _retryScannerStart(int generation, int retryCount) {
    if (retryCount >= _scannerStartMaxRetries ||
        generation != _scannerStartGeneration ||
        !_shouldRunScanner) {
      return;
    }

    _scannerStartTimer?.cancel();
    _scannerStartTimer = Timer(_scannerRetryDelay, () {
      if (generation != _scannerStartGeneration) return;
      unawaited(_startScannerIfNeeded(generation, retryCount: retryCount + 1));
    });
  }

  Future<void> _stopScanner() async {
    try {
      await scannerController.stop();
    } catch (_) {
      // The controller can be mid-start or already disposed during route pops.
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

  Future<Uint8List> _captureQrImageBytes() async {
    await WidgetsBinding.instance.endOfFrame;

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

    return byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );
  }

  String _buildQrImageFileName() {
    final safeUid = currentUid.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    final suffix = safeUid.isEmpty ? 'profile' : safeUid;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'matchu_qr_${suffix}_$timestamp.png';
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
