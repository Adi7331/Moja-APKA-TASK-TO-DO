import 'dart:io';

import 'package:dzien_po_dniu/windows_zip_update_installer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final releaseUrl = Uri.parse(
    'https://github.com/Adi7331/Moja-APKA-TASK-TO-DO/releases/download/v1.1.2/dzien-po-dniu.zip',
  );

  test('rejects an update when the platform is not Windows', () async {
    final result = await WindowsZipUpdateInstaller().start(
      releaseUrl,
      parentPid: 4812,
      executablePath: r'C:\Program Files\Dzien po dniu\dzien_po_dniu.exe',
      isWindows: false,
    );

    expect(result.started, isFalse);
    expect(result.message, contains('tylko na Windows'));
  });

  test(
    'writes and launches a replacement helper for a writable install',
    () async {
      final supportDirectory = await Directory.systemTemp.createTemp(
        'dpp-windows-update-test',
      );
      addTearDown(() => supportDirectory.delete(recursive: true));
      final installDirectory = Directory(r'C:\Apps\DzienPoDniu');
      final executablePath = '${installDirectory.path}\\dzien_po_dniu.exe';
      String? downloadPath;
      String? helperPath;
      String? helperScript;
      String? launchedExecutable;
      List<String>? launchedArguments;
      final installer = WindowsZipUpdateInstaller(
        applicationSupportDirectory: () async => supportDirectory,
        download: (url, destination) async {
          downloadPath = destination.path;
        },
        fileExists: (file) async => file.path == executablePath,
        directoryWritable: (directory) async =>
            directory.path == installDirectory.path,
        writeHelper: (file, script) async {
          helperPath = file.path;
          helperScript = script;
        },
        launchHelper: (executable, arguments) async {
          launchedExecutable = executable;
          launchedArguments = arguments;
        },
      );

      final result = await installer.start(
        releaseUrl,
        parentPid: 4812,
        executablePath: executablePath,
        isWindows: true,
      );

      expect(result.started, isTrue);
      expect(downloadPath, endsWith(r'updates\dzien-po-dniu-update.zip'));
      expect(helperPath, endsWith(r'updates\apply-windows-update.ps1'));
      expect(launchedExecutable, 'powershell.exe');
      expect(launchedArguments, containsAll(<String>['--parent-pid', '4812']));
      expect(helperScript, contains('Expand-Archive'));
      expect(helperScript, contains('Move-Item'));
    },
  );

  test(
    'does not launch a helper when the install directory is not writable',
    () async {
      var launched = false;
      final installer = WindowsZipUpdateInstaller(
        fileExists: (_) async => true,
        directoryWritable: (_) async => false,
        launchHelper: (_, _) async {
          launched = true;
        },
      );

      final result = await installer.start(
        releaseUrl,
        parentPid: 4812,
        executablePath: r'C:\Apps\DzienPoDniu\dzien_po_dniu.exe',
        isWindows: true,
      );

      expect(result.started, isFalse);
      expect(result.message, contains('brak uprawnień'));
      expect(launched, isFalse);
    },
  );
}
