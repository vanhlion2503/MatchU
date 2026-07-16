import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:matchu_app/services/user/user_service.dart';
import 'package:matchu_app/controllers/user/presence_controller.dart';
import 'package:matchu_app/models/nearby_user_vm.dart';
import 'package:matchu_app/services/feed/post_restriction_service.dart';
import 'package:matchu_app/services/nearby/nearby_service.dart';
import 'package:matchu_app/utils/location_utils.dart';
import 'package:matchu_app/translations/nearby_translations.dart';

class NearbyController extends GetxController {
  static const String _presenceOwner = 'nearby';

  final NearbyService _nearbyService = NearbyService();
  final UserService _userService = UserService();
  final PostRestrictionService _restrictionService = PostRestrictionService();
  final PresenceController _presence =
      Get.isRegistered<PresenceController>()
          ? Get.find<PresenceController>()
          : Get.put(PresenceController());
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<User?>? _authSub;

  final RxList<NearbyUserVM> users = <NearbyUserVM>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isLocationVisible = true.obs;
  final RxBool isUpdatingVisibility = false.obs;
  final RxDouble radiusKm = 10.0.obs;
  final RxInt selectedTab = 0.obs;
  final RxnString locationErrorMessage = RxnString();
  final RxBool canOpenAppSettings = false.obs;
  final RxBool canOpenLocationSettings = false.obs;

  double? _lastLat;
  double? _lastLng;
  bool _isVisibilityLoaded = false;
  Future<void>? _loadFuture;
  bool _queuedReload = false;
  Timer? _radiusDebounce;

  @override
  void onInit() {
    super.onInit();
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      loadNearby(force: true);
      return;
    }

    _authSub = _auth.authStateChanges().listen((user) {
      if (user == null) return;
      loadNearby(force: true);
      _authSub?.cancel();
      _authSub = null;
    });
  }

  @override
  void onClose() {
    _radiusDebounce?.cancel();
    _authSub?.cancel();
    _presence.unlistenOwner(_presenceOwner);
    super.onClose();
  }

  Future<void> _loadVisibilitySetting({bool force = false}) async {
    if (_isVisibilityLoaded && !force) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final data = await _userService.getUserRaw(currentUser.uid);
    final rawValue = data?["nearlyEnabled"];
    isLocationVisible.value = rawValue is bool ? rawValue : true;
    _isVisibilityLoaded = true;
  }

  Future<void> setLocationVisibility(bool enabled) async {
    if (isUpdatingVisibility.value) return;
    if (enabled == isLocationVisible.value) return;

    final previousValue = isLocationVisible.value;
    isLocationVisible.value = enabled;
    isUpdatingVisibility.value = true;

    try {
      await _userService.setNearbyVisibility(enabled);

      if (!enabled) {
        _clearNearbyState(clearError: true);
      }

      await loadNearby(force: true);
    } catch (e) {
      isLocationVisible.value = previousValue;
      _setLocationError("Không cập nhật được trạng thái hiển thị vị trí.");
      Get.snackbar(
        NearbyTranslationKeys.error.tr,
        nearbyTr("Không cập nhật được trạng thái hiển thị vị trí."),
      );
    } finally {
      isUpdatingVisibility.value = false;
    }
  }

  Future<void> loadNearby({bool force = false}) async {
    if (_loadFuture != null) {
      _queuedReload = true;
      return _loadFuture!;
    }

    _loadFuture = _runLoadLoop(force: force);
    return _loadFuture!;
  }

  Future<void> _runLoadLoop({required bool force}) async {
    var nextForce = force;
    isLoading.value = true;

    try {
      do {
        _queuedReload = false;
        await _loadNearbyOnce(force: nextForce);
        nextForce = true;
      } while (_queuedReload && !isClosed);
    } finally {
      if (!isClosed) {
        isLoading.value = false;
      }
      _loadFuture = null;
    }
  }

  Future<void> _loadNearbyOnce({required bool force}) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        _setLocationError("Phiên đăng nhập chưa sẵn sàng. Vui lòng thử lại.");
        return;
      }

      await _loadVisibilitySetting(force: force);

      if (!isLocationVisible.value) {
        _clearNearbyState(clearError: true);
        return;
      }

      final pos = await _nearbyService.getCurrentPosition();
      if (isClosed || !isLocationVisible.value) return;
      if (_auth.currentUser?.uid != currentUser.uid) return;

      await updateLocationIfNeeded(pos);
      if (isClosed || !isLocationVisible.value) return;

      final result = await _nearbyService.fetchNearbyUsers(
        currentUid: currentUser.uid,
        myLat: pos.latitude,
        myLng: pos.longitude,
        radiusKm: radiusKm.value,
      );
      if (isClosed || !isLocationVisible.value) return;
      if (_auth.currentUser?.uid != currentUser.uid) return;

      final blockedUserIds = await _restrictionService.fetchBlockedUserIds();
      if (isClosed || !isLocationVisible.value) return;

      final visibleResult = result
          .where((user) => !blockedUserIds.contains(user.uid.trim()))
          .toList(growable: false);

      users.assignAll(visibleResult);
      _clearLocationError();

      final aliveUids = visibleResult.map((e) => e.uid).toSet();

      for (final uid in aliveUids) {
        _presence.listen(uid, owner: _presenceOwner);
      }

      _presence.unlistenExcept(aliveUids, owner: _presenceOwner);
    } on NearbyLocationException catch (e) {
      _clearNearbyState();
      _clearRemoteLocationBestEffort();
      _setLocationError(
        e.message,
        canOpenAppSettings: e.canOpenAppSettings,
        canOpenLocationSettings: e.canOpenLocationSettings,
      );
    } catch (e) {
      _setLocationError(
        "Không tải được danh sách quanh bạn. Vui lòng thử lại.",
      );
      Get.snackbar(
        NearbyTranslationKeys.error.tr,
        nearbyTr("Không tải được danh sách quanh bạn."),
      );
    }
  }

  Future<void> updateLocationIfNeeded(Position pos) async {
    if (!isLocationVisible.value) return;

    if (_lastLat == null) {
      _lastLat = pos.latitude;
      _lastLng = pos.longitude;

      await _userService.updateUserLocation(
        lat: pos.latitude,
        lng: pos.longitude,
      );
      return;
    }

    final moved = LocationUtils.distanceKm(
      _lastLat!,
      _lastLng!,
      pos.latitude,
      pos.longitude,
    );

    if (moved > 0.5) {
      // >500m
      _lastLat = pos.latitude;
      _lastLng = pos.longitude;

      await _userService.updateUserLocation(
        lat: pos.latitude,
        lng: pos.longitude,
      );
    }
  }

  void changeRadius(double value) {
    radiusKm.value = value;
    _radiusDebounce?.cancel();
    _radiusDebounce = Timer(const Duration(milliseconds: 450), () {
      if (isClosed) return;
      loadNearby(force: true);
    });
  }

  void changeTab(int index) {
    if (selectedTab.value == index) return;
    selectedTab.value = index;
  }

  @override
  Future<void> refresh() async {
    _radiusDebounce?.cancel();
    await loadNearby(force: true);
  }

  Future<void> retryLocation() async {
    await refresh();
  }

  Future<void> openLocationSettings() async {
    await _nearbyService.openLocationSettings();
  }

  Future<void> openAppSettings() async {
    await _nearbyService.openAppSettings();
  }

  bool isUserOnline(String uid) {
    return _presence.isOnline(uid);
  }

  void applyUserBlocked(String userId) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return;

    users.removeWhere((user) => user.uid.trim() == normalizedUserId);
    final aliveUids = users.map((user) => user.uid).toSet();
    _presence.unlistenExcept(aliveUids, owner: _presenceOwner);
  }

  void _clearNearbyState({bool clearError = false}) {
    users.clear();
    _presence.unlistenOwner(_presenceOwner);
    _lastLat = null;
    _lastLng = null;
    if (clearError) {
      _clearLocationError();
    }
  }

  void _clearRemoteLocationBestEffort() {
    if (_auth.currentUser == null) return;

    unawaited(_userService.clearUserLocation().catchError((_) {}));
  }

  void _setLocationError(
    String message, {
    bool canOpenAppSettings = false,
    bool canOpenLocationSettings = false,
  }) {
    locationErrorMessage.value = message;
    this.canOpenAppSettings.value = canOpenAppSettings;
    this.canOpenLocationSettings.value = canOpenLocationSettings;
  }

  void _clearLocationError() {
    locationErrorMessage.value = null;
    canOpenAppSettings.value = false;
    canOpenLocationSettings.value = false;
  }
}
