import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
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


  Timer? _emailTimer;
  Timer? _enrollTimer;
  Timer? _loginTimer;

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
  }

  void updateBirthdayIfReady() {
    if (selectedDay.value == null ||
        selectedMonth.value == null ||
        selectedYear.value == null) return;

    final y = selectedYear.value!;
    final m = selectedMonth.value!;
    final d = selectedDay.value!;

    // 🔒 Validate số ngày trong tháng
    final lastDayOfMonth = DateTime(y, m + 1, 0).day;
    if (d > lastDayOfMonth) {
      selectedDay.value = lastDayOfMonth;
    }

    final date = DateTime(
      y,
      m,
      selectedDay.value!,
    );

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

  // =============================================================
  //                      REGISTER ACCOUNT
  // =============================================================
  Future<void> register() async {
    _box.write('isRegistering', true); 
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
          Get.snackbar("Đăng ký thất bại", errorMsg);
        },
      );
    } on FirebaseAuthException catch (e) {
      isLoadingRegister.value = false;
      Get.snackbar("Đăng ký thất bại", firebaseErrorToVietnamese(e.code));
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

      if (refreshedUser!.emailVerified) {
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
    final phoneQuery = await _auth.db
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
        startEnrollOtpTimer();
        isLoadingRegister.value = false;
        Get.toNamed('/otp-enroll');
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

      isLoadingRegister.value = false;

      await logoutC();
      _box.remove('isRegistering');
      Get.offAllNamed('/');

    } on FirebaseAuthException catch (e) {
      isLoadingRegister.value = false;
      Get.snackbar("Lỗi OTP", firebaseErrorToVietnamese(e.code));
    }
  }

  // =============================================================
  //                       LOGIN
  // =============================================================
  Future<void> loginC() async {
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

    await _auth.resolveMfaLogin(
      e: _mfaException!,
      onCodeSent: (verId) {
        loginVerificationId = verId;
        startLoginOtpTimer();
        Get.toNamed('/otp-login');
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
      if (resendLoginOtpSeconds.value == 0)
        timer.cancel();
      else
        resendLoginOtpSeconds.value--;
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
    final picker = ImagePicker();

    final picked = await picker.pickImage(
      source: source,
      imageQuality: 100,
    );
    if (picked == null) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.jpg,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Cắt ảnh',
          lockAspectRatio: true,
        ),
        IOSUiSettings(title: 'Cắt ảnh'),
      ],
    );

    if (cropped == null) return;

    tempAvatarFile.value = File(cropped.path);
  }


  // =============================================================
  //                     SAVE PROFILE
  // =============================================================
  Future<void> saveProfile() async {
    final nickname = nicknameC.text.trim();

    if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(nickname)) {
      Get.snackbar("Lỗi",
          "Nickname chỉ gồm chữ không dấu, số, hoặc dấu gạch dưới (_)");
      return;
    }
    if (fullnameC.text.isEmpty) {
      Get.snackbar("Lỗi", "Vui lòng nhập họ tên");
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
        avatarUrl = await AvatarService.uploadAvatar(
          tempAvatarFile.value!,
        );
      }
      await _auth.saveUserProfile(
        fullname: fullnameC.text.trim(),
        nickname: nickname,
        phonenumber: fullPhoneNumber.value.trim(),
        birthday: selectedBirthday.value!,
        gender: selectedGender.value,
        avatarUrl: avatarUrl,
      );

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await _auth.db
            .collection("users")
            .doc(uid)
            .update({"isProfileCompleted": true});
      }

      isLoadingRegister.value = false;

      final anonAvatarC = Get.find<AnonymousAvatarController>();
      await anonAvatarC.load();

      await IdentityKeyService.generateIfNotExists();
      
      Get.offAllNamed('/main');
    } catch (e) {
      isLoadingRegister.value = false;
      Get.snackbar("Lỗi", e.toString());
    }
  }

  // =============================================================
  //                        LOGOUT
  // =============================================================
  Future<void> logoutC() async {
    if (Get.isRegistered<AuthGateController>()) {
      Get.find<AuthGateController>().reset();
    }

    await LogoutService.logout();
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

    super.onClose();
  }
}
