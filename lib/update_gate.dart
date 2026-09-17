import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'android_zip_update_installer.dart';
import 'update_service.dart';
import 'windows_zip_update_installer.dart';

class UpdateGate extends StatefulWidget {
  UpdateGate({
    required this.child,
    required this.currentVersion,
    required this.checkForUpdate,
    super.key,
    UpdatePlatform? platform,
    Future<bool> Function(Uri url)? openDownload,
    this.startUpdate,
    this.onWindowsHelperStarted,
    void Function(int status)? exitApplication,
    int? parentPid,
    String? executablePath,
  }) : platform = platform ?? _devicePlatform,
       openDownload = openDownload ?? _openInBrowser,
       exitApplication = exitApplication ?? exit,
       parentPid = parentPid ?? pid,
       executablePath = executablePath ?? Platform.resolvedExecutable;

  final Widget child;
  final String currentVersion;
  final Future<ReleaseInfo?> Function() checkForUpdate;
  final UpdatePlatform platform;
  final Future<bool> Function(Uri url) openDownload;
  final Future<WindowsUpdateStartResult> Function(
    ReleaseInfo release,
    UpdatePlatform platform,
  )?
  startUpdate;
  final VoidCallback? onWindowsHelperStarted;
  final void Function(int status) exitApplication;
  final int parentPid;
  final String executablePath;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  ReleaseInfo? _release;
  bool _dismissed = false;
  bool _downloading = false;
  bool _windowsUpdateFailed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_check());
  }

  Future<void> _check() async {
    final release = await widget.checkForUpdate();
    if (!mounted || release?.downloadUrlFor(widget.platform) == null) return;
    setState(() => _release = release);
  }

  @override
  Widget build(BuildContext context) {
    final release = _release;
    if (release == null || _dismissed) return widget.child;
    return Stack(
      children: [
        widget.child,
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.system_update_alt_rounded),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Dostępna aktualizacja ${release.version}',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                            TextButton(
                              onPressed: _downloading
                                  ? null
                                  : () async {
                                      setState(() => _downloading = true);
                                      final result =
                                          await (widget.startUpdate?.call(
                                                release,
                                                widget.platform,
                                              ) ??
                                              _startDefaultUpdate(
                                                release,
                                                widget.platform,
                                                widget.openDownload,
                                                parentPid: widget.parentPid,
                                                executablePath:
                                                    widget.executablePath,
                                              ));
                                      if (!mounted) return;
                                      setState(() {
                                        _downloading = false;
                                        _windowsUpdateFailed =
                                            widget.platform ==
                                                UpdatePlatform.windows &&
                                            !result.started;
                                      });
                                      if (!result.started) {
                                        ScaffoldMessenger.of(this.context)
                                            .showSnackBar(
                                              SnackBar(
                                                content: Text(result.message),
                                              ),
                                            );
                                      } else if (widget.platform ==
                                          UpdatePlatform.windows) {
                                        widget.onWindowsHelperStarted?.call();
                                        widget.exitApplication(0);
                                      }
                                    },
                              child: Text(
                                _downloading
                                    ? 'Pobieranie…'
                                    : 'Aktualizuj teraz',
                              ),
                            ),
                            IconButton(
                              tooltip: 'Zamknij informację o aktualizacji',
                              onPressed: () =>
                                  setState(() => _dismissed = true),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        if (widget.platform == UpdatePlatform.windows &&
                            _windowsUpdateFailed)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _downloading
                                  ? null
                                  : () async {
                                      setState(() => _downloading = true);
                                      await widget.openDownload(
                                        release.windowsUrl!,
                                      );
                                      if (!mounted) return;
                                      setState(() => _downloading = false);
                                    },
                              child: const Text('Pobierz ręcznie'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

UpdatePlatform get _devicePlatform {
  if (Platform.isAndroid) return UpdatePlatform.android;
  if (Platform.isWindows) return UpdatePlatform.windows;
  return UpdatePlatform.other;
}

Future<bool> _openInBrowser(Uri url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);

Future<WindowsUpdateStartResult> _startDefaultUpdate(
  ReleaseInfo release,
  UpdatePlatform platform,
  Future<bool> Function(Uri url) openDownload, {
  required int parentPid,
  required String executablePath,
}) async {
  if (platform == UpdatePlatform.android &&
      release.androidPackage == UpdatePackage.zip) {
    final started = await AndroidZipUpdateInstaller().start(release.androidUrl);
    return started
        ? const WindowsUpdateStartResult.started()
        : const WindowsUpdateStartResult.failed(
            'Nie udało się rozpocząć aktualizacji.',
          );
  }
  if (platform == UpdatePlatform.windows) {
    final windowsUrl = release.windowsUrl;
    if (windowsUrl == null) {
      return const WindowsUpdateStartResult.failed(
        'Nie znaleziono pliku aktualizacji dla Windows.',
      );
    }
    return WindowsZipUpdateInstaller().start(
      windowsUrl,
      parentPid: parentPid,
      executablePath: executablePath,
    );
  }
  final url = release.downloadUrlFor(platform);
  if (url == null) {
    return const WindowsUpdateStartResult.failed(
      'Nie znaleziono pliku aktualizacji.',
    );
  }
  final opened = await openDownload(url);
  return opened
      ? const WindowsUpdateStartResult.started()
      : const WindowsUpdateStartResult.failed(
          'Nie udało się rozpocząć aktualizacji.',
        );
}
