import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:matchu_app/utils/location_utils.dart';
import 'package:matchu_app/models/nearby_user_vm.dart';

class NearbyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<Position> getCurrentPosition({
    Duration timeLimit = const Duration(seconds: 12),
  }) async {
    bool enabled = await Geolocator.isLocationServiceEnabled();

    if(!enabled) throw Exception("Gps chưa được bật");

    LocationPermission permission = await Geolocator.checkPermission();

    if(permission == LocationPermission.denied){
      permission = await Geolocator.requestPermission();
    }

    if(permission == LocationPermission.denied){
      throw Exception("Chua cap quyen vi tri");
    }

    if(permission == LocationPermission.deniedForever){
      throw Exception("GPS bị từ chối vĩnh viễn");
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: timeLimit,
      );
    } on TimeoutException {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      throw Exception("Khong lay duoc vi tri");
    }
  }

  Future<List<NearbyUserVM>> fetchNearbyUsers({
    required String currentUid,
    required double myLat,
    required double myLng,
    required double radiusKm,
  }) async {
    final box = LocationUtils.calculateBoundingBox(
      lat: myLat, 
      lng: myLng, 
      radiusKm: radiusKm,
    );

    final snapshot = await _db
        .collection("users")
        .where("nearlyEnabled", isEqualTo: true)
        .where("location.lat",
            isGreaterThanOrEqualTo: box.minLat)
        .where("location.lat",
            isLessThanOrEqualTo: box.maxLat)
        .get();
    final now = DateTime.now();
    final List<NearbyUserVM> result = [];

    for(final doc in snapshot.docs){
      if (doc.id == currentUid) continue;
      
      final data = doc.data();

      final lastActive = data["lastActiveAt"];

      if(lastActive == null) continue;

      final lastActiveTime = (lastActive as Timestamp).toDate();

      if(lastActiveTime.isBefore(
        now.subtract(const Duration(hours: 24)),
      )) {continue;}

      final location = data["location"];
      if(location == null) continue;

      final lat = location["lat"];
      final lng = location["lng"];
      if (lat == null || lng == null) continue;

      if (lng < box.minLng || lng > box.maxLng) continue;

      final distance = LocationUtils.distanceKm(
        myLat, 
        myLng, 
        lat.toDouble(),
        lng.toDouble(),
      );

      if (distance > radiusKm) continue;

      result.add(
        NearbyUserVM(
          uid: doc.id, 
          fullname: data["fullname"] ?? "",
          nickname: data["nickname"] ?? "", 
          avatarUrl: data["avatarUrl"] ?? "", 
          distanceKm: distance, 
          activeStatus: data["activeStatus"] ?? "offline")
      );
    }
    result.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return result;
  }
}

