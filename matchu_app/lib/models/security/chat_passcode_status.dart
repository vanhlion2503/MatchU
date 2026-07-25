class ChatPasscodeStatus {
  const ChatPasscodeStatus({
    required this.isConfigured,
    required this.isUnlockedOnDevice,
    required this.isHistoryLocked,
    required this.isFaceVerified,
    required this.isFaceRecoveryAvailable,
  });

  final bool isConfigured;
  final bool isUnlockedOnDevice;
  final bool isHistoryLocked;
  final bool isFaceVerified;
  final bool isFaceRecoveryAvailable;

  bool get canRecoverWithFace =>
      isConfigured && isFaceVerified && isFaceRecoveryAvailable;
}
