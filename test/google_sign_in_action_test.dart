import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dzien_po_dniu/google_sign_in_action.dart';

void main() {
  test('calendar reconnect ignores the provider token from the old session', () {
    final attempt = CalendarOAuthAttempt('stale-token');

    expect(attempt.acceptResumedToken('stale-token'), isFalse);
    expect(attempt.acceptResumedToken('new-token'), isTrue);
    expect(attempt.acceptResumedToken('new-token'), isFalse);
  });

  test('calendar reconnect accepts one new sign-in callback', () {
    final attempt = CalendarOAuthAttempt('stale-token');

    expect(attempt.acceptSignedInToken('stale-token'), isTrue);
    expect(attempt.acceptSignedInToken('stale-token'), isFalse);
  });

  test('starts Google OAuth with the fixed application callback', () async {
    final calls = <String>[];
    final action = GoogleSignInAction.forTesting((redirectTo) async {
      calls.add(redirectTo);
      return true;
    });

    await action.start();

    expect(calls, ['dzienpodniu://login-callback/']);
  });

  test('reports when the OAuth browser could not be opened', () async {
    final action = GoogleSignInAction.forTesting((_) async => false);

    await expectLater(action.start(), throwsA(isA<OAuthLaunchException>()));
  });

  test('shows a useful safe message for OAuth launch failures', () {
    expect(
      googleOAuthErrorMessage(const OAuthLaunchException('Google')),
      contains('przeglądarki'),
    );
  });

  test('redacts OAuth codes from an authentication error', () {
    final message = googleOAuthErrorMessage(
      AuthException('callback failed: code=private-value'),
    );

    expect(message, contains('code=[ukryto]'));
    expect(message, isNot(contains('private-value')));
  });

  test('publishes the callback URI used by Google OAuth', () {
    expect(googleLoginRedirectUrl, 'dzienpodniu://login-callback/');
  });

  test('calendar connection requests read-only Calendar scopes', () async {
    String? scopes;
    Map<String, String>? params;
    final action = CalendarConnectionAction.forTesting((requestedScopes, queryParams) async {
      scopes = requestedScopes;
      params = queryParams;
      return true;
    });

    await action.start();

    expect(scopes, contains('calendar.events.readonly'));
    expect(scopes, contains('calendar.calendarlist.readonly'));
    expect(params?['access_type'], 'offline');
  });

  test('reports when the Calendar OAuth browser could not be opened', () async {
    final action = CalendarConnectionAction.forTesting((_, __) async => false);

    await expectLater(action.start(), throwsA(isA<OAuthLaunchException>()));
  });
}
