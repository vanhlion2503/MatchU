import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:matchu_app/services/auth_service.dart';

class AuthController extends GetxController{

  final AuthService _authService = AuthService();
  
  final emailC = TextEditingController();
  final passwordC = TextEditingController();
  final confirmPasswordC = TextEditingController();
  final phoneC = TextEditingController();
  final fullnameC = TextEditingController();
  final nicknameC = TextEditingController();
  final otpC = TextEditingController();

  final Rx<DateTime?> selectedBirthday = Rx<DateTime?>(null);
  final RxString selectedGender = ''.obs;

  final isPasswordHidden = true.obs;
  final isLoadingRegister = false.obs;
  final isLoadingLogin = false.obs;

  final Rxn<User> _user = Rxn<User>(); 
  User? get user => _user.value;
  bool get isAuthenticated => _user.value != null;

  String? registerVerificationId;
  FirebaseAuthMultiFactorException? _mfaException;
  String? loginVerificationId;

  @override
  void onInit() {
    super.onInit();
    _user.bindStream(_authService.authStateChanges);
    ever<User?>(_user, _handleAuthChanged);
  }
  Future<void> _handleAuthChanged(User? user) async{
    if (user == null){
      Get.offAllNamed('/');
    }

    final snap = await _authService.db.collection('users').doc('uid').get();

    final isProfileCompleted = snap.exists && (snap.data()?['isProfileCompleted'] ?? false);

    if (isProfileCompleted) {
      Get.offAllNamed('/home');
    }else{
      Get.offAllNamed('/complete-profile');
    }
  }
  Future<void> register() async{
    if(emailC.text.isEmpty || passwordC.text.isEmpty || phoneC.text.isEmpty){
      Get.snackbar('Lỗi', 'Vui lòng nhập đầy đủ thông tin yêu cầu');
      return;
    }
    if (passwordC.text.trim() != confirmPasswordC.text.trim()) {
      Get.snackbar("Lỗi", "Mật khẩu nhập lại không khớp");
      return;
    }

    if (passwordC.text.trim().length < 6) {
      Get.snackbar("Lỗi", "Mật khẩu phải ít nhất 6 ký tự");
      return;
    }

    isLoadingRegister.value = true;
    await _authService.registerWithEmailAndPassWord(
      email: emailC.text.trim(), 
      password: passwordC.text.trim(), 
      phonenumber: phoneC.text.trim(), 
      onCodeSent: (verificationId){
        registerVerificationId = verificationId;
        isLoadingRegister.value = true;
        Get.toNamed('/otp-register');
      }, 
      onFailed: (error){
        isLoadingRegister.value = false;
        Get.snackbar('Lỗi', 'Đăng ký thất bại');
      }
    );
  }
  Future<void> confirmRegisOtp() async{
    if (otpC.text.isEmpty || registerVerificationId == null){
      Get.snackbar('Lỗi', 'OTP không hợp lệ');
      return;
    }
    isLoadingRegister.value = true;
    try{
      await _authService.confirmRegisterOtp(
        verificationId: registerVerificationId!, 
        smsCode: otpC.text.trim(),
        );
      isLoadingRegister.value = false;
      Get.offAllNamed('/complete-profile');
    }catch(e){
      isLoadingRegister.value = false;
      Get.snackbar('OTP sai', e.toString());
    }
  }
  Future<void> saveProfile() async {
    if(fullnameC.text.isEmpty || nicknameC.text.isEmpty || phoneC.text.isEmpty || selectedBirthday.value == null || selectedGender.value.isEmpty){
      Get.snackbar('Lỗi', 'Bạn hãy nhập đầy đủ thông tin');
      return;
    }
    isLoadingRegister.value = true;
    try{
      await _authService.saveUserProfile(
        fullname: fullnameC.text.trim(), 
        nickname: nicknameC.text.trim(), 
        phonenumber: phoneC.text.trim(),
        birthday: selectedBirthday.value,
        gender: selectedGender.value,
      );
      final user = _authService.auth.currentUser;
      if(user != null){
        await _authService.db.collection('users').doc(user.uid).update({'isProfileCompleted': true});
      }

      isLoadingRegister.value = false;  
    }catch(e){
      isLoadingRegister.value = false;
      Get.snackbar('Không thể cập nhật được thông tin', e.toString());
    }
  }
   Future<void> loginC() async {
    if (emailC.text.isEmpty || passwordC.text.isEmpty) {
      Get.snackbar("Lỗi", "Vui lòng nhập email và mật khẩu");
      return;
    }

    isLoadingLogin.value = true;

    await _authService.login(
      email: emailC.text.trim(),
      password: passwordC.text.trim(),
      onSuccess: () {
        isLoadingLogin.value = true;
      },
      onMfaRequired: (FirebaseAuthMultiFactorException e) {
        isLoadingLogin.value = true;
        _mfaException = e;
        _sendMfaLoginCode();
      },
      onFailed: (error) {
        isLoadingLogin.value = true;
        Get.snackbar("Đăng nhập thất bại", error);
      },
    );
  }

  
  Future<void> _sendMfaLoginCode() async {
    final e = _mfaException;
    if (e == null) {
      Get.snackbar("Lỗi", "Không tìm thấy phiên MFA");
      return;
    }

    isLoadingLogin.value = true;

    await _authService.resolveMfaLogin(
      e: e,
      onCodeSent: (verificationId) {
        loginVerificationId = verificationId;
        isLoadingLogin.value = true;
        Get.toNamed('/otp-login');
      },
      onFailed: (error) {
        isLoadingLogin.value = true;
        Get.snackbar("Lỗi OTP", error);
      },
    );
  }

  Future<void> confirmLogOtp()async{
    if(_mfaException == null || otpC.text.isEmpty || loginVerificationId == null){
      Get.snackbar("Lỗi", "Phiên OTP không hợp lệ");
    }
    isLoadingLogin.value = true;
    try{
      await _authService.confirmLoginOtp(
      e: _mfaException!, 
      verificationId: loginVerificationId!, 
      smsCode: otpC.text.trim(),
      );
      isLoadingLogin.value = false;
    }catch(e){
      isLoadingLogin.value = false;
      Get.snackbar("OTP sai", e.toString());
    }
  }

  Future<void> logoutC() async{
    await _authService.logout();
  }

  @override
  void onClose(){
    emailC.dispose();
    passwordC.dispose();
    confirmPasswordC.dispose();
    phoneC.dispose();
    otpC.dispose();
    fullnameC.dispose();
    nicknameC.dispose();
    super.onClose();
  }
}