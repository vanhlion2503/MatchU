import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:matchu_app/utils/location_utils.dart';
import 'package:matchu_app/models/nearby_user_vm.dart';

enum NearbyLocationIssue {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  permissionRequestInProgress,
  permissionDefinitionMissing,
  timeout,
  unavailable,
}

class NearbyLocationException implements Exception {
  const NearbyLocationException(this.issue, this.message, {this.cause});

  final NearbyLocationIssue issue;
  final String message;
  final Object? cause;

  bool get canOpenAppSettings =>
      issue == NearbyLocationIssue.permissionDeniedForever ||
      issue == NearbyLocationIssue.permissionDefinitionMissing;

  bool get canOpenLocationSettings =>
      issue == NearbyLocationIssue.serviceDisabled;

  @override
  String toString() => message;
}

class NearbyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<Position> getCurrentPosition({
    Duration timeLimit = const Duration(seconds: 16),
    Duration cachedMaxAge = const Duration(minutes: 20),
  }) async {
    await _ensureLocationPermission();

    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw const NearbyLocationException(
        NearbyLocationIssue.serviceDisabled,
        "GPS đang tắt. Hãy bật dịch vụ vị trí rồi thử lại.",
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: timeLimit,
        ),
      );
    } on TimeoutException catch (error) {
      final last = await _freshLastKnownPosition(maxAge: cachedMaxAge);
      if (last != null) return last;

      throw NearbyLocationException(
        NearbyLocationIssue.timeout,
        "Không lấy được vị trí hiện tại. Hãy thử đứng ở nơi thoáng hơn rồi làm mới.",
        cause: error,
      );
    } on LocationServiceDisabledException catch (error) {
      throw NearbyLocationException(
        NearbyLocationIssue.serviceDisabled,
        "GPS đang tắt. Hãy bật dịch vụ vị trí rồi thử lại.",
        cause: error,
      );
    } on PermissionDefinitionsNotFoundException catch (error) {
      throw NearbyLocationException(
        NearbyLocationIssue.permissionDefinitionMissing,
        "Ứng dụng chưa cấu hình quyền vị trí cho nền tảng này.",
        cause: error,
      );
    } catch (error) {
      final last = await _freshLastKnownPosition(maxAge: cachedMaxAge);
      if (last != null) return last;

      throw NearbyLocationException(
        NearbyLocationIssue.unavailable,
        "Không thể lấy vị trí lúc này. Vui lòng thử lại sau.",
        cause: error,
      );
    }
  }

  Future<void> _ensureLocationPermission() async {
    try {
      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw const NearbyLocationException(
          NearbyLocationIssue.permissionDenied,
          "Bạn chưa cấp quyền vị trí cho MatchU.",
        );
      }

      if (permission == LocationPermission.deniedForever) {
        throw const NearbyLocationException(
          NearbyLocationIssue.permissionDeniedForever,
          "Quyền vị trí đã bị từ chối vĩnh viễn. Hãy mở cài đặt ứng dụng để cấp lại quyền.",
        );
      }
    } on NearbyLocationException {
      rethrow;
    } on PermissionRequestInProgressException catch (error) {
      throw NearbyLocationException(
        NearbyLocationIssue.permissionRequestInProgress,
        "Đang xin quyền vị trí. Vui lòng chờ một chút rồi thử lại.",
        cause: error,
      );
    } on PermissionDefinitionsNotFoundException catch (error) {
      throw NearbyLocationException(
        NearbyLocationIssue.permissionDefinitionMissing,
        "Ứng dụng chưa cấu hình quyền vị trí cho nền tảng này.",
        cause: error,
      );
    }
  }

  Future<Position?> _freshLastKnownPosition({required Duration maxAge}) async {
    final last = await Geolocator.getLastKnownPosition();
    if (last == null) return null;

    if (!LocationUtils.isValidCoordinate(last.latitude, last.longitude)) {
      return null;
    }

    final age = DateTime.now().difference(last.timestamp);
    if (!age.isNegative && age > maxAge) return null;

    return last;
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  Future<List<NearbyUserVM>> fetchNearbyUsers({
    required String currentUid,
    required double myLat,
    required double myLng,
    required double radiusKm,
  }) async {
    if (!LocationUtils.isValidCoordinate(myLat, myLng)) return [];

    final box = LocationUtils.calculateBoundingBox(
      lat: myLat,
      lng: myLng,
      radiusKm: radiusKm,
    );

    final snapshot =
        await _db
            .collection("users")
            .where("nearlyEnabled", isEqualTo: true)
            .where("location.lat", isGreaterThanOrEqualTo: box.minLat)
            .where("location.lat", isLessThanOrEqualTo: box.maxLat)
            .get();
    final now = DateTime.now();
    final List<NearbyUserVM> result = [];

    for (final doc in snapshot.docs) {
      if (doc.id == currentUid) continue;

      final data = doc.data();

      final lastActive = data["lastActiveAt"];

      if (lastActive is! Timestamp) continue;

      final lastActiveTime = lastActive.toDate();

      if (lastActiveTime.isBefore(now.subtract(const Duration(hours: 24)))) {
        continue;
      }

      final location = data["location"];
      if (location is! Map) continue;

      final lat = _asDouble(location["lat"]);
      final lng = _asDouble(location["lng"]);
      if (lat == null || lng == null) continue;
      if (!LocationUtils.isValidCoordinate(lat, lng)) continue;

      if (!box.containsLongitude(lng)) continue;

      final distance = LocationUtils.distanceKm(myLat, myLng, lat, lng);

      if (distance > radiusKm) continue;

      result.add(
        NearbyUserVM(
          uid: doc.id,
          fullname: data["fullname"] ?? "",
          nickname: data["nickname"] ?? "",
          avatarUrl: data["avatarUrl"] ?? "",
          distanceKm: distance,
          activeStatus: data["activeStatus"] ?? "offline",
          isFaceVerified: data["isFaceVerified"] == true,
        ),
      );
    }
    result.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return result;
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return null;
  }
}
