import 'dart:convert';
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
        waitForHelperReady: (ready, result, timeout) async => true,
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
      expect(launchedArguments, <String>[
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        helperPath!,
        '--parent-pid',
        '4812',
        '--zip',
        downloadPath!,
        '--install-dir',
        installDirectory.path,
        '--exe-name',
        'dzien_po_dniu.exe',
        '--ready-marker',
        launchedArguments![launchedArguments!.indexOf('--ready-marker') + 1],
        '--ack-marker',
        launchedArguments![launchedArguments!.indexOf('--ack-marker') + 1],
        '--result-file',
        launchedArguments![launchedArguments!.indexOf('--result-file') + 1],
        '--last-result-file',
        launchedArguments![launchedArguments!.indexOf('--last-result-file') +
            1],
      ]);
      final script = helperScript!;
      expect(script, contains('param()'));
      expect(script, contains(r'[string[]]$args'));
      expect(script, contains("Get-RequiredArgument '--parent-pid'"));
      expect(script, contains("Get-RequiredArgument '--zip'"));
      expect(script, contains("Get-RequiredArgument '--install-dir'"));
      expect(script, contains("Get-RequiredArgument '--exe-name'"));
      expect(
        script,
        contains(r'[int]::TryParse($parentPidValue, [ref]$parsedParentPid)'),
      );
      expect(
        script,
        contains(
          r'$parentPath = [System.IO.Directory]::GetParent($installPath).FullName',
        ),
      );
      expect(script, contains('Expand-Archive'));
      expect(script, contains('Write-UpdateResult'));
      expect(script, contains('ackMarker'));
      expect(script, contains('lastResultPath'));
      expect(script, contains('nie potwierdziła poprawnego uruchomienia'));
      expect(script, contains('Move-Item'));
      final createStaging = script.indexOf(
        r'[System.IO.Directory]::CreateDirectory($stagingPath) | Out-Null',
      );
      expect(createStaging, greaterThanOrEqualTo(0));
      expect(createStaging, lessThan(script.indexOf('Expand-Archive')));
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

  test('rejects a nonpositive parent PID before preparing a helper', () async {
    var helperPrepared = false;
    final installer = WindowsZipUpdateInstaller(
      fileExists: (_) async => true,
      directoryWritable: (_) async => true,
      applicationSupportDirectory: () async {
        helperPrepared = true;
        throw StateError('must not prepare helper');
      },
    );

    final result = await installer.start(
      releaseUrl,
      parentPid: 0,
      executablePath: r'C:\Apps\DzienPoDniu\dzien_po_dniu.exe',
      isWindows: true,
    );

    expect(result.started, isFalse);
    expect(result.message, contains('Nieprawidłowy identyfikator procesu'));
    expect(helperPrepared, isFalse);
  });

  test('encodes a PowerShell helper with a BOM and Polish text intact', () {
    const script = "throw 'Nieprawidłowy identyfikator procesu.'";

    final bytes = WindowsZipUpdateInstaller.encodePowerShellScript(script);

    expect(bytes.sublist(0, 3), <int>[0xef, 0xbb, 0xbf]);
    expect(utf8.decode(bytes.sublist(3)), script);
  });
}
