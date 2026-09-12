import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'update_service.dart';

class UpdateGate extends StatefulWidget {
  UpdateGate({
    required this.child,
    required this.currentVersion,
    required this.checkForUpdate,
    super.key,
    UpdatePlatform? platform,
    Future<bool> Function(Uri url)? openDownload,
  }) : platform = platform ?? _devicePlatform,
       openDownload = openDownload ?? _openInBrowser;

  final Widget child;
  final String currentVersion;
  final Future<ReleaseInfo?> Function() checkForUpdate;
  final UpdatePlatform platform;
  final Future<bool> Function(Uri url) openDownload;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  ReleaseInfo? _release;
  bool _dismissed = false;

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
                    child: Row(
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
                          onPressed: () async {
                            final url = release.downloadUrlFor(widget.platform);
                            if (url != null) await widget.openDownload(url);
                          },
                          child: const Text('Pobierz'),
                        ),
                        IconButton(
                          tooltip: 'Zamknij informację o aktualizacji',
                          onPressed: () => setState(() => _dismissed = true),
                          icon: const Icon(Icons.close_rounded),
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
