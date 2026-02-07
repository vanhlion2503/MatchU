import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:matchu_app/services/user/user_service.dart';
import 'package:matchu_app/controllers/user/presence_controller.dart';
import 'package:matchu_app/models/nearby_user_vm.dart';
import 'package:matchu_app/services/nearby/nearby_service.dart';
import 'package:matchu_app/utils/location_utils.dart';

class NearbyController extends GetxController {
  final NearbyService _nearbyService = NearbyService();
  final UserService _userService = UserService();
  final PresenceController _presence = Get.put(PresenceController());
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<User?>? _authSub;

  final RxList<NearbyUserVM> users = <NearbyUserVM>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isLocationVisible = true.obs;
  final RxBool isUpdatingVisibility = false.obs;
  final RxDouble radiusKm = 10.0.obs;
  final RxInt selectedTab = 0.obs;

  double? _myLat;
  double? _myLng;

  double? _lastLat;
  double? _lastLng;
  bool _isVisibilityLoaded = false;

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
    _authSub?.cancel();
    _presence.cleanup();
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
        users.clear();
        _presence.unlistenExcept(<String>{});
        _lastLat = null;
        _lastLng = null;
        _myLat = null;
        _myLng = null;
      }

      await loadNearby(force: true);
    } catch (e) {
      isLocationVisible.value = previousValue;
      Get.snackbar("Loi", e.toString());
    } finally {
      isUpdatingVisibility.value = false;
    }
  }

  Future<void> loadNearby({bool force = false}) async {
    try {
      isLoading.value = true;

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        Get.snackbar("Error", "Auth chua san sang");
        return;
      }

      await _loadVisibilitySetting(force: force);

      if (!isLocationVisible.value) {
        users.clear();
        _presence.unlistenExcept(<String>{});
        _myLat = null;
        _myLng = null;
        return;
      }

      final pos = await _nearbyService.getCurrentPosition();

      if (isLocationVisible.value) {
        await _userService.updateUserLocation(
          lat: pos.latitude,
          lng: pos.longitude,
        );
        _lastLat = pos.latitude;
        _lastLng = pos.longitude;
      }

      _myLat = pos.latitude;
      _myLng = pos.longitude;

      final result = await _nearbyService.fetchNearbyUsers(
        currentUid: currentUser.uid,
        myLat: _myLat!,
        myLng: _myLng!,
        radiusKm: radiusKm.value,
      );

      users.value = result;

      final aliveUids = result.map((e) => e.uid).toSet();

      for (final uid in aliveUids) {
        _presence.listen(uid);
      }

      _presence.unlistenExcept(aliveUids);
    } catch (e) {
      Get.snackbar("Lỗi", e.toString());
    } finally {
      isLoading.value = false;
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
    loadNearby(force: true);
  }

  void changeTab(int index) {
    if (selectedTab.value == index) return;
    selectedTab.value = index;
  }

  @override
  Future<void> refresh() async {
    await loadNearby(force: true);
  }

  bool isUserOnline(String uid) {
    return _presence.isOnline(uid);
  }
}
