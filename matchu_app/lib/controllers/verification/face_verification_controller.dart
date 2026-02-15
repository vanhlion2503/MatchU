import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:matchu_app/models/verification/verification_state.dart';
import 'package:matchu_app/services/verification/face_verification_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class FaceVerificationController extends GetxController
    with WidgetsBindingObserver {
  FaceVerificationController({FaceVerificationService? verificationService})
    : _verificationService = verificationService ?? FaceVerificationService();

  final FaceVerificationService _verificationService;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final Rx<VerificationState> state = VerificationState.idle.obs;
  final RxBool blinkDetected = false.obs;
  final RxBool headTurnDetected = false.obs;
  final RxBool hasStartedVerificationFlow = false.obs;
  final RxBool isCheckingVerificationStatus = true.obs;
  final RxBool isAlreadyVerified = false.obs;
  final RxBool wasAlreadyVerifiedAtEntry = false.obs;
  final RxInt currentLivenessStep = 0.obs;
  final RxList<bool> livenessStepDone =
      List<bool>.filled(_livenessStepLabels.length, false).obs;
  final RxString instructionText = "Đặt khuôn mặt vào khung và chụp ảnh".obs;

  final RxBool isCameraReady = false.obs;
  final RxBool hasCameraPermission = false.obs;
  final RxBool isCaptureLocked = false.obs;
  final RxString errorText = "".obs;

  File? selfieFile;
  File? liveFrameFile;

  CameraController? cameraController;

  FaceDetector? _faceDetector;
  CameraDescription? _frontCamera;
  bool _isStreaming = false;
  bool _isProcessingFrame = false;
  bool _isInitializingCamera = false;
  bool _isShuttingDownCamera = false;
  bool _livenessPassed = false;
  bool _shouldResumeCamera = false;
  bool _isDisposed = false;
  int _activeStreamSession = 0;
  Completer<void>? _pendingFrameProcessing;
  Uint8List? _nv21ReusableBuffer;
  double? _straightYawBaseline;
  int _straightStableFrames = 0;
  bool _blinkPrimed = false;
  DateTime _lastLivenessStepAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastFrameProcessedAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _frameProcessInterval = Duration(milliseconds: 120);
  static const Duration _livenessStepGap = Duration(milliseconds: 350);
  static const int _straightStableRequiredFrames = 3;
  static const double _straightYawTolerance = 8;
  static const double _straightRollTolerance = 10;
  static const double _blinkOpenThreshold = 0.65;
  static const double _blinkClosedThreshold = 0.3;
  static const double _turnYawThreshold = 14;
  static const List<String> _livenessStepLabels = <String>[
    "Nhìn thẳng",
    "Chớp mắt",
    "Quay trái",
    "Quay phải",
  ];

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadVerificationStatusOnEntry());
  }

  @override
  void onClose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(disposeResources());
    _verificationService.dispose();
    super.onClose();
  }

  List<String> get livenessStepLabels => _livenessStepLabels;

  bool isLivenessStepDone(int index) {
    if (index < 0 || index >= livenessStepDone.length) {
      return false;
    }
    return livenessStepDone[index];
  }

  bool isLivenessStepActive(int index) {
    return currentLivenessStep.value == index && !isLivenessStepDone(index);
  }

  Future<void> _loadVerificationStatusOnEntry() async {
    isCheckingVerificationStatus.value = true;
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        isAlreadyVerified.value = false;
        wasAlreadyVerifiedAtEntry.value = false;
        state.value = VerificationState.idle;
        instructionText.value = "Đặt khuôn mặt vào khung hình và chụp ảnh";
        return;
      }

      final snapshot = await _db.collection("users").doc(uid).get();
      final isVerified = snapshot.data()?["isFaceVerified"] == true;
      isAlreadyVerified.value = isVerified;
      wasAlreadyVerifiedAtEntry.value = isVerified;

      if (isVerified) {
        hasStartedVerificationFlow.value = false;
        await _shutdownCameraForPreviewExit();
        state.value = VerificationState.success;
        errorText.value = "";
        instructionText.value = "Tài khoản này đã xác thực khuôn mặt";
      } else {
        state.value = VerificationState.idle;
        instructionText.value = "Đặt khuôn mặt vào khung hình và chụp ảnh";
      }
    } catch (e, stackTrace) {
      debugPrint("loadVerificationStatusOnEntry error: $e");
      debugPrintStack(stackTrace: stackTrace);
      isAlreadyVerified.value = false;
      wasAlreadyVerifiedAtEntry.value = false;
      state.value = VerificationState.idle;
      instructionText.value = "Đặt khuôn mặt vào khung hình và chụp ảnh";
    } finally {
      isCheckingVerificationStatus.value = false;
    }
  }

  void startVerificationFlow() {
    if (isCheckingVerificationStatus.value) {
      return;
    }
    if (isAlreadyVerified.value) {
      state.value = VerificationState.success;
      hasStartedVerificationFlow.value = false;
      return;
    }
    if (hasStartedVerificationFlow.value) {
      return;
    }
    hasStartedVerificationFlow.value = true;
    unawaited(initCamera());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) {
      return;
    }

    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // Ignore transient focus changes to avoid camera open/close loops.
        break;
      case AppLifecycleState.paused:
        if (_isInitializingCamera || !_requiresPreviewCamera) {
          return;
        }
        final hasActiveCamera =
            cameraController != null || isCameraReady.value || _isStreaming;
        if (!hasActiveCamera) {
          return;
        }
        _shouldResumeCamera = true;
        unawaited(_shutdownCameraForPreviewExit());
        break;
      case AppLifecycleState.resumed:
        if (!_requiresPreviewCamera) {
          _shouldResumeCamera = false;
          return;
        }
        final shouldInitCamera =
            _shouldResumeCamera ||
            (cameraController == null && !isCameraReady.value);
        _shouldResumeCamera = false;
        if (shouldInitCamera) {
          unawaited(initCamera());
        }
        break;
      case AppLifecycleState.detached:
        _shouldResumeCamera = false;
        unawaited(_shutdownCameraForPreviewExit());
        break;
    }
  }

  Future<void> initCamera() async {
    if (_isDisposed ||
        _isInitializingCamera ||
        !_requiresPreviewCamera ||
        !hasStartedVerificationFlow.value) {
      return;
    }

    _isInitializingCamera = true;
    errorText.value = "";
    isCameraReady.value = false;

    try {
      await _waitForCameraShutdown();

      if (_isDisposed || !_requiresPreviewCamera) {
        return;
      }

      final status = await Permission.camera.request();
      if (!status.isGranted) {
        hasCameraPermission.value = false;
        state.value = VerificationState.failed;
        errorText.value =
            status.isPermanentlyDenied
                ? "Quyền camera đã bị từ chối vĩnh viễn. Hãy bật lại trong cài đặt."
                : "Không thể truy cập camera. Vui lòng cấp quyền để tiếp tục.";
        instructionText.value = errorText.value;
        return;
      }

      hasCameraPermission.value = true;
      await _disposeCameraOnly();
      await _initFrontCamera();

      _resetLivenessSequence(updateInstruction: false);
      state.value = VerificationState.capturingSelfie;
      instructionText.value = "Đặt khuôn mặt vào khung và chụp ảnh";
    } catch (e, stackTrace) {
      if (e is CameraException) {
        debugPrint("initCamera camera error: ${e.code} ${e.description}");
      }
      await _shutdownCameraForPreviewExit();
      debugPrint("initCamera error: $e");
      debugPrintStack(stackTrace: stackTrace);
      state.value = VerificationState.failed;
      errorText.value = "Không thể khởi tạo camera. Vui lòng thử lại.";
      instructionText.value = errorText.value;
    } finally {
      _isInitializingCamera = false;
    }
  }

  Future<void> captureSelfie() async {
    final currentState = state.value;
    if (currentState != VerificationState.capturingSelfie &&
        currentState != VerificationState.idle) {
      return;
    }

    if (isCaptureLocked.value ||
        !isCameraReady.value ||
        cameraController == null) {
      return;
    }

    try {
      isCaptureLocked.value = true;
      final captured = await _safeTakePicture(cameraController!);
      final tempDirectory = await getTemporaryDirectory();
      final targetPath =
          "${tempDirectory.path}${Platform.pathSeparator}selfie.jpg";
      final savedFile = File(targetPath);
      await savedFile.writeAsBytes(await captured.readAsBytes(), flush: true);
      selfieFile = savedFile;

      state.value = VerificationState.liveness;
      instructionText.value = "Bat dau kiem tra liveness...";
      await startLiveness();
    } catch (e, stackTrace) {
      if (e is CameraException) {
        debugPrint("captureSelfie camera error: ${e.code} ${e.description}");
      }
      await _shutdownCameraForPreviewExit();
      debugPrint("captureSelfie error: $e");
      debugPrintStack(stackTrace: stackTrace);
      state.value = VerificationState.failed;
      errorText.value = "Chụp selfie thất bại. Vui lòng thử lại.";
      instructionText.value = errorText.value;
    } finally {
      isCaptureLocked.value = false;
    }
  }

  Future<void> startLiveness() async {
    if (state.value != VerificationState.liveness) {
      return;
    }

    final camera = cameraController;
    if (camera == null || !camera.value.isInitialized) {
      state.value = VerificationState.failed;
      errorText.value = "Camera chưa sẵn sàng cho bước liveness.";
      instructionText.value = errorText.value;
      return;
    }

    try {
      await _initFaceDetector();
      await _stopImageStream();

      _resetLivenessSequence();
      _isProcessingFrame = false;
      _lastFrameProcessedAt = DateTime.fromMillisecondsSinceEpoch(0);

      final streamSession = ++_activeStreamSession;
      await camera.startImageStream((image) {
        unawaited(_onCameraImage(image, streamSession));
      });
      _isStreaming = true;
    } catch (e, stackTrace) {
      if (e is CameraException) {
        debugPrint("startLiveness camera error: ${e.code} ${e.description}");
      }
      await _shutdownCameraForPreviewExit();
      debugPrint("startLiveness error: $e");
      debugPrintStack(stackTrace: stackTrace);
      state.value = VerificationState.failed;
      errorText.value = "Không thể bắt đầu liveness check.";
      instructionText.value = errorText.value;
    }
  }

  void onBlinkDetected() {
    if (blinkDetected.value) {
      return;
    }
    blinkDetected.value = true;
  }

  void onHeadTurnDetected() {
    if (headTurnDetected.value) {
      return;
    }
    headTurnDetected.value = true;
  }

  void _resetLivenessSequence({bool updateInstruction = true}) {
    blinkDetected.value = false;
    headTurnDetected.value = false;
    _livenessPassed = false;
    currentLivenessStep.value = 0;
    livenessStepDone.assignAll(
      List<bool>.filled(_livenessStepLabels.length, false),
    );
    _straightYawBaseline = null;
    _straightStableFrames = 0;
    _blinkPrimed = false;
    _lastLivenessStepAt = DateTime.fromMillisecondsSinceEpoch(0);
    if (updateInstruction) {
      _updateInstructionForCurrentStep();
    }
  }

  void _updateInstructionForCurrentStep() {
    switch (currentLivenessStep.value) {
      case 0:
        instructionText.value = "Bước 1/4: Nhìn thẳng vào camera";
        break;
      case 1:
        instructionText.value = "Bước 2/4: Chớp mắt";
        break;
      case 2:
        instructionText.value = "Bước 3/4: Quay đầu sang trái";
        break;
      case 3:
        instructionText.value = "Bước 4/4: Quay đầu sang phải";
        break;
      default:
        instructionText.value = "Bạn đã hoàn thành xác thực khuôn mặt";
        break;
    }
  }

  void _completeCurrentLivenessStep() {
    final step = currentLivenessStep.value;
    if (step < 0 || step >= _livenessStepLabels.length) {
      return;
    }

    final now = DateTime.now();
    if (now.difference(_lastLivenessStepAt) < _livenessStepGap) {
      return;
    }
    _lastLivenessStepAt = now;

    livenessStepDone[step] = true;
    if (step == 1) {
      onBlinkDetected();
    }

    if (step >= _livenessStepLabels.length - 1) {
      onHeadTurnDetected();
      _livenessPassed = true;
      instructionText.value = "Đang chụp ảnh xác thực...";
      return;
    }

    currentLivenessStep.value = step + 1;
    _updateInstructionForCurrentStep();
  }

  void _processLivenessStep(Face face) {
    final step = currentLivenessStep.value;
    final yaw = face.headEulerAngleY ?? 0;
    final roll = face.headEulerAngleZ ?? 0;

    switch (step) {
      case 0:
        final left = face.leftEyeOpenProbability;
        final right = face.rightEyeOpenProbability;
        final eyesAreOpen =
            left == null || right == null || (left > 0.4 && right > 0.4);
        final isStraight =
            eyesAreOpen &&
            yaw.abs() <= _straightYawTolerance &&
            roll.abs() <= _straightRollTolerance;
        if (!isStraight) {
          _straightStableFrames = 0;
          return;
        }

        _straightStableFrames++;
        if (_straightStableFrames >= _straightStableRequiredFrames) {
          _straightYawBaseline = yaw;
          _completeCurrentLivenessStep();
        }
        return;
      case 1:
        final left = face.leftEyeOpenProbability;
        final right = face.rightEyeOpenProbability;
        if (left == null || right == null) {
          return;
        }
        if (!_blinkPrimed &&
            left > _blinkOpenThreshold &&
            right > _blinkOpenThreshold) {
          _blinkPrimed = true;
        }
        final blinkClosed =
            left < _blinkClosedThreshold && right < _blinkClosedThreshold;
        if (_blinkPrimed && blinkClosed) {
          _completeCurrentLivenessStep();
        }
        return;
      case 2:
        final baseline = _straightYawBaseline ?? 0;
        final deltaYaw = yaw - baseline;
        if (deltaYaw <= -_turnYawThreshold) {
          _completeCurrentLivenessStep();
        }
        return;
      case 3:
        final baseline = _straightYawBaseline ?? 0;
        final deltaYaw = yaw - baseline;
        if (deltaYaw >= _turnYawThreshold) {
          _completeCurrentLivenessStep();
        }
        return;
      default:
        return;
    }
  }

  Future<void> onLivenessPassed() async {
    if (state.value == VerificationState.processing ||
        state.value == VerificationState.success) {
      return;
    }
    try {
      instructionText.value = "Đang chụp ảnh xác thực...";
      await _stopImageStream();
      await Future<void>.delayed(const Duration(milliseconds: 120));

      final camera = cameraController;
      if (camera == null || !camera.value.isInitialized) {
        throw Exception("Camera is not initialized.");
      }

      // Capture still image after liveness signals to keep best quality frame.
      final capturedFrame = await _safeTakePicture(camera);
      final tempDirectory = await getTemporaryDirectory();
      final targetPath =
          "${tempDirectory.path}${Platform.pathSeparator}live_frame.jpg";
      final savedFrame = File(targetPath);
      await savedFrame.writeAsBytes(
        await capturedFrame.readAsBytes(),
        flush: true,
      );
      liveFrameFile = savedFrame;

      await Future<void>.delayed(const Duration(milliseconds: 180));

      await _shutdownCameraForPreviewExit();

      final selfie = selfieFile;
      if (selfie == null) {
        throw Exception("Selfie file is missing.");
      }

      state.value = VerificationState.processing;
      instructionText.value = "Đang xử lý dữ liệu khuôn mặt ...";

      final isVerified = await _verificationService.uploadVerification(
        selfieFile: selfie,
        liveFrameFile: savedFrame,
      );

      if (isVerified) {
        await _markCurrentUserVerified();
        state.value = VerificationState.success;
        instructionText.value = "Xác thực thành công";
      } else {
        state.value = VerificationState.failed;
        errorText.value = "Xác thực thất bại. Vui lòng thử lại.";
        instructionText.value = errorText.value;
      }
    } catch (e, stackTrace) {
      if (e is CameraException) {
        debugPrint("onLivenessPassed camera error: ${e.code} ${e.description}");
      }
      await _shutdownCameraForPreviewExit();
      debugPrint("onLivenessPassed error: $e");
      debugPrintStack(stackTrace: stackTrace);
      state.value = VerificationState.failed;
      errorText.value = "Xác thực khuôn mặt thất bại. Vui lòng thử lại.";
      instructionText.value = errorText.value;
    }
  }

  Future<void> disposeResources() async {
    await _stopImageStream();
    await _disposeCameraOnly();
    await _disposeDetectorOnly();
  }

  Future<void> retryVerification() async {
    if (wasAlreadyVerifiedAtEntry.value) {
      hasStartedVerificationFlow.value = false;
      state.value = VerificationState.success;
      instructionText.value = "Tài khoản đã xác thực khuôn mặt";
      errorText.value = "";
      return;
    }
    selfieFile = null;
    liveFrameFile = null;
    hasStartedVerificationFlow.value = true;
    _resetLivenessSequence(updateInstruction: false);
    state.value = VerificationState.idle;
    instructionText.value = "Đặt khuôn mặt vào khung và chụp ảnh";
    errorText.value = "";
    await initCamera();
  }

  Future<void> openPermissionSettings() async {
    await openAppSettings();
  }

  Future<void> _onCameraImage(CameraImage image, int streamSession) async {
    if (streamSession != _activeStreamSession ||
        _isProcessingFrame ||
        !_isStreaming ||
        _livenessPassed) {
      return;
    }

    final now = DateTime.now();
    if (now.difference(_lastFrameProcessedAt) < _frameProcessInterval) {
      return;
    }

    _lastFrameProcessedAt = now;
    _isProcessingFrame = true;
    _pendingFrameProcessing = Completer<void>();

    try {
      if (streamSession != _activeStreamSession) {
        return;
      }

      final detector = _faceDetector;
      if (detector == null) {
        return;
      }

      final inputImage = _buildInputImage(image);
      if (inputImage == null) {
        return;
      }

      final faces = await detector.processImage(inputImage);
      if (streamSession != _activeStreamSession || !_isStreaming) {
        return;
      }
      if (faces.isEmpty) {
        if (currentLivenessStep.value == 0) {
          _straightStableFrames = 0;
        }
        return;
      }

      final targetFace = _pickPrimaryFace(faces);
      _processLivenessStep(targetFace);

      if (_livenessPassed) {
        unawaited(onLivenessPassed());
      }
    } catch (e, stackTrace) {
      if (e is PlatformException && e.code == "InputImageConverterError") {
        debugPrint("Liveness frame processing error: ${e.message ?? e.code}");
      } else {
        debugPrint("Liveness frame processing error: $e");
        debugPrintStack(stackTrace: stackTrace);
      }
    } finally {
      _isProcessingFrame = false;
      final pending = _pendingFrameProcessing;
      if (pending != null && !pending.isCompleted) {
        pending.complete();
      }
      _pendingFrameProcessing = null;
    }
  }

  Face _pickPrimaryFace(List<Face> faces) {
    if (faces.length == 1) {
      return faces.first;
    }

    Face largestFace = faces.first;
    double largestArea =
        largestFace.boundingBox.width * largestFace.boundingBox.height;
    for (int i = 1; i < faces.length; i++) {
      final candidate = faces[i];
      final area = candidate.boundingBox.width * candidate.boundingBox.height;
      if (area > largestArea) {
        largestArea = area;
        largestFace = candidate;
      }
    }
    return largestFace;
  }

  Future<void> _initFrontCamera() async {
    final cameras = await availableCameras();
    _frontCamera =
        cameras.firstWhereOrNull(
          (camera) => camera.lensDirection == CameraLensDirection.front,
        ) ??
        cameras.firstOrNull;

    if (_frontCamera == null) {
      throw Exception("Front camera not found.");
    }

    final formats =
        Platform.isIOS
            ? <ImageFormatGroup?>[ImageFormatGroup.bgra8888]
            : <ImageFormatGroup?>[
              ImageFormatGroup.nv21,
              ImageFormatGroup.yuv420,
              null,
            ];
    final presets = <ResolutionPreset>[
      ResolutionPreset.medium,
      ResolutionPreset.low,
      ResolutionPreset.high,
    ];

    CameraException? lastCameraError;

    for (final preset in presets) {
      for (final format in formats) {
        final candidate = CameraController(
          _frontCamera!,
          preset,
          enableAudio: false,
          imageFormatGroup: format,
        );

        try {
          await candidate.initialize();
          cameraController = candidate;
          isCameraReady.value = true;
          debugPrint(
            "initFrontCamera success: preset=$preset format=${format ?? 'default'}",
          );
          return;
        } on CameraException catch (e, stackTrace) {
          lastCameraError = e;
          debugPrint(
            "initFrontCamera failed: preset=$preset format=${format ?? 'default'} code=${e.code} desc=${e.description}",
          );
          debugPrintStack(stackTrace: stackTrace);
          try {
            await candidate.dispose();
          } catch (_) {}
        } catch (e, stackTrace) {
          debugPrint(
            "initFrontCamera failed: preset=$preset format=${format ?? 'default'} error=$e",
          );
          debugPrintStack(stackTrace: stackTrace);
          try {
            await candidate.dispose();
          } catch (_) {}
        }
      }
    }

    if (lastCameraError != null) {
      throw lastCameraError;
    }
    throw Exception("Unable to initialize camera with supported formats.");
  }

  Future<void> _initFaceDetector() async {
    _faceDetector ??= FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableTracking: false,
        minFaceSize: 0.2,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
  }

  InputImage? _buildInputImage(CameraImage image) {
    final camera = cameraController;
    if (camera == null) {
      return null;
    }

    final size = Size(image.width.toDouble(), image.height.toDouble());
    final rotation = _getImageRotation(camera);
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null || image.planes.isEmpty) {
      return null;
    }

    if (Platform.isAndroid) {
      // ML Kit Android bridge only accepts NV21/YV12 from bytes.
      if (format == InputImageFormat.nv21 && image.planes.length == 1) {
        final plane = image.planes.first;
        return InputImage.fromBytes(
          bytes: plane.bytes,
          metadata: InputImageMetadata(
            size: size,
            rotation: rotation,
            format: InputImageFormat.nv21,
            bytesPerRow: plane.bytesPerRow,
          ),
        );
      }
      if (format == InputImageFormat.yuv_420_888 && image.planes.length >= 3) {
        final nv21Bytes = _convertYuv420ToNv21(image);
        return InputImage.fromBytes(
          bytes: nv21Bytes,
          metadata: InputImageMetadata(
            size: size,
            rotation: rotation,
            format: InputImageFormat.nv21,
            bytesPerRow: image.width,
          ),
        );
      }
      if (format == InputImageFormat.yv12 && image.planes.length == 1) {
        final plane = image.planes.first;
        return InputImage.fromBytes(
          bytes: plane.bytes,
          metadata: InputImageMetadata(
            size: size,
            rotation: rotation,
            format: InputImageFormat.yv12,
            bytesPerRow: plane.bytesPerRow,
          ),
        );
      }
      return null;
    }

    if (Platform.isIOS) {
      if (format != InputImageFormat.bgra8888 || image.planes.length != 1) {
        return null;
      }
      final plane = image.planes.first;
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: size,
          rotation: rotation,
          format: InputImageFormat.bgra8888,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    }

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: size,
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Uint8List _convertYuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final expectedSize = width * height + (width * height ~/ 2);
    final bytes = _getReusableNv21Buffer(expectedSize);
    var offset = 0;

    final yRowStride = yPlane.bytesPerRow;
    final yPixelStride = yPlane.bytesPerPixel ?? 1;
    for (int y = 0; y < height; y++) {
      final yRowOffset = y * yRowStride;
      for (int x = 0; x < width; x++) {
        bytes[offset++] = yPlane.bytes[yRowOffset + x * yPixelStride];
      }
    }

    final uvWidth = width ~/ 2;
    final uvHeight = height ~/ 2;
    final uRowStride = uPlane.bytesPerRow;
    final vRowStride = vPlane.bytesPerRow;
    final uPixelStride = uPlane.bytesPerPixel ?? 1;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;

    for (int y = 0; y < uvHeight; y++) {
      final uRowOffset = y * uRowStride;
      final vRowOffset = y * vRowStride;
      for (int x = 0; x < uvWidth; x++) {
        final uIndex = uRowOffset + x * uPixelStride;
        final vIndex = vRowOffset + x * vPixelStride;
        bytes[offset++] = vPlane.bytes[vIndex];
        bytes[offset++] = uPlane.bytes[uIndex];
      }
    }
    return bytes;
  }

  Uint8List _getReusableNv21Buffer(int length) {
    final current = _nv21ReusableBuffer;
    if (current != null && current.length == length) {
      return current;
    }
    final allocated = Uint8List(length);
    _nv21ReusableBuffer = allocated;
    return allocated;
  }

  InputImageRotation _getImageRotation(CameraController camera) {
    final sensorOrientation = camera.description.sensorOrientation;
    final deviceOrientation = camera.value.deviceOrientation;
    int rotationCompensation;

    switch (deviceOrientation) {
      case DeviceOrientation.portraitUp:
        rotationCompensation = 0;
      case DeviceOrientation.landscapeLeft:
        rotationCompensation = 90;
      case DeviceOrientation.portraitDown:
        rotationCompensation = 180;
      case DeviceOrientation.landscapeRight:
        rotationCompensation = 270;
    }

    final rotation =
        camera.description.lensDirection == CameraLensDirection.front
            ? (sensorOrientation + rotationCompensation) % 360
            : (sensorOrientation - rotationCompensation + 360) % 360;

    return InputImageRotationValue.fromRawValue(rotation) ??
        InputImageRotation.rotation0deg;
  }

  Future<void> _stopImageStream() async {
    final camera = cameraController;
    if (camera == null) {
      _isStreaming = false;
      _activeStreamSession++;
      await _waitForPendingFrameProcessing();
      _isProcessingFrame = false;
      return;
    }

    final hasRunningStream = _isStreaming || camera.value.isStreamingImages;
    if (!hasRunningStream) {
      await _waitForPendingFrameProcessing();
      _isProcessingFrame = false;
      return;
    }

    _isStreaming = false;
    _activeStreamSession++;
    try {
      if (camera.value.isStreamingImages) {
        await camera.stopImageStream();
      }
    } catch (e, stackTrace) {
      debugPrint("stopImageStream error: $e");
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      await _waitForPendingFrameProcessing();
      _isProcessingFrame = false;
    }
  }

  Future<void> _disposeCameraOnly() async {
    final camera = cameraController;
    if (camera == null) {
      isCameraReady.value = false;
      return;
    }

    try {
      await _waitForPendingFrameProcessing();
      if (camera.value.isStreamingImages) {
        await camera.stopImageStream();
      }
      await camera.dispose();
    } catch (e, stackTrace) {
      debugPrint("dispose camera error: $e");
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      cameraController = null;
      isCameraReady.value = false;
      _isStreaming = false;
      _isProcessingFrame = false;
      _nv21ReusableBuffer = null;
    }
  }

  Future<void> _waitForPendingFrameProcessing() async {
    final pending = _pendingFrameProcessing;
    if (pending == null) {
      return;
    }
    try {
      await pending.future.timeout(const Duration(milliseconds: 250));
    } catch (_) {}
  }

  Future<void> _disposeDetectorOnly() async {
    final detector = _faceDetector;
    if (detector == null) {
      return;
    }

    try {
      await detector.close();
    } catch (e, stackTrace) {
      debugPrint("dispose detector error: $e");
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _faceDetector = null;
    }
  }

  Future<void> _shutdownCameraForPreviewExit() async {
    if (_isShuttingDownCamera) {
      return;
    }
    _isShuttingDownCamera = true;
    try {
      await _stopImageStream();
      await _disposeCameraOnly();
      await _disposeDetectorOnly();
    } finally {
      _isShuttingDownCamera = false;
    }
  }

  Future<void> _markCurrentUserVerified() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception("User chua dang nhap.");
    }
    await _db.collection("users").doc(uid).set({
      "isFaceVerified": true,
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    isAlreadyVerified.value = true;
  }

  Future<XFile> _safeTakePicture(CameraController camera) async {
    for (int i = 0; i < 8; i++) {
      if (!camera.value.isInitialized) {
        throw Exception("Camera is not initialized.");
      }
      if (!camera.value.isTakingPicture) {
        return camera.takePicture();
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
    throw Exception("Camera is busy, cannot capture image.");
  }

  bool get _requiresPreviewCamera =>
      hasStartedVerificationFlow.value &&
      (state.value == VerificationState.idle ||
          state.value == VerificationState.capturingSelfie ||
          state.value == VerificationState.liveness);

  Future<void> _waitForCameraShutdown() async {
    for (int i = 0; i < 20; i++) {
      if (!_isShuttingDownCamera) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
  }
}
