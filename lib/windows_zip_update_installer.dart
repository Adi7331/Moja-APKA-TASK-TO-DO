import 'dart:convert';
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
    Future<bool> Function(File ready, File result, Duration timeout)?
    waitForHelperReady,
  }) : _downloadOverride = download,
       _applicationSupportDirectory =
           applicationSupportDirectory ?? getApplicationSupportDirectory,
       _fileExists = fileExists ?? _fileExistsOnDisk,
       _directoryWritable = directoryWritable ?? _writeDeleteProbe,
       _writeHelper = writeHelper ?? _writeHelperToDisk,
       _launchHelper = launchHelper ?? _launchDetachedPowerShell,
       _waitForHelperReady = waitForHelperReady ?? _waitForHelperReadyOnDisk;

  final Future<void> Function(Uri url, File destination)? _downloadOverride;
  final Future<Directory> Function() _applicationSupportDirectory;
  final Future<bool> Function(File file) _fileExists;
  final Future<bool> Function(Directory directory) _directoryWritable;
  final Future<void> Function(File file, String script) _writeHelper;
  final Future<void> Function(String executable, List<String> arguments)
  _launchHelper;
  final Future<bool> Function(File ready, File result, Duration timeout)
  _waitForHelperReady;

  Future<WindowsUpdateStartResult> start(
    Uri url, {
    required int parentPid,
    required String executablePath,
    bool? isWindows,
    void Function(int receivedBytes, int? totalBytes)? onProgress,
    Duration helperReadyTimeout = const Duration(seconds: 45),
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
    if (parentPid <= 0) {
      return const WindowsUpdateStartResult.failed(
        'Nieprawidłowy identyfikator procesu.',
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
      final updateId = DateTime.now().microsecondsSinceEpoch.toString();
      final readyFile = File(
        '${updatesDirectory.path}${Platform.pathSeparator}ready-$updateId',
      );
      final acknowledgementFile = File(
        '${updatesDirectory.path}${Platform.pathSeparator}started-$updateId',
      );
      final resultFile = File(
        '${updatesDirectory.path}${Platform.pathSeparator}result-$updateId.json',
      );
      final lastResultFile = File(
        '${updatesDirectory.path}${Platform.pathSeparator}last-update-result.json',
      );
      final helperFile = File(
        '${updatesDirectory.path}${Platform.pathSeparator}apply-windows-update.ps1',
      );
      await zipFile.parent.create(recursive: true);
      if (_downloadOverride != null) {
        await _downloadOverride(url, zipFile);
      } else {
        await _downloadPackage(url, zipFile, onProgress: onProgress);
      }
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
        '--ready-marker',
        readyFile.path,
        '--ack-marker',
        acknowledgementFile.path,
        '--result-file',
        resultFile.path,
        '--last-result-file',
        lastResultFile.path,
      ]);
      final ready = await _waitForHelperReady(
        readyFile,
        resultFile,
        helperReadyTimeout,
      );
      if (!ready) {
        final failure = await _readFailure(resultFile);
        return WindowsUpdateStartResult.failed(
          failure ?? 'Nie udało się przygotować plików aktualizacji przed zamknięciem aplikacji.',
        );
      }
      return const WindowsUpdateStartResult.started();
    } on Object catch (error) {
      return WindowsUpdateStartResult.failed(
        'Nie udało się przygotować aktualizacji: ${_safeError(error)}',
      );
    }
  }

  Future<String?> consumePreviousFailure() async {
    try {
      final support = await _applicationSupportDirectory();
      final updates = Directory(
        '${support.path}${Platform.pathSeparator}updates',
      );
      final result = File(
        '${updates.path}${Platform.pathSeparator}last-update-result.json',
      );
      final seen = File(
        '${updates.path}${Platform.pathSeparator}last-update-result-seen',
      );
      if (!await result.exists()) return null;
      final value = jsonDecode(await result.readAsString());
      if (value is! Map || value['status'] != 'failed') return null;
      final time = value['time'] as String?;
      if (time == null ||
          (await seen.exists() && await seen.readAsString() == time)) {
        return null;
      }
      await seen.writeAsString(time, flush: true);
      return value['message'] as String? ??
          'Przywrócono poprzednią wersję po błędzie aktualizacji.';
    } on Object {
      return null;
    }
  }

  static Future<bool> _waitForHelperReadyOnDisk(
    File readyFile,
    File resultFile,
    Duration timeout,
  ) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await readyFile.exists()) return true;
      if (await resultFile.exists()) return false;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return readyFile.exists();
  }

  static Future<String?> _readFailure(File resultFile) async {
    try {
      if (!await resultFile.exists()) return null;
      final result = jsonDecode(await resultFile.readAsString());
      if (result is Map && result['status'] == 'failed') {
        return result['message'] as String?;
      }
    } on Object {
      return null;
    }
    return null;
  }

  static String _safeError(Object error) {
    final text = error.toString().replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
    return text.length > 180 ? '${text.substring(0, 180)}…' : text;
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

  static Future<void> _downloadPackage(
    Uri url,
    File destination, {
    void Function(int receivedBytes, int? totalBytes)? onProgress,
  }) async {
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
      final totalBytes = response.contentLength > 0
          ? response.contentLength
          : null;
      final sink = destination.openWrite();
      var receivedBytes = 0;
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          onProgress?.call(receivedBytes, totalBytes);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
    } finally {
      client.close(force: true);
    }
  }

  static Future<void> _writeHelperToDisk(File file, String script) async {
    await file.parent.create(recursive: true);
    await file.writeAsBytes(encodePowerShellScript(script), flush: true);
  }

  static List<int> encodePowerShellScript(String script) => <int>[
    0xef,
    0xbb,
    0xbf,
    ...utf8.encode(script),
  ];

  static Future<void> _launchDetachedPowerShell(
    String executable,
    List<String> arguments,
  ) async {
    await Process.start(executable, arguments, mode: ProcessStartMode.detached);
  }

  static const _replacementScript = r'''param()

$ErrorActionPreference = 'Stop'
$helperArguments = [string[]]$args
function Get-RequiredArgument([string]$name) {
  $index = [Array]::IndexOf($helperArguments, $name)
  if ($index -lt 0 -or $index -ge ($helperArguments.Count - 1)) {
    throw "Brak wymaganego argumentu $name."
  }
  return [string]$helperArguments[$index + 1]
}

$parentPidValue = Get-RequiredArgument '--parent-pid'
$parsedParentPid = 0
if (![int]::TryParse($parentPidValue, [ref]$parsedParentPid) -or $parsedParentPid -le 0) {
  throw 'Nieprawidłowy identyfikator procesu.'
}
$parentPid = $parsedParentPid
$zip = Get-RequiredArgument '--zip'
$installDir = Get-RequiredArgument '--install-dir'
$exeName = Get-RequiredArgument '--exe-name'
$readyMarker = Get-RequiredArgument '--ready-marker'
$ackMarker = Get-RequiredArgument '--ack-marker'
$resultFile = Get-RequiredArgument '--result-file'
$lastResultFile = Get-RequiredArgument '--last-result-file'
$zipPath = [System.IO.Path]::GetFullPath($zip)
$installPath = [System.IO.Path]::GetFullPath($installDir)
$readyPath = [System.IO.Path]::GetFullPath($readyMarker)
$ackPath = [System.IO.Path]::GetFullPath($ackMarker)
$resultPath = [System.IO.Path]::GetFullPath($resultFile)
$lastResultPath = [System.IO.Path]::GetFullPath($lastResultFile)
$parentPath = [System.IO.Directory]::GetParent($installPath).FullName
$stagingPath = Join-Path -Path $parentPath -ChildPath ('.dzien-po-dniu-staging-' + [Guid]::NewGuid().ToString('N'))
$backupPath = $installPath + '-previous'
$stagingCreated = $false
$backupCreated = $false
$replacementActivated = $false
$activationSucceeded = $false
function Write-UpdateResult([string]$status, [string]$message) {
  $record = @{ status = $status; message = $message; time = [DateTimeOffset]::Now.ToString('o') } | ConvertTo-Json -Compress
  $temporary = $resultPath + '.tmp'
  [System.IO.File]::WriteAllText($temporary, $record, [System.Text.UTF8Encoding]::new($false))
  Move-Item -LiteralPath $temporary -Destination $resultPath -Force
  $lastTemporary = $lastResultPath + '.tmp'
  [System.IO.File]::WriteAllText($lastTemporary, $record, [System.Text.UTF8Encoding]::new($false))
  Move-Item -LiteralPath $lastTemporary -Destination $lastResultPath -Force
}

try {
  if (!(Test-Path -LiteralPath $zipPath -PathType Leaf)) { throw 'Nie znaleziono pobranego archiwum ZIP.' }
  if (!(Test-Path -LiteralPath $installPath -PathType Container)) {
    throw 'Katalog instalacji nie istnieje.'
  }
  if (Test-Path -LiteralPath $backupPath) {
    throw 'Istnieje poprzednia kopia aktualizacji wymagająca sprawdzenia.'
  }

  [System.IO.Directory]::CreateDirectory($stagingPath) | Out-Null
  $stagingCreated = $true
  Expand-Archive -LiteralPath $zipPath -DestinationPath $stagingPath -Force
  $stagedExe = Join-Path -Path $stagingPath -ChildPath $exeName
  if (!(Test-Path -LiteralPath $stagedExe -PathType Leaf)) {
    throw 'Archiwum aktualizacji nie zawiera pliku wykonywalnego.'
  }
  [System.IO.File]::WriteAllText($readyPath, 'ready', [System.Text.UTF8Encoding]::new($false))

  while (Get-Process -Id $parentPid -ErrorAction SilentlyContinue) {
    Start-Sleep -Milliseconds 250
  }

  Move-Item -LiteralPath $installPath -Destination $backupPath
  $backupCreated = $true
  Move-Item -LiteralPath $stagingPath -Destination $installPath
  $stagingCreated = $false
  $replacementActivated = $true

  $newProcess = Start-Process -PassThru -FilePath (Join-Path -Path $installPath -ChildPath $exeName) -WorkingDirectory $installPath -ArgumentList @('--dpp-update-ack=' + $ackPath)
  $ackDeadline = [DateTime]::UtcNow.AddSeconds(60)
  while (!(Test-Path -LiteralPath $ackPath) -and [DateTime]::UtcNow -lt $ackDeadline) {
    if ($newProcess.HasExited) { throw 'Nowa wersja zamknęła się przed potwierdzeniem uruchomienia.' }
    Start-Sleep -Milliseconds 250
  }
  if (!(Test-Path -LiteralPath $ackPath)) { throw 'Nowa wersja nie potwierdziła poprawnego uruchomienia.' }
  $activationSucceeded = $true
  Write-UpdateResult 'success' 'Aktualizacja została uruchomiona.'
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
  Write-UpdateResult 'failed' ([string]$_.Exception.Message)
}
finally {
  if ($stagingCreated -and (Test-Path -LiteralPath $stagingPath)) {
    Remove-Item -LiteralPath $stagingPath -Recurse -Force
  }
  if ($activationSucceeded -and (Test-Path -LiteralPath $zipPath)) {
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
