import 'package:cryptography/cryptography.dart';

class RemoteSignalKeys {
  /// Identity DH key (X25519)
  final SimplePublicKey identityDhKey;

  /// Signed PreKey (X25519)
  final SimplePublicKey signedPreKey;

  /// One-time PreKey (X25519)
  final SimplePublicKey oneTimePreKey;

  RemoteSignalKeys({
    required this.identityDhKey,
    required this.signedPreKey,
    required this.oneTimePreKey,
  });
}
