import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'release workflow builds and publishes signed Android and Windows ZIPs',
    () {
      final workflow = File('.github/workflows/release.yml').readAsStringSync();

      expect(workflow, contains("tags: ['v*']"));
      expect(workflow, contains('workflow_dispatch:'));
      expect(workflow, contains('contents: write'));
      expect(workflow, contains('secrets.SUPABASE_URL'));
      expect(workflow, contains('secrets.SUPABASE_PUBLISHABLE_KEY'));
      expect(workflow, contains('secrets.ANDROID_KEYSTORE_BASE64'));
      expect(workflow, contains('flutter build apk --release'));
      expect(workflow, contains(r'[[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]'));
      expect(workflow, contains(r'ANDROID_BUILD_NUMBER=$((major * 1000000 + minor * 1000 + patch))'));
      expect(workflow, contains(r'major=$((10#$major))'));
      expect(workflow, contains(r'minor=$((10#$minor))'));
      expect(workflow, contains(r'patch=$((10#$patch))'));
      expect(workflow, contains(r'--build-number "$ANDROID_BUILD_NUMBER"'));
      expect(workflow, isNot(contains(r'--build-number "$GITHUB_RUN_NUMBER"')));
      expect(workflow, contains('flutter build windows --release'));
      expect(workflow, contains(r'dzien-po-dniu-android-v${VERSION}.zip'));
      expect(workflow, contains(r'dzien-po-dniu-windows-v$version.zip'));
      expect(workflow, contains('softprops/action-gh-release@v2'));
      expect(workflow, contains('update.json'));
    },
  );
}
