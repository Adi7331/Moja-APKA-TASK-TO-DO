import 'dart:io';

import 'package:path_provider/path_provider.dart';

class WindowsUpdateStartResult {
  const WindowsUpdateStartResult.started()
    : started = true,
      message = 'Aktualizacja została przygotowana.';

  const WindowsUpdateStartResult.failed(this.message) : started = false;

  final bool started;
  final String message;
}

class WindowsZipUpdateInstaller {
  WindowsZipUpdateInstaller({
    Future<void> Function(Uri url, File destination)? download,
    Future<Directory> Function()? applicationSupportDirectory,
    Future<bool> Function(File file)? fileExists,
    Future<bool> Function(Directory directory)? directoryWritable,
    Future<void> Function(File file, String script)? writeHelper,
    Future<void> Function(String executable, List<String> arguments)?
    launchHelper,
  }) : _download = download ?? _downloadPackage,
       _applicationSupportDirectory =
           applicationSupportDirectory ?? getApplicationSupportDirectory,
       _fileExists = fileExists ?? _fileExistsOnDisk,
       _directoryWritable = directoryWritable ?? _writeDeleteProbe,
       _writeHelper = writeHelper ?? _writeHelperToDisk,
       _launchHelper = launchHelper ?? _launchDetachedPowerShell;

  final Future<void> Function(Uri url, File destination) _download;
  final Future<Directory> Function() _applicationSupportDirectory;
  final Future<bool> Function(File file) _fileExists;
  final Future<bool> Function(Directory directory) _directoryWritable;
  final Future<void> Function(File file, String script) _writeHelper;
  final Future<void> Function(String executable, List<String> arguments)
  _launchHelper;

  Future<WindowsUpdateStartResult> start(
    Uri url, {
    required int parentPid,
    required String executablePath,
    bool? isWindows,
  }) async {
    if (!(isWindows ?? Platform.isWindows)) {
      return const WindowsUpdateStartResult.failed(
        'Aktualizacje ZIP są dostępne tylko na Windows.',
      );
    }
    if (!_isGitHubReleaseZip(url)) {
      return const WindowsUpdateStartResult.failed(
        'Aktualizacja musi być plikiem ZIP z GitHub Releases.',
      );
    }
    if (!executablePath.toLowerCase().endsWith('dzien_po_dniu.exe')) {
      return const WindowsUpdateStartResult.failed(
        'Nie znaleziono oczekiwanego pliku dzien_po_dniu.exe.',
      );
    }

    final executable = File(executablePath);
    if (!await _fileExists(executable)) {
      return const WindowsUpdateStartResult.failed(
        'Nie znaleziono pliku dzien_po_dniu.exe.',
      );
    }

    final installDirectory = executable.parent;
    if (!await _directoryWritable(installDirectory)) {
      return const WindowsUpdateStartResult.failed(
        'brak uprawnień do zapisu w katalogu instalacji.',
      );
    }

    try {
      final supportDirectory = await _applicationSupportDirectory();
      final updatesDirectory = Directory(
        '${supportDirectory.path}${Platform.pathSeparator}updates',
      );
      await updatesDirectory.create(recursive: true);
      final zipFile = File(
        '${updatesDirectory.path}${Platform.pathSeparator}dzien-po-dniu-update.zip',
      );
      final helperFile = File(
        '${updatesDirectory.path}${Platform.pathSeparator}apply-windows-update.ps1',
      );
      await _download(url, zipFile);
      await _writeHelper(helperFile, _replacementScript);
      await _launchHelper('powershell.exe', <String>[
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        helperFile.path,
        '--parent-pid',
        parentPid.toString(),
        '--zip',
        zipFile.path,
        '--install-dir',
        installDirectory.path,
        '--exe-name',
        'dzien_po_dniu.exe',
      ]);
      return const WindowsUpdateStartResult.started();
    } on Object {
      return const WindowsUpdateStartResult.failed(
        'Nie udało się przygotować aktualizacji.',
      );
    }
  }

  static bool _isGitHubReleaseZip(Uri url) =>
      url.scheme == 'https' &&
      url.host == 'github.com' &&
      url.path.toLowerCase().endsWith('.zip') &&
      (url.path.contains('/releases/download/') ||
          url.path.contains('/releases/latest/download/'));

  static Future<bool> _fileExistsOnDisk(File file) => file.exists();

  static Future<bool> _writeDeleteProbe(Directory directory) async {
    if (!await directory.exists()) return false;

    final probe = File(
      '${directory.path}${Platform.pathSeparator}.dpp-write-probe-${DateTime.now().microsecondsSinceEpoch}',
    );
    var created = false;
    try {
      await probe.create(exclusive: true);
      created = true;
      await probe.writeAsString('', mode: FileMode.writeOnly);
      await probe.delete();
      return true;
    } on Object {
      if (created && await probe.exists()) {
        try {
          await probe.delete();
        } on Object {
          // A failed cleanup means this installation directory is unsuitable.
        }
      }
      return false;
    }
  }

  static Future<void> _downloadPackage(Uri url, File destination) async {
    await destination.parent.create(recursive: true);
    final client = HttpClient();
    try {
      final request = await client
          .getUrl(url)
          .timeout(const Duration(seconds: 15));
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Nie udało się pobrać aktualizacji.');
      }
      final sink = destination.openWrite();
      await response.pipe(sink);
    } finally {
      client.close(force: true);
    }
  }

  static Future<void> _writeHelperToDisk(File file, String script) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(script, flush: true);
  }

  static Future<void> _launchDetachedPowerShell(
    String executable,
    List<String> arguments,
  ) async {
    await Process.start(executable, arguments, mode: ProcessStartMode.detached);
  }

  static const _replacementScript = r'''param(
  [Parameter(Mandatory = $true)][int]$parentPid,
  [Parameter(Mandatory = $true)][string]$zip,
  [Parameter(Mandatory = $true)][string]$installDir,
  [Parameter(Mandatory = $true)][string]$exeName
)

$ErrorActionPreference = 'Stop'
$zipPath = [System.IO.Path]::GetFullPath($zip)
$installPath = [System.IO.Path]::GetFullPath($installDir)
$parentPath = Split-Path -LiteralPath $installPath -Parent
$stagingPath = Join-Path -Path $parentPath -ChildPath ('.dzien-po-dniu-staging-' + [Guid]::NewGuid().ToString('N'))
$backupPath = $installPath + '-previous'
$stagingCreated = $false
$backupCreated = $false
$replacementActivated = $false
$activationSucceeded = $false

try {
  while (Get-Process -Id $parentPid -ErrorAction SilentlyContinue) {
    Start-Sleep -Milliseconds 250
  }

  if (!(Test-Path -LiteralPath $installPath -PathType Container)) {
    throw 'Katalog instalacji nie istnieje.'
  }
  if (Test-Path -LiteralPath $backupPath) {
    throw 'Istnieje poprzednia kopia aktualizacji wymagająca sprawdzenia.'
  }

  Expand-Archive -LiteralPath $zipPath -DestinationPath $stagingPath -Force
  $stagingCreated = $true
  $stagedExe = Join-Path -Path $stagingPath -ChildPath $exeName
  if (!(Test-Path -LiteralPath $stagedExe -PathType Leaf)) {
    throw 'Archiwum aktualizacji nie zawiera pliku wykonywalnego.'
  }

  Move-Item -LiteralPath $installPath -Destination $backupPath
  $backupCreated = $true
  Move-Item -LiteralPath $stagingPath -Destination $installPath
  $stagingCreated = $false
  $replacementActivated = $true

  Start-Process -FilePath (Join-Path -Path $installPath -ChildPath $exeName) -WorkingDirectory $installPath
  $activationSucceeded = $true
}
catch {
  if ($backupCreated -and (Test-Path -LiteralPath $backupPath)) {
    if ($replacementActivated -and (Test-Path -LiteralPath $installPath)) {
      Move-Item -LiteralPath $installPath -Destination $stagingPath
      $stagingCreated = $true
      $replacementActivated = $false
    }
    if (!(Test-Path -LiteralPath $installPath)) {
      Move-Item -LiteralPath $backupPath -Destination $installPath
      $backupCreated = $false
    }
  }
  throw
}
finally {
  if ($stagingCreated -and (Test-Path -LiteralPath $stagingPath)) {
    Remove-Item -LiteralPath $stagingPath -Recurse -Force
  }
  if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
  }
  if ($activationSucceeded -and $backupCreated -and (Test-Path -LiteralPath $backupPath)) {
    Remove-Item -LiteralPath $backupPath -Recurse -Force
  }
  if ($PSCommandPath -and (Test-Path -LiteralPath $PSCommandPath)) {
    Remove-Item -LiteralPath $PSCommandPath -Force -ErrorAction SilentlyContinue
  }
}
''';
}
