class VideoMatchingAccessProof {
  const VideoMatchingAccessProof({
    required this.id,
    required this.deviceId,
    required this.expiresAt,
  });

  final String id;
  final String deviceId;
  final DateTime expiresAt;

  bool isUsableAt(DateTime now) {
    // Keep a small clock/network margin so a proof cannot expire while the
    // matching callable is in flight.
    return id.isNotEmpty &&
        deviceId.isNotEmpty &&
        expiresAt.isAfter(now.add(const Duration(seconds: 15)));
  }

  factory VideoMatchingAccessProof.fromRouteResult({
    required Map<dynamic, dynamic> result,
    required String deviceId,
  }) {
    final id = result['sessionId']?.toString().trim() ?? '';
    final expiresAt =
        DateTime.tryParse(result['expiresAt']?.toString() ?? '')?.toUtc();
    if (result['success'] != true || id.isEmpty || expiresAt == null) {
      throw const FormatException('Invalid video matching face proof.');
    }
    return VideoMatchingAccessProof(
      id: id,
      deviceId: deviceId,
      expiresAt: expiresAt,
    );
  }
}
