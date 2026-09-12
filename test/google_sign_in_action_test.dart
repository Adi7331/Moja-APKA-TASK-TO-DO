import 'package:flutter_test/flutter_test.dart';

import 'package:dzien_po_dniu/google_sign_in_action.dart';

void main() {
  test('starts Google OAuth with the fixed application callback', () async {
    final calls = <String>[];
    final action = GoogleSignInAction.forTesting((redirectTo) async {
      calls.add(redirectTo);
    });

    await action.start();

    expect(calls, ['dzienpodniu://login-callback/']);
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
    });

    await action.start();

    expect(scopes, contains('calendar.events.readonly'));
    expect(scopes, contains('calendar.calendarlist.readonly'));
    expect(params?['access_type'], 'offline');
  });
}
