import 'dart:math';

class BoundingBox {
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;
  final bool crossesAntimeridian;

  const BoundingBox({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
    this.crossesAntimeridian = false,
  });

  bool containsLongitude(double lng) {
    final normalized = LocationUtils.normalizeLongitude(lng);
    if (crossesAntimeridian) {
      return normalized >= minLng || normalized <= maxLng;
    }
    return normalized >= minLng && normalized <= maxLng;
  }
}

class LocationUtils {
  static const double _earthRadiusKm = 6371;

  static BoundingBox calculateBoundingBox({
    required double lat,
    required double lng,
    required double radiusKm,
  }) {
    final safeLat = lat.clamp(-90.0, 90.0);
    final safeLng = normalizeLongitude(lng);
    final safeRadiusKm = radiusKm.clamp(0.1, 20000.0);

    final latDeltaDeg = safeRadiusKm / _earthRadiusKm * 180 / pi;
    final cosLat = cos(safeLat * pi / 180).abs();
    final lngDeltaDeg =
        cosLat < 0.000001
            ? 180.0
            : min(180.0, safeRadiusKm / (_earthRadiusKm * cosLat) * 180 / pi);

    final minLat = (safeLat - latDeltaDeg).clamp(-90.0, 90.0);
    final maxLat = (safeLat + latDeltaDeg).clamp(-90.0, 90.0);

    if (lngDeltaDeg >= 180) {
      return BoundingBox(
        minLat: minLat,
        maxLat: maxLat,
        minLng: -180,
        maxLng: 180,
      );
    }

    final minLng = normalizeLongitude(safeLng - lngDeltaDeg);
    final maxLng = normalizeLongitude(safeLng + lngDeltaDeg);

    return BoundingBox(
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
      crossesAntimeridian: minLng > maxLng,
    );
  }

  static double distanceKm(double lat1, double lng1, double lat2, double lng2) {
    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    return _earthRadiusKm * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static bool isValidCoordinate(double lat, double lng) {
    return lat.isFinite &&
        lng.isFinite &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180;
  }

  static double normalizeLongitude(double lng) {
    if (!lng.isFinite) return 0;

    var normalized = ((lng + 180) % 360) - 180;
    if (normalized <= -180) normalized += 360;
    return normalized;
  }

  static double _degToRad(double deg) => deg * pi / 180;
}
