import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/services/auth_service.dart';
import 'package:matchu_app/translates/firebase_error_translator.dart';

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

  // ========= UI STATE =========
  final isPasswordHidden = true.obs;
  final isLoadingRegister = false.obs;
  final isLoadingLogin = false.obs;

  final resendEmailSeconds = 60.obs;
  final resendEnrollOtpSeconds = 60.obs;
  final resendLoginOtpSeconds = 60.obs;

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

    // checkInitialLogin();
  }

  Future<void> checkInitialLogin() async {
    final u = FirebaseAuth.instance.currentUser;

    if (u == null) {
      Get.offAllNamed('/welcome');
      return;
    }

    try {
      final snap = await _auth.db.collection('users').doc(u.uid).get();

      final completed = snap.exists && (snap.data()?['isProfileCompleted'] ?? false);

      if (completed) {
        Get.offAllNamed('/main');
      } else {
        Get.offAllNamed('/complete-profile');
      }
    } catch (e) {
      Get.offAllNamed('/welcome');
    }
  }


  // =============================================================
  //                      REGISTER ACCOUNT
  // =============================================================
  Future<void> register() async {
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

    // Kiểm tra sdt có bị trùng không
    final phoneQuery = await _auth.db
        .collection('users')
        .where("phonenumber", isEqualTo: phone)
        .get();

    if (phoneQuery.docs.isNotEmpty) {
      Get.snackbar("Lỗi", "Số điện thoại đã có người sử dụng");
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
      // Xác thực MFA OTP
      await _auth.confirmLoginOtp(
        e: _mfaException!,
        verificationId: loginVerificationId!,
        smsCode: otpC.text.trim(),
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Get.snackbar("Lỗi", "Đăng nhập thất bại");
        return;
      }

      // Kiểm tra hồ sơ
      final snap =
          await _auth.db.collection('users').doc(user.uid).get();

      final completed =
          snap.exists && (snap.data()?['isProfileCompleted'] ?? false);

      if (completed) {
        Get.offAllNamed('/main');
      } else {
        Get.toNamed('/complete-profile');
      }
    } catch (e) {
      Get.snackbar("OTP sai", e.toString());
    } finally {
      isLoadingLogin.value = false;
    }
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

    isLoadingRegister.value = true;

    try {
      await _auth.saveUserProfile(
        fullname: fullnameC.text.trim(),
        nickname: nickname,
        phonenumber: fullPhoneNumber.value.trim(),
        birthday: selectedBirthday.value!,
        gender: selectedGender.value,
      );

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await _auth.db
            .collection("users")
            .doc(uid)
            .update({"isProfileCompleted": true});
      }

      isLoadingRegister.value = false;

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
    await _auth.logout();
    Get.offAllNamed('/');
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
