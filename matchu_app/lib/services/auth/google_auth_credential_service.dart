import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Provides one Google credential flow for both sign-in and sensitive
/// reauthentication. GoogleSignIn v7 must be initialized before authenticate.
abstract final class GoogleAuthCredentialService {
  static Future<void>? _initialization;

  static Future<OAuthCredential> requestCredential({
    bool clearPreviousSession = false,
  }) async {
    await _ensureInitialized();
    if (clearPreviousSession) {
      // Google Sign-In v7 uses Credential Manager on Android. Clearing its
      // state immediately before an interactive login prevents the previously
      // suspended account from being auto-selected again.
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Continue with the interactive picker. A provider cleanup failure
        // must not make the login button unusable.
      }
    }
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

  /// Clears only the local Google account session. This does not revoke the
  /// user's Google authorization and allows choosing another account next.
  static Future<void> signOut() async {
    await _ensureInitialized();
    await GoogleSignIn.instance.signOut();
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
