import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:dzien_po_dniu/local_backup_codec.dart';

void main() {
  final snapshot = {
    'ownerId': 'owner-1',
    'tasks': [
      {'id': '1', 'title': 'Zażółć gęślą jaźń'},
    ],
    'attachments': {'photo.jpg': base64Encode([1, 2, 3])},
  };

  test('plain backup preserves data and detects corruption', () {
    final bytes = LocalBackupCodec.encode(snapshot);
    expect(LocalBackupCodec.decode(bytes), snapshot);
    final text = utf8.decode(bytes);
    expect(text, contains('encrypted":false'));
    final corrupt = utf8.encode(text.replaceFirst('owner-1', 'owner-2'));
    expect(() => LocalBackupCodec.decode(corrupt), throwsFormatException);
  });

  test('password-protected backup hides contents and requires password', () {
    final bytes = LocalBackupCodec.encode(snapshot, password: 'moje hasło');
    expect(utf8.decode(bytes), isNot(contains('Zażółć')));
    expect(LocalBackupCodec.decode(bytes, password: 'moje hasło'), snapshot);
    expect(
      () => LocalBackupCodec.decode(bytes, password: 'złe hasło'),
      throwsFormatException,
    );
    expect(() => LocalBackupCodec.decode(bytes), throwsFormatException);
  });
}
