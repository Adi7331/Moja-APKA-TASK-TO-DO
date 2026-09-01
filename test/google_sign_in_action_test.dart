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
}
