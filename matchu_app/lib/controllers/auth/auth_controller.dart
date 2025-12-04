import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:matchu_app/services/auth_service.dart';

class AuthController extends GetxController {
  final AuthService _authService = AuthService();

  final emailC = TextEditingController();
  final passwordC = TextEditingController();
  final confirmPasswordC = TextEditingController();
  final otpC = TextEditingController();
  final fullnameC = TextEditingController();
  final nicknameC = TextEditingController();
  

  final RxString fullPhoneNumber = ''.obs;
  final Rx<DateTime?> selectedBirthday = Rx<DateTime?>(null);
  final RxString selectedGender = ''.obs;

  final isPasswordHidden = true.obs;
  final isLoadingRegister = false.obs;
  final isLoadingLogin = false.obs;

  final Rxn<User> _user = Rxn<User>();
  User? get user => _user.value;

  FirebaseAuthMultiFactorException? _mfaException;
  String? loginVerificationId;
  String? enrollVerificationId;
  bool _isRegistering = false;

  @override
  void onInit() {
    super.onInit();
    _user.bindStream(_authService.authStateChanges);
  }

  /// ✅ REGISTER — GỬI EMAIL VERIFY ĐÚNG LUỒNG
  Future<void> register() async {
    final phone = fullPhoneNumber.value.trim();

    if (!RegExp(r'^\+\d{9,15}$').hasMatch(phone)) {
      Get.snackbar("Lỗi", "Số điện thoại không hợp lệ");
      return;
    }

    if (emailC.text.isEmpty || passwordC.text.isEmpty) {
      Get.snackbar("Lỗi", "Vui lòng nhập đầy đủ thông tin");
      return;
    }

    if (passwordC.text != confirmPasswordC.text) {
      Get.snackbar("Lỗi", "Mật khẩu nhập lại không khớp");
      return;
    }

    _isRegistering = true;
    isLoadingRegister.value = true;

    try {
      await _authService.registerWithEmailAndPassWord(
        email: emailC.text.trim(),
        password: passwordC.text.trim(),
        phonenumber: phone,
        onSuccess: () {
          isLoadingRegister.value = false;
          Get.toNamed('/verify-email');
        },
        onFailed: (error){
          isLoadingRegister.value = false;
          Get.snackbar("Đăng ký thất bại", error);
        },
      );
    } catch (e) {
      isLoadingRegister.value = false;
      Get.snackbar("Đăng ký thất bại", e.toString());
      _isRegistering = false;
    }
  }
  Future<void> checkEmailVeriFied() async{
    final user = FirebaseAuth.instance.currentUser;
    await user?.reload();

    if(user!.emailVerified){
      Get.toNamed('/enroll-phone');
    }else{
      Get.snackbar("Chưa xác minh", "Vui lòng kiểm tra email của bạn");
    }
  }
  Future<void> sendEnrollOtp() async{
    final phone = fullPhoneNumber.value.trim();
    if(!phone.startsWith("+")){
      Get.snackbar('Lỗi', 'Số điện thoại không hợp lệ');
      return;
    }
    isLoadingRegister.value = true;
    await _authService.sendEnrollMfaOtp(
      phonenumber: phone, 
      onCodeSent: (verificationId) {
        enrollVerificationId = verificationId;
        isLoadingRegister.value = false;
        Get.toNamed('/otp-enroll');
      },
      onFailed: (e){
        isLoadingRegister.value = false;
        Get.snackbar("Lỗi", e);
      });
  }
  Future<void> confirmEnrollOtp() async {
    if (enrollVerificationId == null || otpC.text.isEmpty){
      Get.snackbar("Lỗi", "Thiếu mã OTP");
      return;
    } 

    isLoadingRegister.value = true;

    try {
      await _authService.confirmRegisterOtp(
        verificationId: enrollVerificationId!,
        smsCode: otpC.text.trim(),
      );

      isLoadingRegister.value = false;
      await logoutC();
      Get.offAllNamed('/');
    } catch (e) {
      isLoadingRegister.value = false;
      Get.snackbar("OTP sai", e.toString());
    }
  }
  /// ✅ LOGIN
  Future<void> loginC() async {
    if (emailC.text.isEmpty || passwordC.text.isEmpty) {
      Get.snackbar("Lỗi", "Vui lòng nhập email và mật khẩu");
      return;
    }

    isLoadingLogin.value = true;

    await _authService.login(
      email: emailC.text.trim(), 
      password: passwordC.text.trim(), 
      onSuccess: () async{
        isLoadingLogin.value = false;
      }, 
      onMfaRequired: (e){
        _mfaException = e;
        isLoadingLogin.value = false;
        _sendMfaLoginCode();
      }, 
      onFailed: (e){
        isLoadingLogin.value = false;
      });
  }

  /// ✅ GỬI OTP MFA
  Future<void> _sendMfaLoginCode() async {
    if (_mfaException == null) {
      Get.snackbar("Lỗi", "Không tìm thấy phiên MFA");
      return;
    }
    await _authService.resolveMfaLogin(
      e: _mfaException!,
      onCodeSent: (verificationId) {
        loginVerificationId = verificationId;
        isLoadingLogin.value = false;
        Get.toNamed('/otp-login');
      },
      onFailed: (error) {
        isLoadingLogin.value = false;
        Get.snackbar("Lỗi OTP", error);
      },
    );
  }

  /// ✅ XÁC NHẬN OTP MFA LOGIN
  Future<void> confirmLogOtp() async {
    if (_mfaException == null ||
        otpC.text.isEmpty ||
        loginVerificationId == null) {
      Get.snackbar("Lỗi", "Phiên OTP không hợp lệ");
      return;
    }

    isLoadingLogin.value = true;

    try {
      // 1. Xác thực OTP
      await _authService.confirmLoginOtp(
        e: _mfaException!,
        verificationId: loginVerificationId!,
        smsCode: otpC.text.trim(),
      );

      // 2. Lấy user hiện tại
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Get.snackbar("Lỗi", "Đăng nhập thất bại");
        return;
      }

      // 3. Kiểm tra hồ sơ
      final snap = await _authService.db
          .collection('users')
          .doc(user.uid)
          .get();

      final isProfileCompleted =
          snap.exists && (snap.data()?['isProfileCompleted'] ?? false);

      // 4. Điều hướng
      if (isProfileCompleted) {
        Get.offAllNamed('/home');
      } else {
        Get.toNamed('/complete-profile');
      }
    } catch (e) {
      Get.snackbar("OTP sai", e.toString());
    } finally {
      isLoadingLogin.value = false;
    }
  }


  /// ✅ LƯU PROFILE
  Future<void> saveProfile() async {
    if (fullnameC.text.isEmpty || nicknameC.text.isEmpty) {
      Get.snackbar("Lỗi", "Vui lòng nhập đầy đủ thông tin");
      return;
    }

    isLoadingRegister.value = true;

    try {
      await _authService.saveUserProfile(
        fullname: fullnameC.text.trim(),
        nickname: nicknameC.text.trim(),
        phonenumber: fullPhoneNumber.value.trim(),
        birthday: selectedBirthday.value,
        gender: selectedGender.value,
      );

      final user = _authService.auth.currentUser;
      if (user != null) {
        await _authService.db
            .collection('users')
            .doc(user.uid)
            .update({'isProfileCompleted': true});
      }

      isLoadingRegister.value = false;
      Get.offAllNamed('/home');
    } catch (e) {
      isLoadingRegister.value = false;
      Get.snackbar("Lỗi", e.toString());
    }
  }

  Future<void> logoutC() async {
    await _authService.logout();
    Get.offAllNamed('/');
  }

  @override
  void onClose() {
    emailC.dispose();
    passwordC.dispose();
    confirmPasswordC.dispose();
    otpC.dispose();
    fullnameC.dispose();
    nicknameC.dispose();
    super.onClose();
  }
}
