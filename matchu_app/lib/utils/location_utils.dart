import 'dart:math';

class BoundingBox{
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  BoundingBox({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });
}

class LocationUtils {
  static const double _earthRadiusKm = 6371;

  static BoundingBox calculateBoundingBox({
    required double lat,
    required double lng,
    required double radiusKm,
  }) {
    final latDelta = radiusKm / _earthRadiusKm;
    final lngDelta =
        radiusKm / (_earthRadiusKm * cos(lat * pi / 180));

    return BoundingBox(
      minLat: lat - latDelta * 180 / pi,
      maxLat: lat + latDelta * 180 / pi,
      minLng: lng - lngDelta * 180 / pi,
      maxLng: lng + lngDelta * 180 / pi,
    );
  }

  static double distanceKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    return _earthRadiusKm * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _degToRad(double deg) => deg * pi / 180;
}