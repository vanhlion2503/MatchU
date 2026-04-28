import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:matchu_app/controllers/auth/auth_gate_controller.dart';
import 'package:matchu_app/controllers/chat/anonymous_avatar_controller.dart';
import 'package:matchu_app/services/auth/auth_service.dart';
import 'package:matchu_app/services/auth/logout_service.dart';
import 'package:matchu_app/services/security/identity_key_service.dart';
import 'package:matchu_app/services/user/avatar_service.dart';
import 'package:matchu_app/translates/firebase_error_translator.dart';
import 'package:matchu_app/utils/profile_input_validator.dart';

enum DobField { day, month, year }

class AuthController extends GetxController {
  final AuthService _auth = AuthService();

  // ========= INPUT CONTROLLERS =========
  final emailC = TextEditingController();
  final passwordC = TextEditingController();
  final confirmPasswordC = TextEditingController();
  final otpC = TextEditingController();
  final fullnameC = TextEditingController();
  final nicknameC = TextEditingController();
  final birthdayC = TextEditingController();

  final RxString fullPhoneNumber = ''.obs;
  final Rx<DateTime?> selectedBirthday = Rx<DateTime?>(null);
  final RxString selectedGender = ''.obs;
  final _box = GetStorage();

  // ========= UI STATE =========
  final isPasswordHidden = true.obs;
  final isLoadingRegister = false.obs;
  final isLoadingLogin = false.obs;

  final resendEmailSeconds = 60.obs;
  final resendEnrollOtpSeconds = 60.obs;
  final resendLoginOtpSeconds = 60.obs;

  final selectedDobField = Rxn<DobField>();

  final selectedDay = RxnInt();
  final selectedMonth = RxnInt();
  final selectedYear = RxnInt();
  final tempAvatarFile = Rxn<File>();
  final isUploadingAvatar = false.obs;
  final isCheckingNickname = false.obs;
  final isNicknameAvailable = RxnBool();
  final nicknameCheckMessage = ''.obs;
  final RxString _nicknameDraft = ''.obs;

  Timer? _emailTimer;
  Timer? _enrollTimer;
  Timer? _loginTimer;
  Worker? _nicknameDebounceWorker;

  int _nicknameCheckToken = 0;
  bool _isNormalizingFullname = false;
  bool _isNormalizingNickname = false;

  // ========= FIREBASE USER STREAM =========
  final Rxn<User> _userRx = Rxn<User>();
  User? get user => _userRx.value;

  FirebaseAuthMultiFactorException? _mfaException;
  String? enrollVerificationId;
  String? loginVerificationId;

  @override
  void onInit() {
    super.onInit();
    // Lắng nghe trạng thái đăng nhập nhưng KHÔNG redirect
    _userRx.bindStream(_auth.authStateChanges);
    _nicknameDebounceWorker = debounce<String>(
      _nicknameDraft,
      (value) => _checkNicknameDebounced(value),
      time: const Duration(milliseconds: 500),
    );
  }

  void updateBirthdayIfReady() {
    if (selectedDay.value == null ||
        selectedMonth.value == null ||
        selectedYear.value == null) {
      return;
    }

    final y = selectedYear.value!;
    final m = selectedMonth.value!;
    final d = selectedDay.value!;

    // 🔒 Validate số ngày trong tháng
    final lastDayOfMonth = DateTime(y, m + 1, 0).day;
    if (d > lastDayOfMonth) {
      selectedDay.value = lastDayOfMonth;
    }

    final date = DateTime(y, m, selectedDay.value!);

    selectedBirthday.value = date;
    birthdayC.text = DateFormat('dd/MM/yyyy').format(date);
  }

  void onMonthChanged(int month) {
    selectedMonth.value = month;
    updateBirthdayIfReady();
  }

  void onYearChanged(int year) {
    selectedYear.value = year;
    updateBirthdayIfReady();
  }

  void onFullnameChanged(String value) {
    if (_isNormalizingFullname) return;

    final normalized = value.replaceAll(RegExp(r' {2,}'), ' ').trimLeft();
    if (normalized == value) return;

    _isNormalizingFullname = true;
    _replaceControllerText(fullnameC, normalized);
    _isNormalizingFullname = false;
  }

  void onNicknameChanged(String value) {
    if (_isNormalizingNickname) return;

    final normalized = ProfileInputValidator.sanitizeNicknameRealtime(value);
    if (normalized != value) {
      _isNormalizingNickname = true;
      _replaceControllerText(nicknameC, normalized);
      _isNormalizingNickname = false;
    }

    _scheduleNicknameCheck(normalized);
  }

  void _scheduleNicknameCheck(String nickname) {
    final localError = ProfileInputValidator.validateNickname(nickname);

    _nicknameCheckToken++;
    isCheckingNickname.value = false;

    if (nickname.isEmpty) {
      isNicknameAvailable.value = null;
      nicknameCheckMessage.value = '';
      _nicknameDraft.value = '';
      return;
    }

    if (localError != null) {
      isNicknameAvailable.value = null;
      nicknameCheckMessage.value = localError;
      _nicknameDraft.value = '';
      return;
    }

    isNicknameAvailable.value = null;
    nicknameCheckMessage.value = '';
    _nicknameDraft.value = nickname;
  }

  Future<void> _checkNicknameDebounced(String nickname) async {
    if (nickname.isEmpty) return;

    final currentNickname = ProfileInputValidator.normalizeNickname(
      nicknameC.text,
    );
    if (currentNickname != nickname) return;

    await _checkNicknameAvailability(nickname);
  }

  Future<bool?> _checkNicknameAvailability(String nickname) async {
    final currentToken = ++_nicknameCheckToken;
    isCheckingNickname.value = true;

    try {
      final isUnique = await _auth.isNicknameUnique(nickname);

      final latestNickname = ProfileInputValidator.normalizeNickname(
        nicknameC.text,
      );
      if (currentToken != _nicknameCheckToken || latestNickname != nickname) {
        return null;
      }

      isNicknameAvailable.value = isUnique;
      nicknameCheckMessage.value =
          isUnique ? "Nickname có thể sử dụng" : "Nickname đã được sử dụng";
      return isUnique;
    } catch (_) {
      if (currentToken == _nicknameCheckToken) {
        isNicknameAvailable.value = null;
        nicknameCheckMessage.value =
            "Không thể kiểm tra nickname. Vui lòng thử lại";
      }
      return null;
    } finally {
      if (currentToken == _nicknameCheckToken) {
        isCheckingNickname.value = false;
      }
    }
  }

  Future<bool> _ensureNicknameUnique(String nickname) async {
    if (!isCheckingNickname.value &&
        ProfileInputValidator.normalizeNickname(nicknameC.text) == nickname &&
        isNicknameAvailable.value != null) {
      return isNicknameAvailable.value == true;
    }

    final checked = await _checkNicknameAvailability(nickname);
    return checked == true;
  }

  void _replaceControllerText(
    TextEditingController controller,
    String nextText,
  ) {
    final oldValue = controller.value;
    final oldText = oldValue.text;
    final lengthDelta = oldText.length - nextText.length;
    final baseOffset = oldValue.selection.baseOffset;

    final nextOffset =
        baseOffset < 0 ? nextText.length : (baseOffset - lengthDelta);

    controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(
        offset: nextOffset.clamp(0, nextText.length),
      ),
    );
  }

  // =============================================================
  //                      REGISTER ACCOUNT
  // =============================================================
  Future<void> register() async {
    _box.remove('isRegistering');
    if (emailC.text.isEmpty || passwordC.text.isEmpty) {
      Get.snackbar("Lỗi", "Vui lòng nhập đầy đủ thông tin");
      return;
    }

    if (passwordC.text.length < 6) {
      Get.snackbar("Lỗi", "Mật khẩu phải từ 6 ký tự trở lên");
      return;
    }

    if (passwordC.text != confirmPasswordC.text) {
      Get.snackbar("Lỗi", "Mật khẩu nhập lại không khớp");
      return;
    }

    _box.write('isRegistering', true);
    isLoadingRegister.value = true;

    try {
      await _auth.registerWithEmailAndPassWord(
        email: emailC.text.trim(),
        password: passwordC.text.trim(),
        onSuccess: () {
          isLoadingRegister.value = false;
          Get.toNamed('/verify-email');
        },
        onFailed: (errorMsg) {
          isLoadingRegister.value = false;
          _box.remove('isRegistering');
          Get.snackbar("Đăng ký thất bại", errorMsg);
        },
      );
    } on FirebaseAuthException catch (e) {
      isLoadingRegister.value = false;
      _box.remove('isRegistering');
      Get.snackbar("Đăng ký thất bại", firebaseErrorToVietnamese(e.code));
    } catch (e) {
      isLoadingRegister.value = false;
      _box.remove('isRegistering');
      Get.snackbar("Đăng ký thất bại", e.toString());
    }
  }

  Future<void> cancelRegistrationFlow({
    String redirectRoute = '/register',
  }) async {
    if (isLoadingRegister.value) return;

    isLoadingRegister.value = true;
    final auth = FirebaseAuth.instance;

    try {
      final currentUser = auth.currentUser;
      if (currentUser != null) {
        try {
          await currentUser.reload();
        } catch (_) {}

        final refreshedUser = auth.currentUser;
        if (refreshedUser != null) {
          bool shouldDelete = true;
          try {
            final userDoc =
                await _auth.db.collection('users').doc(refreshedUser.uid).get();
            final completed = userDoc.data()?['isProfileCompleted'] == true;
            shouldDelete = !completed;
          } catch (_) {}

          if (shouldDelete) {
            try {
              await refreshedUser.delete();
            } on FirebaseAuthException {
              await auth.signOut();
            }
          } else {
            await auth.signOut();
          }
        }
      }
    } catch (e) {
      Get.snackbar("Lỗi", "Không thể hủy luồng đăng ký: $e");
    } finally {
      _box.remove('isRegistering');
      enrollVerificationId = null;
      loginVerificationId = null;
      _mfaException = null;
      otpC.clear();
      passwordC.clear();
      confirmPasswordC.clear();
      fullPhoneNumber.value = '';
      resendEmailSeconds.value = 60;
      _emailTimer?.cancel();
      isLoadingRegister.value = false;
    }

    if (Get.currentRoute != redirectRoute) {
      Get.offAllNamed(redirectRoute);
    }
  }

  // =============================================================
  //               CHECK EMAIL VERIFIED (AFTER REGISTER)
  // =============================================================
  Future<void> checkEmailVerified() async {
    isLoadingRegister.value = true;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Get.snackbar("Lỗi", "Không tìm thấy người dùng");
        isLoadingRegister.value = false;
        return;
      }

      await user.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;

      if (refreshedUser != null && refreshedUser.emailVerified) {
        isLoadingRegister.value = false;
        Get.toNamed('/enroll-phone');
      } else {
        isLoadingRegister.value = false;
        Get.snackbar("Chưa xác minh", "Vui lòng kiểm tra email.");
      }
    } catch (e) {
      isLoadingRegister.value = false;
      Get.snackbar("Lỗi", e.toString());
    }
  }

  // =============================================================
  //                RESEND VERIFY EMAIL
  // =============================================================
  Future<void> resendVerifyEmail() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Get.snackbar("Lỗi", "Không tìm thấy user");
      return;
    }

    try {
      await user.sendEmailVerification();
      startEmailTimer();
      Get.snackbar("Thành công", "Đã gửi email xác minh");
    } catch (_) {}
  }

  void startEmailTimer() {
    resendEmailSeconds.value = 60;
    _emailTimer?.cancel();

    _emailTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (resendEmailSeconds.value == 0) {
        timer.cancel();
      } else {
        resendEmailSeconds.value--;
      }
    });
  }

  // =============================================================
  //                    SEND OTP (MFA ENROLL)
  // =============================================================
  Future<void> sendEnrollOtp() async {
    final phone = fullPhoneNumber.value.trim();

    if (!RegExp(r'^\+\d{9,15}$').hasMatch(phone)) {
      Get.snackbar("Lỗi", "Số điện thoại không hợp lệ");
      return;
    }
    // Kiểm tra số điện thoại được dùng tối đa 2 lần
    final phoneQuery =
        await _auth.db
            .collection('users')
            .where("phonenumber", isEqualTo: phone)
            .get();

    if (phoneQuery.docs.length >= 2) {
      Get.snackbar(
        "Lỗi",
        "Số điện thoại này đã được sử dụng cho tối đa 2 tài khoản",
      );
      return;
    }

    isLoadingRegister.value = true;

    await _auth.sendEnrollMfaOtp(
      phonenumber: phone,
      onCodeSent: (verId) {
        enrollVerificationId = verId;
        otpC.clear();
        startEnrollOtpTimer();
        isLoadingRegister.value = false;
        if (Get.currentRoute != '/otp-enroll') {
          Get.toNamed('/otp-enroll');
        }
      },
      onFailed: (msg) {
        isLoadingRegister.value = false;
        Get.snackbar("Lỗi OTP", msg);
      },
    );
  }

  void startEnrollOtpTimer() {
    resendEnrollOtpSeconds.value = 60;
    _enrollTimer?.cancel();

    _enrollTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (resendEnrollOtpSeconds.value == 0) {
        timer.cancel();
      } else {
        resendEnrollOtpSeconds.value--;
      }
    });
  }

  // =============================================================
  //             CONFIRM ENROLL OTP → LOGOUT (FLOW OF YOU)
  // =============================================================
  Future<void> confirmEnrollOtp() async {
    if (enrollVerificationId == null || otpC.text.isEmpty) {
      Get.snackbar("Lỗi", "Thiếu mã OTP");
      return;
    }

    isLoadingRegister.value = true;

    try {
      await _auth.confirmRegisterOtp(
        verificationId: enrollVerificationId!,
        smsCode: otpC.text.trim(),
      );

      await logoutC();
      _box.remove('isRegistering');

      Get.snackbar(
        "🎉 Đăng ký thành công",
        "Vui lòng đăng nhập để tiếp tục",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green.withValues(alpha: 0.9),
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      Get.offAllNamed('/');
    } on FirebaseAuthException catch (e) {
      Get.snackbar("Lỗi OTP", firebaseErrorToVietnamese(e.code));
    } catch (e) {
      Get.snackbar("Lỗi OTP", e.toString());
    } finally {
      isLoadingRegister.value = false;
    }
  }

  // =============================================================
  //                       LOGIN
  // =============================================================
  Future<void> loginC() async {
    _box.remove('isRegistering');

    if (emailC.text.isEmpty || passwordC.text.isEmpty) {
      Get.snackbar("Lỗi", "Nhập email và mật khẩu");
      return;
    }

    isLoadingLogin.value = true;

    await _auth.login(
      email: emailC.text.trim(),
      password: passwordC.text.trim(),
      onSuccess: () {
        isLoadingLogin.value = false;
      },
      onMfaRequired: (e) {
        isLoadingLogin.value = false;
        _mfaException = e;
        sendLoginOtp();
      },
      onFailed: (msg) {
        isLoadingLogin.value = false;
        Get.snackbar("Đăng nhập thất bại", msg);
      },
    );
  }

  // =============================================================
  //               SEND LOGIN OTP (MFA LOGIN)
  // =============================================================
  Future<void> sendLoginOtp() async {
    if (_mfaException == null) {
      Get.snackbar("Lỗi", "Không tìm thấy phiên MFA");
      return;
    }

    PhoneMultiFactorInfo? phoneHint;
    for (final hint in _mfaException!.resolver.hints) {
      if (hint is PhoneMultiFactorInfo) {
        phoneHint = hint;
        break;
      }
    }
    final hintPhone = phoneHint?.phoneNumber.trim();
    if (hintPhone != null && hintPhone.isNotEmpty) {
      fullPhoneNumber.value = hintPhone;
    }

    await _auth.resolveMfaLogin(
      e: _mfaException!,
      onCodeSent: (verId) {
        loginVerificationId = verId;
        otpC.clear();
        startLoginOtpTimer();
        if (Get.currentRoute != '/otp-login') {
          Get.toNamed('/otp-login');
        }
      },
      onFailed: (msg) {
        Get.snackbar("Lỗi OTP", msg);
      },
    );
  }

  void startLoginOtpTimer() {
    resendLoginOtpSeconds.value = 60;
    _loginTimer?.cancel();

    _loginTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (resendLoginOtpSeconds.value == 0) {
        timer.cancel();
      } else {
        resendLoginOtpSeconds.value--;
      }
    });
  }

  // =============================================================
  //               CONFIRM LOGIN OTP
  // =============================================================
  Future<void> confirmLogOtp() async {
    if (_mfaException == null ||
        loginVerificationId == null ||
        otpC.text.isEmpty) {
      Get.snackbar("Lỗi", "Phiên OTP không hợp lệ");
      return;
    }

    isLoadingLogin.value = true;

    try {
      // ✅ CHỈ XÁC THỰC OTP
      await _auth.confirmLoginOtp(
        e: _mfaException!,
        verificationId: loginVerificationId!,
        smsCode: otpC.text.trim(),
      );

      // ❌ KHÔNG kiểm tra currentUser
      // ❌ KHÔNG Get.to / Get.off ở đây
      // ✅ AuthGateController sẽ tự xử lý authStateChanges
    } on FirebaseAuthException catch (e) {
      Get.snackbar("OTP sai", e.message ?? "Xác thực thất bại");
    } catch (e) {
      Get.snackbar("Lỗi", e.toString());
    } finally {
      isLoadingLogin.value = false;
    }
  }

  Future<void> pickTempAvatar(ImageSource source) async {
    if (isUploadingAvatar.value || isLoadingRegister.value) return;

    isUploadingAvatar.value = true;
    try {
      final picker = ImagePicker();

      final picked = await picker.pickImage(source: source, imageQuality: 100);
      if (picked == null) return;

      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressFormat: ImageCompressFormat.jpg,
        uiSettings: [
          AndroidUiSettings(toolbarTitle: 'Cắt ảnh', lockAspectRatio: true),
          IOSUiSettings(title: 'Cắt ảnh'),
        ],
      );

      if (cropped == null) return;

      tempAvatarFile.value = File(cropped.path);
    } finally {
      isUploadingAvatar.value = false;
    }
  }

  // =============================================================
  //                     SAVE PROFILE
  // =============================================================
  Future<void> saveProfile() async {
    if (isLoadingRegister.value) return;
    if (isUploadingAvatar.value) return;

    final fullname = ProfileInputValidator.normalizeFullname(fullnameC.text);
    final nickname = ProfileInputValidator.normalizeNickname(nicknameC.text);

    final fullnameError = ProfileInputValidator.validateFullname(fullname);
    if (fullnameError != null) {
      Get.snackbar("Lỗi", fullnameError);
      return;
    }

    final nicknameError = ProfileInputValidator.validateNickname(nickname);
    if (nicknameError != null) {
      Get.snackbar("Lỗi", nicknameError);
      return;
    }

    final isNicknameUnique = await _ensureNicknameUnique(nickname);
    if (!isNicknameUnique) {
      final message =
          isNicknameAvailable.value == false
              ? "Nickname đã được sử dụng"
              : "Không thể kiểm tra nickname. Vui lòng thử lại";
      Get.snackbar("Lỗi", message);
      return;
    }

    if (selectedGender.value.isEmpty) {
      Get.snackbar("Lỗi", "Vui lòng chọn giới tính");
      return;
    }
    if (selectedBirthday.value == null) {
      Get.snackbar("Lỗi", "Vui lòng chọn ngày sinh");
      return;
    }

    if (tempAvatarFile.value == null) {
      Get.snackbar(
        "Thiếu ảnh đại diện",
        "Vui lòng chọn ảnh đại diện để tiếp tục",
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    isLoadingRegister.value = true;

    try {
      String? avatarUrl;
      if (tempAvatarFile.value != null) {
        isUploadingAvatar.value = true;
        avatarUrl = await AvatarService.uploadAvatar(tempAvatarFile.value!);
      }
      await _auth.saveUserProfile(
        fullname: fullname,
        nickname: nickname,
        phonenumber: fullPhoneNumber.value.trim(),
        birthday: selectedBirthday.value!,
        gender: selectedGender.value,
        avatarUrl: avatarUrl,
      );

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await _auth.db.collection("users").doc(uid).update({
          "isProfileCompleted": true,
        });
      }

      final anonAvatarC = Get.find<AnonymousAvatarController>();
      await anonAvatarC.load();

      await IdentityKeyService.generateIfNotExists();

      Get.offAllNamed('/main');
    } catch (e) {
      Get.snackbar("Lỗi", e.toString());
    } finally {
      isLoadingRegister.value = false;
      isUploadingAvatar.value = false;
    }
  }

  // =============================================================
  //                        LOGOUT
  // =============================================================
  Future<void> logoutC() async {
    const splashRoute = '/';
    const signedOutRoute = '/welcome';
    AuthGateController? authGateC;

    if (Get.isRegistered<AuthGateController>()) {
      authGateC = Get.find<AuthGateController>();
      authGateC.beginLogout(redirectRoute: signedOutRoute);
    }

    if (Get.currentRoute != splashRoute) {
      Get.offAllNamed(splashRoute);
    }

    final loggedOut = await LogoutService.logout();
    if (!loggedOut && FirebaseAuth.instance.currentUser != null) {
      authGateC?.reset();
      if (Get.currentRoute != '/main') {
        Get.offAllNamed('/main');
      }
      Get.snackbar("Lỗi", "Đăng xuất thất bại. Vui lòng thử lại.");
    }
  }

  // =============================================================
  //                        DISPOSE
  // =============================================================
  @override
  void onClose() {
    emailC.dispose();
    passwordC.dispose();
    confirmPasswordC.dispose();
    otpC.dispose();
    fullnameC.dispose();
    nicknameC.dispose();
    birthdayC.dispose();

    _emailTimer?.cancel();
    _enrollTimer?.cancel();
    _loginTimer?.cancel();
    _nicknameDebounceWorker?.dispose();

    super.onClose();
  }
}
