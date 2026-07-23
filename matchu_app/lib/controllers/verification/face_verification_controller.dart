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
import 'package:matchu_app/repositories/verification/face_verification_repository.dart';
import 'package:matchu_app/services/security/passcode_backup_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

enum FaceVerificationMode { enrollment, reauthentication }

class FaceVerificationController extends GetxController
    with WidgetsBindingObserver {
  FaceVerificationController({
    FaceVerificationRepository? verificationRepository,
  }) : _verificationRepository =
           verificationRepository ??
           (throw ArgumentError.notNull('verificationRepository')),
       mode = _readMode(Get.arguments),
       purpose = _readPurpose(Get.arguments);

  final FaceVerificationRepository _verificationRepository;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FaceVerificationMode mode;
  final String purpose;

  final Rx<VerificationState> state = VerificationState.idle.obs;
  final RxBool headTurnDetected = false.obs;
  final RxBool hasStartedVerificationFlow = false.obs;
  final RxBool isCheckingVerificationStatus = true.obs;
  final RxBool isAlreadyVerified = false.obs;
  final RxBool wasAlreadyVerifiedAtEntry = false.obs;
  final RxInt currentLivenessStep = 0.obs;
  final RxList<bool> livenessStepDone = <bool>[].obs;
  final RxList<String> _challengeStepLabels = <String>[].obs;
  final RxString instructionText = "Đặt khuôn mặt vào khung và chụp ảnh".obs;

  final RxBool isCameraReady = false.obs;
  final RxBool hasCameraPermission = false.obs;
  final RxBool isCaptureLocked = false.obs;
  final RxString errorText = "".obs;
  final RxBool isPinActionRunning = false.obs;

  File? selfieFile;
  File? liveFrameFile;
  final List<File> _livenessEvidenceFiles = <File>[];
  FaceLivenessChallenge? _livenessChallenge;
  FaceTemplateUpdateAuthorization? _templateUpdateAuthorization;
  FaceVerificationResult? _successfulResult;

  CameraController? cameraController;

  FaceDetector? _faceDetector;
  CameraDescription? _frontCamera;
  bool _isStreaming = false;
  bool _isProcessingFrame = false;
  bool _isInitializingCamera = false;
  bool _isShuttingDownCamera = false;
  bool _livenessPassed = false;
  bool _stepEvidenceCaptureInProgress = false;
  bool _shouldResumeCamera = false;
  bool _isDisposed = false;
  bool _serverRequiresTemplateUpdatePin = false;
  int _activeStreamSession = 0;
  Completer<void>? _pendingFrameProcessing;
  Timer? _evidenceCaptureTimer;
  Uint8List? _nv21ReusableBuffer;
  double? _straightYawBaseline;
  int _straightStableFrames = 0;
  DateTime _lastLivenessStepAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastFrameProcessedAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _frameProcessInterval = Duration(milliseconds: 120);
  static const Duration _livenessStepGap = Duration(milliseconds: 350);
  static const int _straightStableRequiredFrames = 3;
  static const double _straightYawTolerance = 8;
  static const double _straightRollTolerance = 10;
  static const double _turnYawThreshold = 14;
  static FaceVerificationMode _readMode(dynamic arguments) {
    if (arguments is Map && arguments["mode"] == "reauth") {
      return FaceVerificationMode.reauthentication;
    }
    return FaceVerificationMode.enrollment;
  }

  static String _readPurpose(dynamic arguments) {
    if (arguments is Map && arguments["purpose"] == "video_matching") {
      return "video_matching";
    }
    return "face_reauth";
  }

  bool get isReauthentication => mode == FaceVerificationMode.reauthentication;

  Map<String, dynamic> get successResultPayload {
    final result = _successfulResult;
    return <String, dynamic>{
      "success": state.value == VerificationState.success,
      "mode": isReauthentication ? "reauth" : "enroll",
      if (result?.sessionId != null) "sessionId": result!.sessionId,
      if (result?.expiresAt != null)
        "expiresAt": result!.expiresAt!.toIso8601String(),
    };
  }

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
    _verificationRepository.dispose();
    super.onClose();
  }

  List<String> get livenessStepLabels => _challengeStepLabels.toList();

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

      if (isReauthentication) {
        if (!isVerified) {
          state.value = VerificationState.failed;
          errorText.value =
              "Tài khoản này chưa xác thực khuôn mặt. Vui lòng nhập mã PIN.";
          instructionText.value = errorText.value;
          return;
        }

        hasStartedVerificationFlow.value = false;
        state.value = VerificationState.idle;
        errorText.value = "";
        instructionText.value =
            "Quét khuôn mặt để mở khóa tin nhắn trên thiết bị này";
      } else if (isVerified) {
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
    if (isReauthentication) {
      if (!isAlreadyVerified.value) {
        state.value = VerificationState.failed;
        errorText.value =
            "Tài khoản này chưa xác thực khuôn mặt. Vui lòng nhập mã PIN.";
        instructionText.value = errorText.value;
        return;
      }
      if (hasStartedVerificationFlow.value) {
        return;
      }
      hasStartedVerificationFlow.value = true;
      unawaited(initCamera());
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
          if (this.state.value == VerificationState.liveness) {
            unawaited(_restartLivenessAfterPause());
          } else {
            unawaited(initCamera());
          }
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
      if (isReauthentication || state.value == VerificationState.liveness) {
        state.value = VerificationState.liveness;
        instructionText.value = "Bắt đầu kiểm tra liveness...";
        await startLiveness();
        return;
      }

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
      _livenessChallenge ??= await _verificationRepository
          .createLivenessChallenge(purpose: purpose);
      final challenge = _livenessChallenge;
      if (challenge == null || !challenge.isValid) {
        throw StateError("Unable to create a liveness challenge.");
      }
      _challengeStepLabels.assignAll(
        challenge.actions.map(_labelForLivenessAction),
      );
      await _initFaceDetector();
      await _stopImageStream();

      _resetLivenessSequence();
      _isProcessingFrame = false;
      _lastFrameProcessedAt = DateTime.fromMillisecondsSinceEpoch(0);
      await _startLivenessImageStream();
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

  void onHeadTurnDetected() {
    if (headTurnDetected.value) {
      return;
    }
    headTurnDetected.value = true;
  }

  void _resetLivenessSequence({bool updateInstruction = true}) {
    headTurnDetected.value = false;
    _livenessPassed = false;
    _stepEvidenceCaptureInProgress = false;
    currentLivenessStep.value = 0;
    livenessStepDone.assignAll(
      List<bool>.filled(_challengeStepLabels.length, false),
    );
    _straightYawBaseline = null;
    _straightStableFrames = 0;
    _lastLivenessStepAt = DateTime.fromMillisecondsSinceEpoch(0);
    if (updateInstruction) {
      _updateInstructionForCurrentStep();
    }
  }

  void _updateInstructionForCurrentStep() {
    final index = currentLivenessStep.value;
    if (index < 0 || index >= _challengeStepLabels.length) {
      instructionText.value = "Bạn đã hoàn thành xác thực khuôn mặt";
      return;
    }
    instructionText.value =
        "Bước ${index + 1}/${_challengeStepLabels.length}: "
        "${_challengeStepLabels[index]}";
  }

  String _labelForLivenessAction(String action) {
    return switch (action) {
      "center" => "Nhìn thẳng vào camera",
      "turn_left" => "Quay đầu sang trái và giữ nguyên",
      "turn_right" => "Quay đầu sang phải và giữ nguyên",
      _ => "Làm theo hướng dẫn",
    };
  }

  Future<void> _startLivenessImageStream() async {
    final camera = cameraController;
    if (camera == null || !camera.value.isInitialized || _isStreaming) return;
    final streamSession = ++_activeStreamSession;
    await camera.startImageStream((image) {
      unawaited(_onCameraImage(image, streamSession));
    });
    _isStreaming = true;
  }

  void _scheduleCurrentStepEvidenceCapture() {
    final step = currentLivenessStep.value;
    if (step < 0 ||
        step >= _challengeStepLabels.length ||
        _stepEvidenceCaptureInProgress) {
      return;
    }
    final now = DateTime.now();
    if (now.difference(_lastLivenessStepAt) < _livenessStepGap) {
      return;
    }
    _lastLivenessStepAt = now;
    _stepEvidenceCaptureInProgress = true;
    instructionText.value = "Giữ nguyên tư thế...";
    // Let the current ML Kit frame callback finish before stopping its stream.
    _evidenceCaptureTimer?.cancel();
    _evidenceCaptureTimer = Timer(const Duration(milliseconds: 40), () {
      if (_isDisposed ||
          state.value != VerificationState.liveness ||
          step != currentLivenessStep.value) {
        _stepEvidenceCaptureInProgress = false;
        return;
      }
      unawaited(_captureCurrentStepEvidence(step));
    });
  }

  void _processLivenessStep(Face face) {
    final step = currentLivenessStep.value;
    final challenge = _livenessChallenge;
    if (challenge == null ||
        step < 0 ||
        step >= challenge.actions.length ||
        _stepEvidenceCaptureInProgress) {
      return;
    }
    final yaw = face.headEulerAngleY ?? 0;
    final roll = face.headEulerAngleZ ?? 0;
    final action = challenge.actions[step];

    switch (action) {
      case "center":
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
          _scheduleCurrentStepEvidenceCapture();
        }
        return;
      case "turn_left":
        final baseline = _straightYawBaseline ?? 0;
        final deltaYaw = yaw - baseline;
        if (deltaYaw <= -_turnYawThreshold) {
          _scheduleCurrentStepEvidenceCapture();
        }
        return;
      case "turn_right":
        final baseline = _straightYawBaseline ?? 0;
        final deltaYaw = yaw - baseline;
        if (deltaYaw >= _turnYawThreshold) {
          _scheduleCurrentStepEvidenceCapture();
        }
        return;
      default:
        return;
    }
  }

  Future<void> _captureCurrentStepEvidence(int step) async {
    try {
      await _stopImageStream();
      final camera = cameraController;
      if (camera == null || !camera.value.isInitialized) {
        throw StateError("Camera is unavailable for liveness evidence.");
      }
      final captured = await _safeTakePicture(camera);
      final directory = await getTemporaryDirectory();
      final file = File(
        "${directory.path}${Platform.pathSeparator}"
        "liveness_evidence_$step.jpg",
      );
      await file.writeAsBytes(await captured.readAsBytes(), flush: true);
      _livenessEvidenceFiles.add(file);
      livenessStepDone[step] = true;

      if (step >= _challengeStepLabels.length - 1) {
        onHeadTurnDetected();
        _livenessPassed = true;
        instructionText.value = "Đang chụp ảnh xác thực...";
        _stepEvidenceCaptureInProgress = false;
        await onLivenessPassed();
        return;
      }

      currentLivenessStep.value = step + 1;
      _straightStableFrames = 0;
      _updateInstructionForCurrentStep();
      _stepEvidenceCaptureInProgress = false;
      await _startLivenessImageStream();
    } catch (error, stackTrace) {
      debugPrint("capture liveness evidence error: $error");
      debugPrintStack(stackTrace: stackTrace);
      _stepEvidenceCaptureInProgress = false;
      await _shutdownCameraForPreviewExit();
      state.value = VerificationState.failed;
      errorText.value = "Không thể ghi nhận bước xác thực. Vui lòng thử lại.";
      instructionText.value = errorText.value;
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

      state.value = VerificationState.processing;
      instructionText.value = "Đang xử lý dữ liệu khuôn mặt ...";

      final challenge = _livenessChallenge;
      if (challenge == null ||
          _livenessEvidenceFiles.length != challenge.actions.length) {
        throw StateError("Liveness evidence is incomplete.");
      }
      final verificationResult =
          isReauthentication
              ? await _verificationRepository.reauthenticate(
                liveFrameFile: savedFrame,
                challenge: challenge,
                evidenceFrames: List<File>.unmodifiable(_livenessEvidenceFiles),
                purpose: purpose,
              )
              : await _verificationRepository.enrollVerification(
                selfieFile:
                    selfieFile ?? (throw Exception("Selfie file is missing.")),
                liveFrameFile: savedFrame,
                challenge: challenge,
                evidenceFrames: List<File>.unmodifiable(_livenessEvidenceFiles),
                purpose: purpose,
                templateUpdateAuthorizationId: _templateUpdateAuthorization?.id,
              );

      final hasRequiredReauthSession =
          !isReauthentication ||
          ((verificationResult.sessionId ?? "").trim().isNotEmpty);

      if (verificationResult.success && hasRequiredReauthSession) {
        _successfulResult = verificationResult;
        if (!isReauthentication) {
          await _syncCurrentUserVerifiedState();
          await PasscodeBackupService.syncFaceRecoveryBackupIfEligible();
          _templateUpdateAuthorization = null;
          _serverRequiresTemplateUpdatePin = false;
        }
        state.value = VerificationState.success;
        instructionText.value = "Xác thực thành công";
      } else {
        if (verificationResult.reason ==
                "template_update_authorization_required" ||
            verificationResult.reason ==
                "template_update_authorization_invalid") {
          _templateUpdateAuthorization = null;
          _serverRequiresTemplateUpdatePin = true;
        }
        state.value = VerificationState.failed;
        errorText.value = _messageForVerificationReason(
          verificationResult.reason,
        );
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
    } finally {
      await _deleteTemporaryFaceFiles();
    }
  }

  Future<void> disposeResources() async {
    _evidenceCaptureTimer?.cancel();
    _evidenceCaptureTimer = null;
    await _stopImageStream();
    await _disposeCameraOnly();
    await _disposeDetectorOnly();
    await _deleteTemporaryFaceFiles();
  }

  Future<void> retryVerification() async {
    if (!isReauthentication &&
        (wasAlreadyVerifiedAtEntry.value || _serverRequiresTemplateUpdatePin) &&
        _templateUpdateAuthorization?.isValid != true) {
      startTemplateUpdatePinAuthorization();
      return;
    }
    await _deleteTemporaryFaceFiles();
    _successfulResult = null;
    _livenessChallenge = null;
    _challengeStepLabels.clear();
    hasStartedVerificationFlow.value = true;
    _resetLivenessSequence(updateInstruction: false);
    state.value = VerificationState.idle;
    instructionText.value = "Đặt khuôn mặt vào khung và chụp ảnh";
    errorText.value = "";
    await initCamera();
  }

  void startTemplateUpdatePinAuthorization() {
    if (isReauthentication ||
        (!wasAlreadyVerifiedAtEntry.value &&
            !_serverRequiresTemplateUpdatePin) ||
        isPinActionRunning.value) {
      return;
    }
    errorText.value = "";
    state.value = VerificationState.authorizingUpdate;
  }

  Future<bool> confirmTemplateUpdatePin(String passcode) async {
    if (isPinActionRunning.value) {
      return false;
    }
    final normalizedPasscode = passcode.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(normalizedPasscode)) {
      errorText.value = "Mã PIN phải gồm đúng 6 chữ số.";
      return false;
    }

    isPinActionRunning.value = true;
    errorText.value = "";
    try {
      final authorization = await _verificationRepository
          .authorizeTemplateUpdateWithPin(passcode: normalizedPasscode);
      _templateUpdateAuthorization = authorization;
      await retryVerification();
      return true;
    } catch (error) {
      errorText.value = _messageForPinError(error);
      return false;
    } finally {
      isPinActionRunning.value = false;
    }
  }

  void cancelTemplateUpdatePin() {
    if (wasAlreadyVerifiedAtEntry.value) {
      errorText.value = "";
      state.value = VerificationState.success;
    } else {
      errorText.value =
          "Cần nhập đúng mã PIN chat để cập nhật dữ liệu khuôn mặt hiện có.";
      state.value = VerificationState.failed;
    }
  }

  String _messageForVerificationReason(String? reason) {
    return switch (reason) {
      "face_not_detected" => "Không tìm thấy khuôn mặt rõ ràng trong ảnh.",
      "multiple_faces_detected" =>
        "Chỉ được có một khuôn mặt trong khung hình.",
      "image_too_dark" => "Ảnh quá tối. Hãy chuyển đến nơi đủ sáng.",
      "image_too_bright" => "Ảnh quá sáng. Hãy tránh nguồn sáng trực tiếp.",
      "image_too_blurry" => "Ảnh bị mờ. Hãy giữ thiết bị ổn định.",
      "face_too_small" => "Hãy đưa khuôn mặt gần khung hướng dẫn hơn.",
      "face_mismatch" || "challenge_identity_mismatch" =>
        "Khuôn mặt không khớp với dữ liệu đã xác thực.",
      "challenge_invalid" ||
      "challenge_not_found" => "Phiên kiểm tra đã hết hạn. Vui lòng thử lại.",
      "challenge_replay_detected" =>
        "Ảnh xác thực đã được sử dụng trước đó. Vui lòng quét lại.",
      "challenge_pose_invalid" || "challenge_turn_pose_invalid" =>
        "Tư thế khuôn mặt chưa đúng hướng dẫn. Vui lòng thử lại.",
      "template_update_authorization_required" ||
      "template_update_authorization_invalid" =>
        "Quyền cập nhật khuôn mặt đã hết hạn. Vui lòng nhập lại mã PIN.",
      "liveness_rate_limited" =>
        "Bạn đã thử quá nhiều lần. Vui lòng quay lại sau.",
      _ => "Xác thực thất bại. Vui lòng thử lại.",
    };
  }

  String _messageForPinError(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains("incorrect") || raw.contains("permission-denied")) {
      return "Mã PIN không đúng. Vui lòng thử lại.";
    }
    if (raw.contains("resource-exhausted") || raw.contains("too many")) {
      return "Bạn đã thử quá nhiều lần. Vui lòng thử lại sau.";
    }
    if (raw.contains("failed-precondition")) {
      return "Bạn cần thiết lập mã PIN bảo vệ chat trước khi cập nhật khuôn mặt.";
    }
    return "Không thể kiểm tra mã PIN. Vui lòng thử lại.";
  }

  Future<void> _restartLivenessAfterPause() async {
    await _deleteLivenessEvidenceFiles();
    _livenessChallenge = null;
    _challengeStepLabels.clear();
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
        instructionText.value = "Đưa khuôn mặt vào giữa khung hình";
        return;
      }
      if (faces.length != 1) {
        _straightStableFrames = 0;
        instructionText.value = "Chỉ để một khuôn mặt trong khung hình";
        return;
      }

      if (!_stepEvidenceCaptureInProgress) {
        _updateInstructionForCurrentStep();
      }
      final targetFace = faces.single;
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
      _evidenceCaptureTimer?.cancel();
      _evidenceCaptureTimer = null;
      await _stopImageStream();
      await _disposeCameraOnly();
      await _disposeDetectorOnly();
    } finally {
      _isShuttingDownCamera = false;
    }
  }

  Future<void> _syncCurrentUserVerifiedState() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception("User chua dang nhap.");
    }

    try {
      final snapshot = await _db.collection("users").doc(uid).get();
      if (snapshot.data()?["isFaceVerified"] != true) {
        debugPrint(
          "Face enrollment succeeded but user document is not marked verified yet.",
        );
      }
    } catch (e) {
      debugPrint("Unable to refresh face verification state: $e");
    }
    isAlreadyVerified.value = true;
  }

  Future<void> _deleteTemporaryFaceFiles() async {
    final files = <File?>[selfieFile, liveFrameFile];
    selfieFile = null;
    liveFrameFile = null;

    for (final file in files) {
      if (file == null) {
        continue;
      }
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint("delete temporary face file error: $e");
      }
    }
    await _deleteLivenessEvidenceFiles();
  }

  Future<void> _deleteLivenessEvidenceFiles() async {
    final files = List<File>.from(_livenessEvidenceFiles);
    _livenessEvidenceFiles.clear();
    for (final file in files) {
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint("delete liveness evidence error: $e");
      }
    }
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
