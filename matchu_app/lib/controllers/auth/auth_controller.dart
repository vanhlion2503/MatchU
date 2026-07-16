import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:matchu_app/translations/localized_material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
import 'package:matchu_app/utils/interest_tags.dart';
import 'package:matchu_app/utils/profile_input_validator.dart';
import 'package:matchu_app/translations/auth_translations.dart';

enum DobField { day, month, year }

class RememberedLoginAccount {
  const RememberedLoginAccount({
    required this.email,
    required this.password,
    required this.savedAt,
    this.fullname = '',
    this.avatarUrl = '',
    this.phoneNumber = '',
  });

  final String email;
  final String password;
  final DateTime savedAt;
  final String fullname;
  final String avatarUrl;
  final String phoneNumber;

  String get normalizedEmail => email.trim().toLowerCase();

  String get displayName {
    final nameFromProfile = fullname.trim();
    if (nameFromProfile.isNotEmpty) return nameFromProfile;

    final name = email.split('@').first.trim();
    return name.isEmpty ? email : name;
  }

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    'savedAt': savedAt.toIso8601String(),
    'fullname': fullname,
    'avatarUrl': avatarUrl,
    'phoneNumber': phoneNumber,
  };

  factory RememberedLoginAccount.fromJson(Map<String, dynamic> json) {
    return RememberedLoginAccount(
      email: (json['email'] ?? '').toString(),
      password: (json['password'] ?? '').toString(),
      savedAt:
          DateTime.tryParse((json['savedAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      fullname: (json['fullname'] ?? '').toString(),
      avatarUrl: (json['avatarUrl'] ?? '').toString(),
      phoneNumber:
          (json['phoneNumber'] ?? json['phonenumber'] ?? '').toString(),
    );
  }
}

class AuthController extends GetxController {
  final AuthService _auth = AuthService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _legacyRememberedLoginAccountKey =
      'auth_remembered_login';
  static const String _rememberedLoginAccountsKey =
      'auth_remembered_login_accounts';
  static const String _loginPhoneCacheKey = 'auth_login_phone_cache';

  // ========= INPUT CONTROLLERS =========
  final emailC = TextEditingController();
  final passwordC = TextEditingController();
  final confirmPasswordC = TextEditingController();
  final otpC = TextEditingController();
  final fullnameC = TextEditingController();
  final nicknameC = TextEditingController();
  final birthdayC = TextEditingController();
  final interestC = TextEditingController();

  final RxString fullPhoneNumber = ''.obs;
  final Rx<DateTime?> selectedBirthday = Rx<DateTime?>(null);
  final RxString selectedGender = ''.obs;
  final _box = GetStorage();

  // ========= UI STATE =========
  final isPasswordHidden = true.obs;
  final isLoadingRegister = false.obs;
  final isLoadingLogin = false.obs;
  final rememberLoginAccount = false.obs;
  final rememberedLoginAccounts = <RememberedLoginAccount>[].obs;
  final isLoadingRememberedAccount = false.obs;

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
  final selectedInterests = <String>[].obs;
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

  Future<void> prepareLoginForm() async {
    emailC.clear();
    passwordC.clear();
    otpC.clear();
    birthdayC.clear();
    nicknameC.clear();
    fullnameC.clear();
    interestC.clear();
    selectedInterests.clear();
    fullPhoneNumber.value = '';
    loginVerificationId = null;
    _mfaException = null;
    await loadRememberedLoginAccount();
  }

  Future<void> loadRememberedLoginAccount() async {
    if (isLoadingRememberedAccount.value) return;

    isLoadingRememberedAccount.value = true;
    try {
      final accounts = await _loadRememberedLoginAccountsFromStorage();
      rememberedLoginAccounts.assignAll(accounts);
      rememberLoginAccount.value = accounts.isNotEmpty;
    } catch (_) {
      rememberedLoginAccounts.clear();
      rememberLoginAccount.value = false;
    } finally {
      isLoadingRememberedAccount.value = false;
    }
  }

  Future<List<RememberedLoginAccount>>
  _loadRememberedLoginAccountsFromStorage() async {
    final accounts = <RememberedLoginAccount>[];
    final raw = await _secureStorage.read(key: _rememberedLoginAccountsKey);

    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        await _clearAllRememberedLoginAccounts();
        return accounts;
      }

      for (final item in decoded) {
        if (item is! Map) continue;
        final account = RememberedLoginAccount.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (account.normalizedEmail.isNotEmpty && account.password.isNotEmpty) {
          _upsertRememberedAccount(accounts, account);
        }
      }

      accounts.sort((a, b) => b.savedAt.compareTo(a.savedAt));
      return accounts;
    }

    final legacyRaw = await _secureStorage.read(
      key: _legacyRememberedLoginAccountKey,
    );
    if (legacyRaw == null || legacyRaw.isEmpty) return accounts;

    try {
      final decoded = jsonDecode(legacyRaw);
      if (decoded is Map<String, dynamic>) {
        final account = RememberedLoginAccount.fromJson(decoded);
        if (account.normalizedEmail.isNotEmpty && account.password.isNotEmpty) {
          accounts.add(account);
          await _writeRememberedLoginAccounts(accounts);
        }
      }
    } finally {
      await _secureStorage.delete(key: _legacyRememberedLoginAccountKey);
    }

    return accounts;
  }

  Future<void> loginWithRememberedAccount(
    RememberedLoginAccount account,
  ) async {
    if (isLoadingLogin.value) return;

    var selectedAccount = account;
    if (selectedAccount.normalizedEmail.isEmpty ||
        selectedAccount.password.isEmpty) {
      await loadRememberedLoginAccount();
      selectedAccount =
          _findRememberedAccountByEmail(account.email) ?? selectedAccount;
    }

    if (selectedAccount.normalizedEmail.isEmpty ||
        selectedAccount.password.isEmpty) {
      _showAuthSnackbar("Lỗi", "Không tìm thấy tài khoản đã lưu");
      return;
    }

    emailC.text = selectedAccount.email;
    passwordC.text = selectedAccount.password;
    rememberLoginAccount.value = true;
    await loginC();
  }

  Future<void> _saveRememberedLoginAccount({
    required String email,
    required String password,
  }) async {
    final existingAccount = _findRememberedAccountByEmail(email);
    final fallbackAccount = RememberedLoginAccount(
      email: email.trim(),
      password: password,
      savedAt: DateTime.now(),
      fullname: existingAccount?.fullname ?? '',
      avatarUrl: existingAccount?.avatarUrl ?? '',
      phoneNumber: existingAccount?.phoneNumber ?? '',
    );

    await _saveRememberedLoginAccountToList(fallbackAccount);

    final profile = await _loadCurrentRememberedProfile();
    final account = RememberedLoginAccount(
      email: email.trim(),
      password: password,
      savedAt: DateTime.now(),
      fullname: profile.fullname,
      avatarUrl: profile.avatarUrl,
      phoneNumber: profile.phoneNumber,
    );

    await _saveRememberedLoginAccountToList(account);
    await _saveLoginPhoneCache(email: email, phoneNumber: profile.phoneNumber);
  }

  Future<void> _saveRememberedLoginAccountToList(
    RememberedLoginAccount account,
  ) async {
    final accounts = rememberedLoginAccounts.toList(growable: true);
    _upsertRememberedAccount(accounts, account);
    accounts.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    await _writeRememberedLoginAccounts(accounts);
    rememberedLoginAccounts.assignAll(accounts);
  }

  Future<void> _writeRememberedLoginAccounts(
    List<RememberedLoginAccount> accounts,
  ) async {
    await _secureStorage.write(
      key: _rememberedLoginAccountsKey,
      value: jsonEncode(accounts.map((account) => account.toJson()).toList()),
    );
  }

  void _upsertRememberedAccount(
    List<RememberedLoginAccount> accounts,
    RememberedLoginAccount account,
  ) {
    final normalizedEmail = account.normalizedEmail;
    if (normalizedEmail.isEmpty || account.password.isEmpty) return;

    accounts.removeWhere((item) => item.normalizedEmail == normalizedEmail);
    accounts.insert(0, account);
  }

  RememberedLoginAccount? _findRememberedAccountByEmail(String email) {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return null;

    for (final account in rememberedLoginAccounts) {
      if (account.normalizedEmail == normalizedEmail) return account;
    }
    return null;
  }

  Future<Map<String, String>> _loadLoginPhoneCache() async {
    final raw = await _secureStorage.read(key: _loginPhoneCacheKey);
    if (raw == null || raw.isEmpty) return {};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return {};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } catch (_) {
      return {};
    }
  }

  Future<String> _getCachedLoginPhone(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return '';

    final cache = await _loadLoginPhoneCache();
    return cache[normalizedEmail]?.trim() ?? '';
  }

  Future<void> _saveLoginPhoneCache({
    required String email,
    required String phoneNumber,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPhone = normalizePhoneNumber(phoneNumber);
    if (normalizedEmail.isEmpty ||
        !RegExp(r'^\+\d{9,15}$').hasMatch(normalizedPhone)) {
      return;
    }

    final cache = await _loadLoginPhoneCache();
    cache[normalizedEmail] = normalizedPhone;
    await _secureStorage.write(
      key: _loginPhoneCacheKey,
      value: jsonEncode(cache),
    );
  }

  Future<void> removeRememberedLoginAccount(
    RememberedLoginAccount account,
  ) async {
    await _removeRememberedLoginAccount(account.email);
    _showAuthSnackbar("Đã xóa", "Tài khoản này sẽ không còn được lưu");
  }

  Future<void> _removeRememberedLoginAccount(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return;

    final accounts = rememberedLoginAccounts
        .where((account) => account.normalizedEmail != normalizedEmail)
        .toList(growable: false);

    if (accounts.isEmpty) {
      await _clearAllRememberedLoginAccounts();
      return;
    }

    await _writeRememberedLoginAccounts(accounts);
    rememberedLoginAccounts.assignAll(accounts);
    rememberLoginAccount.value = true;
  }

  Future<void> _clearAllRememberedLoginAccounts() async {
    await _secureStorage.delete(key: _rememberedLoginAccountsKey);
    await _secureStorage.delete(key: _legacyRememberedLoginAccountKey);
    rememberedLoginAccounts.clear();
    rememberLoginAccount.value = false;
  }

  Future<({String fullname, String avatarUrl, String phoneNumber})>
  _loadCurrentRememberedProfile() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final uid = currentUser?.uid.trim() ?? '';
    if (uid.isEmpty) {
      return (fullname: '', avatarUrl: '', phoneNumber: '');
    }

    try {
      final snap = await _auth.db.collection('users').doc(uid).get();
      final data = snap.data();
      if (data == null) {
        return (
          fullname: currentUser?.displayName?.trim() ?? '',
          avatarUrl: currentUser?.photoURL?.trim() ?? '',
          phoneNumber: currentUser?.phoneNumber?.trim() ?? '',
        );
      }

      final fullname =
          (data['fullname'] ?? data['displayName'] ?? '').toString().trim();
      final avatarUrl =
          (data['avatarUrl'] ?? data['avatar'] ?? '').toString().trim();
      final phoneNumber =
          (data['phonenumber'] ?? currentUser?.phoneNumber ?? '')
              .toString()
              .trim();

      return (
        fullname: fullname,
        avatarUrl: avatarUrl,
        phoneNumber: phoneNumber,
      );
    } catch (_) {
      return (
        fullname: currentUser?.displayName?.trim() ?? '',
        avatarUrl: currentUser?.photoURL?.trim() ?? '',
        phoneNumber: currentUser?.phoneNumber?.trim() ?? '',
      );
    }
  }

  Future<void> _syncRememberedLoginAfterSuccess() async {
    final email = emailC.text.trim();
    final password = passwordC.text.trim();
    if (email.isEmpty || password.isEmpty) return;

    if (rememberLoginAccount.value) {
      await _saveRememberedLoginAccount(email: email, password: password);
    } else {
      await _removeRememberedLoginAccount(email);
    }
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

  void addInterest(String tag) {
    if (selectedInterests.length >= InterestTags.maxSelected) return;

    final resolved = InterestTags.resolve(tag);
    if (resolved == null) return;

    final exists = selectedInterests.any(
      (item) => InterestTags.fold(item) == InterestTags.fold(resolved),
    );
    if (!exists) {
      selectedInterests.add(resolved);
    }

    interestC.clear();
  }

  void removeInterest(String tag) {
    selectedInterests.removeWhere(
      (item) => InterestTags.fold(item) == InterestTags.fold(tag),
    );
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

  String normalizePhoneNumber(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'[\s()-]'), '');
    if (normalized.startsWith('+840')) {
      return '+84${normalized.substring(4)}';
    }
    return normalized;
  }

  // =============================================================
  //                      REGISTER ACCOUNT
  // =============================================================
  Future<void> register() async {
    if (isLoadingRegister.value) return;

    _box.remove('isRegistering');
    if (emailC.text.isEmpty || passwordC.text.isEmpty) {
      _showAuthSnackbar("Lỗi", "Vui lòng nhập đầy đủ thông tin");
      return;
    }

    if (passwordC.text.length < 6) {
      _showAuthSnackbar("Lỗi", "Mật khẩu phải từ 6 ký tự trở lên");
      return;
    }

    if (passwordC.text != confirmPasswordC.text) {
      _showAuthSnackbar("Lỗi", "Mật khẩu nhập lại không khớp");
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
          _showAuthSnackbar("Đăng ký thất bại", errorMsg);
        },
      );
    } on FirebaseAuthException catch (e) {
      isLoadingRegister.value = false;
      _box.remove('isRegistering');
      _showAuthSnackbar("Đăng ký thất bại", firebaseErrorToVietnamese(e.code));
    } catch (e) {
      isLoadingRegister.value = false;
      _box.remove('isRegistering');
      _showAuthSnackbar("Đăng ký thất bại", e.toString());
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
      _showAuthSnackbar("Lỗi", "Không thể hủy luồng đăng ký: $e");
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
    if (isLoadingRegister.value) return;

    isLoadingRegister.value = true;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showAuthSnackbar("Lỗi", "Không tìm thấy người dùng");
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
        _showAuthSnackbar("Chưa xác minh", "Vui lòng kiểm tra email.");
      }
    } catch (e) {
      isLoadingRegister.value = false;
      _showAuthSnackbar("Lỗi", e.toString());
    }
  }

  // =============================================================
  //                RESEND VERIFY EMAIL
  // =============================================================
  Future<void> resendVerifyEmail() async {
    if (resendEmailSeconds.value > 0) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showAuthSnackbar("Lỗi", "Không tìm thấy user");
      return;
    }

    try {
      await user.sendEmailVerification();
      startEmailTimer();
      _showAuthSnackbar("Thành công", "Đã gửi email xác minh");
    } catch (_) {}
  }

  void startEmailTimer() {
    resendEmailSeconds.value = 60;
    _emailTimer?.cancel();

    _emailTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
    if (isLoadingRegister.value) return;

    final phone = normalizePhoneNumber(fullPhoneNumber.value);

    if (!RegExp(r'^\+\d{9,15}$').hasMatch(phone)) {
      _showAuthSnackbar("Lỗi", "Số điện thoại không hợp lệ");
      return;
    }
    isLoadingRegister.value = true;

    try {
      final isUnique = await _auth.isPhoneNumberUnique(phone);

      if (!isUnique) {
        isLoadingRegister.value = false;
        _showAuthSnackbar("Lỗi", "Số điện thoại này đã được sử dụng");
        return;
      }

      fullPhoneNumber.value = phone;
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
          _showAuthSnackbar("Lỗi OTP", msg);
        },
      );
    } catch (_) {
      isLoadingRegister.value = false;
      _showAuthSnackbar("Lỗi", "Không thể gửi OTP. Vui lòng thử lại");
    }
  }

  void startEnrollOtpTimer() {
    resendEnrollOtpSeconds.value = 60;
    _enrollTimer?.cancel();

    _enrollTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
    if (isLoadingRegister.value) return;

    if (enrollVerificationId == null || otpC.text.isEmpty) {
      _showAuthSnackbar("Lỗi", "Thiếu mã OTP");
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

      _showAuthSnackbar(
        "🎉 Đăng ký thành công",
        "Vui lòng đăng nhập để tiếp tục",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green.withValues(alpha: 0.9),
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      Get.offAllNamed('/');
    } on FirebaseAuthException catch (e) {
      _showAuthSnackbar("Lỗi OTP", firebaseErrorToVietnamese(e.code));
    } catch (e) {
      _showAuthSnackbar("Lỗi OTP", e.toString());
    } finally {
      isLoadingRegister.value = false;
    }
  }

  Future<void> signInWithGoogle({bool fromRegister = false}) async {
    final loading = fromRegister ? isLoadingRegister : isLoadingLogin;
    if (loading.value) return;

    _box.remove('isRegistering');
    if (fromRegister) {
      _box.write('isRegistering', true);
    }
    loading.value = true;

    try {
      final credential = await _auth.signInWithGoogle();
      if (fromRegister) {
        final uid = credential.user?.uid;
        if (uid != null) {
          final snap = await _auth.db.collection('users').doc(uid).get();
          if (snap.data()?['isProfileCompleted'] == true) {
            _box.remove('isRegistering');
            await FirebaseAuth.instance.signOut();
            _showAuthSnackbar(
              "T\u00e0i kho\u1ea3n \u0111\u00e3 t\u1ed3n t\u1ea1i",
              "Vui l\u00f2ng \u0111\u0103ng nh\u1eadp b\u1eb1ng Google \u0111\u1ec3 ti\u1ebfp t\u1ee5c",
            );
          }
        }
      } else {
        await _auth.markGoogleProvider(credential);
        await _auth.setOnlineStatus(true);
      }
    } on FirebaseAuthMultiFactorException catch (e) {
      _box.remove('isRegistering');
      if (fromRegister) {
        _showAuthSnackbar(
          "T\u00e0i kho\u1ea3n \u0111\u00e3 t\u1ed3n t\u1ea1i",
          "Vui l\u00f2ng \u0111\u0103ng nh\u1eadp b\u1eb1ng Google \u0111\u1ec3 x\u00e1c minh OTP",
        );
      } else {
        _mfaException = e;
        sendLoginOtp();
      }
    } on FirebaseAuthException catch (e) {
      _box.remove('isRegistering');
      _showAuthSnackbar(
        "\u0110\u0103ng nh\u1eadp Google th\u1ea5t b\u1ea1i",
        firebaseErrorToVietnamese(e.code),
      );
    } catch (e) {
      _box.remove('isRegistering');
      final message = e.toString();
      if (!message.toLowerCase().contains('canceled')) {
        _showAuthSnackbar(
          "\u0110\u0103ng nh\u1eadp Google th\u1ea5t b\u1ea1i",
          message,
        );
      }
    } finally {
      loading.value = false;
    }
  }

  //                       LOGIN
  // =============================================================
  Future<void> loginC() async {
    if (isLoadingLogin.value) return;

    _box.remove('isRegistering');

    if (emailC.text.isEmpty || passwordC.text.isEmpty) {
      _showAuthSnackbar("Lỗi", "Nhập email và mật khẩu");
      return;
    }

    isLoadingLogin.value = true;
    loginVerificationId = null;
    otpC.clear();

    await _auth.login(
      email: emailC.text.trim(),
      password: passwordC.text.trim(),
      onSuccess: () {
        unawaited(_syncRememberedLoginAfterSuccess());
        isLoadingLogin.value = false;
      },
      onMfaRequired: (e) {
        _mfaException = e;
        sendLoginOtp();
      },
      onFailed: (msg) {
        isLoadingLogin.value = false;
        _showAuthSnackbar("Đăng nhập thất bại", msg);
      },
    );
  }

  // =============================================================
  //               SEND LOGIN OTP (MFA LOGIN)
  // =============================================================
  Future<void> sendLoginOtp() async {
    if (isLoadingLogin.value && loginVerificationId != null) return;

    if (_mfaException == null) {
      _showAuthSnackbar("Lỗi", "Không tìm thấy phiên MFA");
      return;
    }

    isLoadingLogin.value = true;

    PhoneMultiFactorInfo? phoneHint;
    for (final hint in _mfaException!.resolver.hints) {
      if (hint is PhoneMultiFactorInfo) {
        phoneHint = hint;
        break;
      }
    }
    final savedPhone =
        _findRememberedAccountByEmail(emailC.text)?.phoneNumber.trim() ?? '';
    final cachedPhone = await _getCachedLoginPhone(emailC.text);
    final hintPhone = phoneHint?.phoneNumber.trim() ?? '';
    if (savedPhone.isNotEmpty &&
        !savedPhone.contains('*') &&
        RegExp(r'^\+\d{9,15}$').hasMatch(savedPhone)) {
      fullPhoneNumber.value = savedPhone;
    } else if (cachedPhone.isNotEmpty &&
        !cachedPhone.contains('*') &&
        RegExp(r'^\+\d{9,15}$').hasMatch(cachedPhone)) {
      fullPhoneNumber.value = cachedPhone;
    } else if (hintPhone.isNotEmpty) {
      fullPhoneNumber.value = hintPhone;
    }

    await _auth.resolveMfaLogin(
      e: _mfaException!,
      onCodeSent: (verId) {
        loginVerificationId = verId;
        otpC.clear();
        startLoginOtpTimer();
        isLoadingLogin.value = false;
        if (Get.currentRoute != '/otp-login') {
          Get.toNamed('/otp-login');
        }
      },
      onFailed: (msg) {
        isLoadingLogin.value = false;
        _showAuthSnackbar("Lỗi OTP", msg);
      },
    );
  }

  void startLoginOtpTimer() {
    resendLoginOtpSeconds.value = 60;
    _loginTimer?.cancel();

    _loginTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
    if (isLoadingLogin.value) return;

    if (_mfaException == null ||
        loginVerificationId == null ||
        otpC.text.isEmpty) {
      _showAuthSnackbar("Lỗi", "Phiên OTP không hợp lệ");
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
      await _syncRememberedLoginAfterSuccess();

      // ❌ KHÔNG kiểm tra currentUser
      // ❌ KHÔNG Get.to / Get.off ở đây
      // ✅ AuthGateController sẽ tự xử lý authStateChanges
    } on FirebaseAuthException catch (e) {
      _showAuthSnackbar("OTP sai", firebaseErrorToVietnamese(e.code));
    } catch (e) {
      _showAuthSnackbar("Lỗi", e.toString());
    } finally {
      isLoadingLogin.value = false;
    }
  }

  Future<void> pickTempAvatar(ImageSource source) async {
    if (isUploadingAvatar.value || isLoadingRegister.value) return;

    try {
      final picker = ImagePicker();

      final picked = await picker.pickImage(source: source, imageQuality: 100);
      if (picked == null) return;

      await pickTempAvatarFile(File(picked.path));
    } catch (error) {
      _showAuthSnackbar("Lỗi", error.toString());
    }
  }

  Future<void> pickTempAvatarFile(File file) async {
    if (isUploadingAvatar.value || isLoadingRegister.value) return;

    isUploadingAvatar.value = true;
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: file.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressFormat: ImageCompressFormat.jpg,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: authTr('Cắt ảnh'),
            lockAspectRatio: true,
          ),
          IOSUiSettings(title: authTr('Cắt ảnh')),
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
      _showAuthSnackbar("Lỗi", fullnameError);
      return;
    }

    final nicknameError = ProfileInputValidator.validateNickname(nickname);
    if (nicknameError != null) {
      _showAuthSnackbar("Lỗi", nicknameError);
      return;
    }

    final isNicknameUnique = await _ensureNicknameUnique(nickname);
    if (!isNicknameUnique) {
      final message =
          isNicknameAvailable.value == false
              ? "Nickname đã được sử dụng"
              : "Không thể kiểm tra nickname. Vui lòng thử lại";
      _showAuthSnackbar("Lỗi", message);
      return;
    }

    if (selectedGender.value.isEmpty) {
      _showAuthSnackbar("Lỗi", "Vui lòng chọn giới tính");
      return;
    }
    if (selectedBirthday.value == null) {
      _showAuthSnackbar("Lỗi", "Vui lòng chọn ngày sinh");
      return;
    }

    final normalizedPhone = normalizePhoneNumber(fullPhoneNumber.value);
    if (normalizedPhone.isNotEmpty) {
      final isPhoneUnique = await _auth.isPhoneNumberUnique(normalizedPhone);
      if (!isPhoneUnique) {
        _showAuthSnackbar("Lỗi", "Số điện thoại này đã được sử dụng");
        return;
      }
      fullPhoneNumber.value = normalizedPhone;
    }

    if (tempAvatarFile.value == null) {
      _showAuthSnackbar(
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
        interests: InterestTags.normalizeList(selectedInterests),
        avatarUrl: avatarUrl,
      );
      await _saveLoginPhoneCache(
        email: FirebaseAuth.instance.currentUser?.email ?? emailC.text,
        phoneNumber: fullPhoneNumber.value,
      );

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await _auth.db.collection("users").doc(uid).update({
          "isProfileCompleted": true,
        });
      }

      final anonAvatarC = Get.find<AnonymousAvatarController>();
      await anonAvatarC.load();

      try {
        await IdentityKeyService.generateIfNotExists();
      } catch (e, st) {
        debugPrint('Identity key setup skipped after profile save: $e');
        debugPrintStack(stackTrace: st);
      }

      Get.offAllNamed('/main');
    } catch (e) {
      _showAuthSnackbar("Lỗi", e.toString());
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
      _showAuthSnackbar("Lỗi", "Đăng xuất thất bại. Vui lòng thử lại.");
    }
  }

  void _showAuthSnackbar(
    String title,
    String message, {
    SnackPosition? snackPosition,
    Color? backgroundColor,
    Color? colorText,
    Duration? duration,
    EdgeInsets? margin,
  }) {
    Get.snackbar(
      authTr(title),
      authTr(message),
      snackPosition: snackPosition,
      backgroundColor: backgroundColor,
      colorText: colorText,
      duration: duration,
      margin: margin,
    );
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
    interestC.dispose();

    _emailTimer?.cancel();
    _enrollTimer?.cancel();
    _loginTimer?.cancel();
    _nicknameDebounceWorker?.dispose();

    super.onClose();
  }
}
