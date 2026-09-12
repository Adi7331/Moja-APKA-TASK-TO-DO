import 'package:dzien_po_dniu/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release manifest identifies only a newer stable semantic version', () {
    final release = ReleaseInfo.fromJson({
      'version': '1.1.0',
      'androidUrl': 'https://github.com/Adi7331/Moja-APKA-TASK-TO-DO/releases/download/v1.1.0/app.apk',
      'windowsUrl': 'https://github.com/Adi7331/Moja-APKA-TASK-TO-DO/releases/download/v1.1.0/app.zip',
      'notes': 'Calendar i Skupienie',
    });

    expect(release.isNewerThan('1.0.9'), isTrue);
    expect(release.isNewerThan('1.1.0'), isFalse);
    expect(release.isNewerThan('1.2.0'), isFalse);
  });

  test('release manifest rejects a missing Android download link', () {
    expect(
      () => ReleaseInfo.fromJson({'version': '1.1.0'}),
      throwsFormatException,
    );
  });

  test(
    'release manifest rejects an unsafe download host and malformed version',
    () {
      expect(
        () => ReleaseInfo.fromJson({
          'version': 'next',
          'androidUrl': 'https://example.com/app.apk',
        }),
        throwsFormatException,
      );
    },
  );

  test('release selects the correct download for Android and Windows', () {
    final release = ReleaseInfo.fromJson({
      'version': '1.1.0',
      'androidUrl': 'https://github.com/Adi7331/Moja-APKA-TASK-TO-DO/releases/download/v1.1.0/app.apk',
      'windowsUrl': 'https://github.com/Adi7331/Moja-APKA-TASK-TO-DO/releases/download/v1.1.0/app.zip',
    });

    expect(release.downloadUrlFor(UpdatePlatform.android), release.androidUrl);
    expect(release.downloadUrlFor(UpdatePlatform.windows), release.windowsUrl);
    expect(release.downloadUrlFor(UpdatePlatform.other), isNull);
  });
}
