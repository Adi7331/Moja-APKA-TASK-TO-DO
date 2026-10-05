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
    Future<bool> Function(String redirectTo) startOAuth,
  ) => _CallbackGoogleSignInAction(startOAuth);
}

class OAuthLaunchException implements Exception {
  const OAuthLaunchException(this.flowName);

  final String flowName;

  @override
  String toString() => 'Nie udało się otworzyć przeglądarki dla logowania $flowName.';
}

String googleOAuthErrorMessage(Object error) {
  if (error is OAuthLaunchException) return error.toString();

  final rawDetail = error is AuthException ? error.message : error.toString();
  final detail = _redactOAuthDetails(rawDetail);
  final normalized = detail.toLowerCase();

  if (normalized.contains('redirect') &&
      (normalized.contains('not allowed') ||
          normalized.contains('mismatch') ||
          normalized.contains('invalid'))) {
    return 'Supabase odrzucił adres powrotu. W Authentication → URL Configuration '
        'dodaj: $googleLoginRedirectUrl';
  }
  if (normalized.contains('provider') &&
      (normalized.contains('disabled') || normalized.contains('not enabled'))) {
    return 'Logowanie Google jest wyłączone w ustawieniach dostawców Supabase.';
  }

  return detail.isEmpty
      ? 'Logowanie Google nie powiodło się (${error.runtimeType}).'
      : 'Logowanie Google nie powiodło się: $detail';
}

String _redactOAuthDetails(String value) {
  final sanitized = value
      .replaceAll(
        RegExp(
          r'(access_token|refresh_token|id_token|code|state)=([^&\s]+)',
          caseSensitive: false,
        ),
        r'$1=[ukryto]',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final end = sanitized.length > 240 ? 240 : sanitized.length;
  return sanitized.substring(0, end);
}

Future<void> _launchOAuth(String flowName, Future<bool> Function() launch) async {
  if (!await launch()) throw OAuthLaunchException(flowName);
}

class SupabaseGoogleSignInAction implements GoogleSignInAction {
  SupabaseGoogleSignInAction(this._client);

  final SupabaseClient _client;

  @override
  Future<void> start() async {
    await _launchOAuth(
      'Google',
      () => _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: googleLoginRedirectUrl,
      ),
    );
  }
}

class _CallbackGoogleSignInAction implements GoogleSignInAction {
  _CallbackGoogleSignInAction(this._startOAuth);

  final Future<bool> Function(String redirectTo) _startOAuth;

  @override
  Future<void> start() async {
    await _launchOAuth('Google', () => _startOAuth(googleLoginRedirectUrl));
  }
}

abstract interface class CalendarConnectionAction {
  Future<void> start();

  static CalendarConnectionAction forTesting(
    Future<bool> Function(String scopes, Map<String, String> queryParams)
    startOAuth,
  ) => _CallbackCalendarConnectionAction(startOAuth);
}

class SupabaseCalendarConnectionAction implements CalendarConnectionAction {
  SupabaseCalendarConnectionAction(this._client);
  final SupabaseClient _client;

  @override
  Future<void> start() async {
    await _launchOAuth(
      'Google Calendar',
      () => _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: googleLoginRedirectUrl,
        scopes: googleCalendarReadOnlyScopes,
        queryParams: const {'access_type': 'offline', 'prompt': 'consent'},
      ),
    );
  }
}

class _CallbackCalendarConnectionAction implements CalendarConnectionAction {
  _CallbackCalendarConnectionAction(this._startOAuth);
  final Future<bool> Function(String scopes, Map<String, String> queryParams)
  _startOAuth;

  @override
  Future<void> start() async {
    await _launchOAuth(
      'Google Calendar',
      () => _startOAuth(googleCalendarReadOnlyScopes, const {
        'access_type': 'offline',
        'prompt': 'consent',
      }),
    );
  }
}
