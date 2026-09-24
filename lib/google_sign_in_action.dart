import 'package:supabase_flutter/supabase_flutter.dart';

const googleLoginRedirectUrl = 'dzienpodniu://login-callback/';
const googleCalendarReadOnlyScopes =
    'https://www.googleapis.com/auth/calendar.calendarlist.readonly '
    'https://www.googleapis.com/auth/calendar.events.readonly';

/// An OAuth launch must not be completed with the provider token that was
/// already present before Chrome opened. A fresh signed-in callback is the
/// authoritative result; resume is only a fallback when its token changed.
class CalendarOAuthAttempt {
  CalendarOAuthAttempt(this.baselineProviderToken);

  final String? baselineProviderToken;
  bool _consumed = false;

  bool acceptSignedInToken(String? token) => _accept(token);

  bool acceptResumedToken(String? token) {
    if (token == baselineProviderToken) return false;
    return _accept(token);
  }

  bool _accept(String? token) {
    if (_consumed || token == null || token.isEmpty) return false;
    _consumed = true;
    return true;
  }
}

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
