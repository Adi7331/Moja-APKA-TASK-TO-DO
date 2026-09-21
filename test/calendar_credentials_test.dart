import 'package:dzien_po_dniu/calendar_credentials.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSecretStorage implements CalendarSecretStorage {
  String? value;

  @override
  Future<String?> read(String key) async => value;

  @override
  Future<void> write(String key, String value) async => this.value = value;

  @override
  Future<void> delete(String key) async => value = null;
}

void main() {
  test(
    'calendar credential store saves, reads and clears a device token',
    () async {
      final storage = _FakeSecretStorage();
      final credentials = CalendarCredentialStore(storage);

      await credentials.save('google-access-token');
      expect(await credentials.read(), 'google-access-token');

      await credentials.clear();
      expect(await credentials.read(), isNull);
    },
  );
}
