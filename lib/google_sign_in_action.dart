import 'package:supabase_flutter/supabase_flutter.dart';

const googleLoginRedirectUrl = 'dzienpodniu://login-callback/';

abstract interface class GoogleSignInAction {
  Future<void> start();

  static GoogleSignInAction forTesting(
    Future<void> Function(String redirectTo) startOAuth,
  ) => _CallbackGoogleSignInAction(startOAuth);
}

class SupabaseGoogleSignInAction implements GoogleSignInAction {
  SupabaseGoogleSignInAction(this._client);

  final SupabaseClient _client;

  @override
  Future<void> start() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: googleLoginRedirectUrl,
    );
  }
}

class _CallbackGoogleSignInAction implements GoogleSignInAction {
  _CallbackGoogleSignInAction(this._startOAuth);

  final Future<void> Function(String redirectTo) _startOAuth;

  @override
  Future<void> start() => _startOAuth(googleLoginRedirectUrl);
}
