import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows runner registers and forwards the OAuth callback protocol', () {
    final runner = File('windows/runner/main.cpp').readAsStringSync();

    expect(runner, contains('RegisterDzienPoDniuProtocol'));
    expect(runner, contains(r'SOFTWARE\\Classes\\dzienpodniu'));
    expect(runner, contains(r'\"%1\"'));
    expect(runner, contains('SendAppLinkToInstance()'));
  });
}
