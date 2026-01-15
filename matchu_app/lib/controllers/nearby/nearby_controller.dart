import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:matchu_app/services/user/user_service.dart';
import 'package:matchu_app/controllers/user/presence_controller.dart';
import 'package:matchu_app/models/nearby_user_vm.dart';
import 'package:matchu_app/services/nearby/nearby_service.dart';
import 'package:matchu_app/utils/location_utils.dart';

class NearbyController extends GetxController{
  final NearbyService _nearbyService = NearbyService();
  final UserService _userService = UserService();
  final PresenceController _presence = Get.put(PresenceController());
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<User?>? _authSub;

  final RxList<NearbyUserVM> users = <NearbyUserVM>[].obs;
  final RxBool isLoading = false.obs;
  final RxDouble radiusKm = 3.0.obs;
  final RxInt selectedTab = 0.obs;

  double? _myLat;
  double? _myLng;

  double? _lastLat;
  double? _lastLng;

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

  Future<void> loadNearby({bool force = false}) async {
    try{
      isLoading.value = true;

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        Get.snackbar("Error", "Auth chua san sang");
        return;
      }

      final pos = await _nearbyService.getCurrentPosition();

      await _userService.updateUserLocation(
        lat: pos.latitude, 
        lng: pos.longitude,
      );

      _myLat = pos.latitude;
      _myLng = pos.longitude;

      final result = await _nearbyService.fetchNearbyUsers(
        currentUid: currentUser.uid,
        myLat: _myLat!, 
        myLng: _myLng!, 
        radiusKm: radiusKm.value
      );

      users.value = result;

      final aliveUids = result.map((e) => e.uid).toSet();

      for (final uid in aliveUids){
        _presence.listen(uid);
      }

      _presence.unlistenExcept(aliveUids);
    } catch(e){
      Get.snackbar("Lỗi", e.toString());
    } finally{
      isLoading.value = false;
    }
  }

  Future<void> updateLocationIfNeeded(Position pos) async {
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

    if (moved > 0.5) { // >500m
      _lastLat = pos.latitude;
      _lastLng = pos.longitude;

      await _userService.updateUserLocation(
        lat: pos.latitude,
        lng: pos.longitude,
      );
    }
  }

  void changeRadius(double value){
    radiusKm.value = value;
    loadNearby(force: true);
  }

  void changeTab(int index) {
    if (selectedTab.value == index) return;
    selectedTab.value = index;
  }

  Future<void> refresh() async {
    await loadNearby(force: true);
  }

  bool isUserOnline(String uid){
    return _presence.isOnline(uid);
  }

}
