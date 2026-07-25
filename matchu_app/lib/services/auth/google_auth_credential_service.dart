import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Provides one Google credential flow for both sign-in and sensitive
/// reauthentication. GoogleSignIn v7 must be initialized before authenticate.
abstract final class GoogleAuthCredentialService {
  static Future<void>? _initialization;

  static Future<OAuthCredential> requestCredential() async {
    await _ensureInitialized();
    final googleUser = await GoogleSignIn.instance.authenticate();
    final googleAuthentication = googleUser.authentication;
    final idToken = googleAuthentication.idToken;
    if (idToken == null || idToken.trim().isEmpty) {
      throw const GoogleSignInException(
        code: GoogleSignInExceptionCode.providerConfigurationError,
        description: 'Google did not return an ID token.',
      );
    }

    return GoogleAuthProvider.credential(idToken: idToken);
  }

  static Future<void> _ensureInitialized() async {
    final existing = _initialization;
    if (existing != null) {
      await existing;
      return;
    }

    final initialization = GoogleSignIn.instance.initialize();
    _initialization = initialization;
    try {
      await initialization;
    } catch (_) {
      // A transient initialization error must not permanently block retries.
      if (identical(_initialization, initialization)) {
        _initialization = null;
      }
      rethrow;
    }
  }
}
