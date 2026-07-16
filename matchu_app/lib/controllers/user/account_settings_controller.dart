import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:matchu_app/translations/localized_material.dart';
import 'package:get/get.dart';
import 'package:matchu_app/models/profile_snap_shot.dart';
import 'package:matchu_app/services/user/account_service.dart';
import 'package:matchu_app/utils/interest_tags.dart';
import 'package:matchu_app/utils/profile_input_validator.dart';
import 'package:matchu_app/translations/profile_translations.dart';

enum DobField { day, month, year }

class AccountSettingsController extends GetxController {
  final fullnameC = TextEditingController();
  final nicknameC = TextEditingController();
  final interestC = TextEditingController();

  final selectedGender = ''.obs;

  // ===== DOB STATE =====
  final selectedDobField = Rxn<DobField>();
  final selectedDay = RxnInt();
  final selectedMonth = RxnInt();
  final selectedYear = RxnInt();
  final selectedBirthday = Rx<DateTime?>(null);

  final isSaving = false.obs;
  final isLoadingInitial = true.obs;

  final isCheckingNickname = false.obs;
  final isNicknameAvailable = RxnBool();
  final nicknameCheckMessage = ''.obs;
  final selectedInterests = <String>[].obs;
  final RxString _nicknameDraft = ''.obs;

  final _service = AccountService();

  Worker? _nicknameDebounceWorker;
  int _nicknameCheckToken = 0;
  bool _isNormalizingFullname = false;
  bool _isNormalizingNickname = false;

  ProfileSnapshot? _original;

  @override
  void onInit() {
    super.onInit();
    _nicknameDebounceWorker = debounce<String>(
      _nicknameDraft,
      (value) => _checkNicknameDebounced(value),
      time: const Duration(milliseconds: 500),
    );
    loadCurrentUser();
  }

  Future<void> loadCurrentUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      isLoadingInitial.value = false;
      Get.snackbar(
        ProfileTranslationKeys.error.tr,
        profileTr("Không tìm thấy người dùng"),
      );
      return;
    }

    try {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      final data = snap.data();
      if (data == null) {
        throw Exception("Không tìm thấy dữ liệu hồ sơ");
      }

      final fullname = ProfileInputValidator.normalizeFullname(
        data['fullname'] ?? '',
      );
      final nickname = ProfileInputValidator.sanitizeNicknameRealtime(
        data['nickname'] ?? '',
      );
      final gender = (data['gender'] ?? '').toString().trim();
      final birthday = _parseBirthday(data['birthday']);
      final interests = InterestTags.normalizeList(
        List<String>.from(data['interests'] ?? const []),
      );

      if (birthday == null) {
        throw Exception("Ngày sinh không hợp lệ");
      }

      fullnameC.text = fullname;
      nicknameC.text = nickname;
      selectedGender.value = gender;

      selectedBirthday.value = birthday;
      selectedDay.value = birthday.day;
      selectedMonth.value = birthday.month;
      selectedYear.value = birthday.year;
      selectedInterests.assignAll(interests);
      interestC.clear();

      _original = ProfileSnapshot(
        fullname: fullname,
        nickname: nickname,
        gender: gender,
        birthday: birthday,
        interests: interests,
      );

      isNicknameAvailable.value = true;
      nicknameCheckMessage.value = '';
    } catch (e) {
      Get.snackbar(
        ProfileTranslationKeys.error.tr,
        profileTr("Không thể tải hồ sơ: $e"),
      );
    } finally {
      isLoadingInitial.value = false;
    }
  }

  bool get hasChanged {
    if (_original == null) return false;

    final currentFullname = ProfileInputValidator.normalizeFullname(
      fullnameC.text,
    );
    final currentNickname = ProfileInputValidator.normalizeNickname(
      nicknameC.text,
    );

    return currentFullname != _original!.fullname ||
        currentNickname != _original!.nickname ||
        selectedGender.value != _original!.gender ||
        !_isSameDate(selectedBirthday.value, _original!.birthday) ||
        !_isSameInterests(selectedInterests, _original!.interests);
  }

  // ===== GHÉP NGÀY SINH =====
  void updateBirthdayIfReady() {
    if (selectedDay.value == null ||
        selectedMonth.value == null ||
        selectedYear.value == null) {
      return;
    }

    final d = selectedDay.value!;
    final m = selectedMonth.value!;
    final y = selectedYear.value!;

    final lastDay = DateTime(y, m + 1, 0).day;
    if (d > lastDay) {
      selectedDay.value = lastDay;
    }

    selectedBirthday.value = DateTime(y, m, selectedDay.value!);
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

    if (_original != null && nickname == _original!.nickname) {
      isNicknameAvailable.value = true;
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
      final isUnique = await _service.isNicknameUnique(nickname);

      final latestNickname = ProfileInputValidator.normalizeNickname(
        nicknameC.text,
      );
      if (currentToken != _nicknameCheckToken || latestNickname != nickname) {
        return null;
      }

      isNicknameAvailable.value = isUnique;
      nicknameCheckMessage.value = profileTr(
        isUnique ? "Nickname có thể sử dụng" : "Nickname đã được sử dụng",
      );
      return isUnique;
    } catch (_) {
      if (currentToken == _nicknameCheckToken) {
        isNicknameAvailable.value = null;
        nicknameCheckMessage.value = profileTr(
          "Không thể kiểm tra nickname. Vui lòng thử lại",
        );
      }
      return null;
    } finally {
      if (currentToken == _nicknameCheckToken) {
        isCheckingNickname.value = false;
      }
    }
  }

  Future<bool> _ensureNicknameUnique(String nickname) async {
    if (_original != null && nickname == _original!.nickname) {
      return true;
    }

    if (!isCheckingNickname.value &&
        ProfileInputValidator.normalizeNickname(nicknameC.text) == nickname &&
        isNicknameAvailable.value != null) {
      return isNicknameAvailable.value == true;
    }

    final checked = await _checkNicknameAvailability(nickname);
    return checked == true;
  }

  Future<void> save() async {
    if (isSaving.value) return;

    final fullname = ProfileInputValidator.normalizeFullname(fullnameC.text);
    final nickname = ProfileInputValidator.normalizeNickname(
      ProfileInputValidator.sanitizeNicknameRealtime(nicknameC.text),
    );
    final gender = selectedGender.value;
    final birthday = selectedBirthday.value;
    final interests = InterestTags.normalizeList(selectedInterests);

    if (fullnameC.text != fullname) {
      _replaceControllerText(fullnameC, fullname);
    }
    if (nicknameC.text != nickname) {
      _replaceControllerText(nicknameC, nickname);
    }

    final fullnameError = ProfileInputValidator.validateFullname(fullname);
    if (fullnameError != null) {
      Get.snackbar(ProfileTranslationKeys.error.tr, profileTr(fullnameError));
      return;
    }

    final nicknameError = ProfileInputValidator.validateNickname(nickname);
    if (nicknameError != null) {
      Get.snackbar(ProfileTranslationKeys.error.tr, profileTr(nicknameError));
      return;
    }

    if (!['male', 'female', 'other'].contains(gender)) {
      Get.snackbar(
        ProfileTranslationKeys.error.tr,
        profileTr("Vui lòng chọn giới tính"),
      );
      return;
    }

    if (birthday == null) {
      Get.snackbar(
        ProfileTranslationKeys.error.tr,
        profileTr("Vui lòng chọn ngày sinh"),
      );
      return;
    }

    if (!_isAdult(birthday)) {
      Get.snackbar(
        ProfileTranslationKeys.error.tr,
        profileTr("Bạn phải đủ 18 tuổi"),
      );
      return;
    }

    final isNicknameUnique = await _ensureNicknameUnique(nickname);
    if (!isNicknameUnique) {
      final message =
          isNicknameAvailable.value == false
              ? "Nickname đã được sử dụng"
              : "Không thể kiểm tra nickname. Vui lòng thử lại";
      Get.snackbar(ProfileTranslationKeys.error.tr, profileTr(message));
      return;
    }

    if (!hasChanged) {
      return;
    }

    isSaving.value = true;
    try {
      await _service.updateBasicProfile(
        fullname: fullname,
        nickname: nickname,
        gender: gender,
        birthday: birthday,
        interests: interests,
      );

      _original = ProfileSnapshot(
        fullname: fullname,
        nickname: nickname,
        gender: gender,
        birthday: birthday,
        interests: interests,
      );

      isNicknameAvailable.value = true;
      nicknameCheckMessage.value = '';

      Get.snackbar(
        ProfileTranslationKeys.success.tr,
        profileTr("Đã cập nhật hồ sơ"),
      );
    } catch (e) {
      Get.snackbar(ProfileTranslationKeys.error.tr, profileTr(e.toString()));
    } finally {
      isSaving.value = false;
    }
  }

  DateTime? _parseBirthday(dynamic raw) {
    if (raw == null) return null;

    if (raw is String && raw.trim().isNotEmpty) {
      return DateTime.tryParse(raw.trim());
    }

    return null;
  }

  bool _isSameDate(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;

    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isSameInterests(List<String> a, List<String> b) {
    final left = InterestTags.normalizeList(a);
    final right = InterestTags.normalizeList(b);
    if (left.length != right.length) return false;

    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }

    return true;
  }

  bool _isAdult(DateTime birthday) {
    final now = DateTime.now();
    var age = now.year - birthday.year;

    final hadBirthdayThisYear =
        now.month > birthday.month ||
        (now.month == birthday.month && now.day >= birthday.day);

    if (!hadBirthdayThisYear) {
      age--;
    }

    return age >= 18;
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

  @override
  void onClose() {
    _nicknameDebounceWorker?.dispose();
    fullnameC.dispose();
    nicknameC.dispose();
    interestC.dispose();
    super.onClose();
  }
}
