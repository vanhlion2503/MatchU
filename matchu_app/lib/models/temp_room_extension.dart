enum TempRoomExtensionFailure {
  insufficientGem,
  tooEarly,
  expired,
  limitReached,
  roomUnavailable,
  unknown,
}

class TempRoomExtensionException implements Exception {
  const TempRoomExtensionException(this.failure, {this.currentGem});

  final TempRoomExtensionFailure failure;
  final int? currentGem;
}

abstract final class TempRoomExtensionPolicy {
  static const int gemCost = 1;
  static const int addedMinutes = 5;
  static const int availableAtSeconds = 60;
  static const int maxExtensions = 2;

  static bool isAvailable({
    required int remainingSeconds,
    required int extensionCount,
    required bool isActive,
  }) {
    return isActive &&
        remainingSeconds > 0 &&
        remainingSeconds <= availableAtSeconds &&
        extensionCount < maxExtensions;
  }
}
