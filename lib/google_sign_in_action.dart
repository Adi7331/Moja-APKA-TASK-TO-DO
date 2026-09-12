import 'package:supabase_flutter/supabase_flutter.dart';

const googleLoginRedirectUrl = 'dzienpodniu://login-callback/';
const googleCalendarReadOnlyScopes =
    'https://www.googleapis.com/auth/calendar.calendarlist.readonly '
    'https://www.googleapis.com/auth/calendar.events.readonly';

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

abstract interface class CalendarConnectionAction {
  Future<void> start();

  static CalendarConnectionAction forTesting(
    Future<void> Function(String scopes, Map<String, String> queryParams)
    startOAuth,
  ) => _CallbackCalendarConnectionAction(startOAuth);
}

class SupabaseCalendarConnectionAction implements CalendarConnectionAction {
  SupabaseCalendarConnectionAction(this._client);
  final SupabaseClient _client;

  @override
  Future<void> start() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: googleLoginRedirectUrl,
      scopes: googleCalendarReadOnlyScopes,
      queryParams: const {'access_type': 'offline', 'prompt': 'consent'},
    );
  }
}

class _CallbackCalendarConnectionAction implements CalendarConnectionAction {
  _CallbackCalendarConnectionAction(this._startOAuth);
  final Future<void> Function(String scopes, Map<String, String> queryParams)
  _startOAuth;

  @override
  Future<void> start() => _startOAuth(googleCalendarReadOnlyScopes, const {
    'access_type': 'offline',
    'prompt': 'consent',
  });
}
