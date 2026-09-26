import 'dart:io';

class WindowsAutostart {
  const WindowsAutostart();

  static const _runKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const _valueName = 'Dniowka';

  Future<void> setEnabled(bool enabled, {String? executablePath}) async {
    if (!Platform.isWindows) return;
    if (enabled) {
      final path = executablePath ?? Platform.resolvedExecutable;
      final result = await Process.run('reg.exe', [
        'add',
        _runKey,
        '/v',
        _valueName,
        '/t',
        'REG_SZ',
        '/d',
        '"$path" --background',
        '/f',
      ]);
      if (result.exitCode != 0) {
        throw ProcessException('reg.exe', const [
          'add',
        ], 'Nie udało się włączyć autostartu.');
      }
    } else {
      await Process.run('reg.exe', ['delete', _runKey, '/v', _valueName, '/f']);
    }
  }
}
