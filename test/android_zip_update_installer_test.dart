import 'dart:io';

import 'package:dzien_po_dniu/android_zip_update_installer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('downloads a ZIP and sends it to the Android installer', () async {
    final directory = await Directory.systemTemp.createTemp('dpp-update-test');
    addTearDown(() => directory.delete(recursive: true));
    final package = File('${directory.path}/dzien-po-dniu.zip');
    var installedPath = '';
    final installer = AndroidZipUpdateInstaller(
      download: (url) async {
        expect(url.path, endsWith('.zip'));
        await package.writeAsBytes([1, 2, 3]);
        return package;
      },
      installZip: (file) async => installedPath = file.path,
    );

    final started = await installer.start(
      Uri.parse(
        'https://github.com/Adi7331/Moja-APKA-TASK-TO-DO/releases/download/v1.1.1/dzien-po-dniu-v1.1.1.zip',
      ),
      isAndroid: true,
    );

    expect(started, isTrue);
    expect(installedPath, package.path);
  });
}
