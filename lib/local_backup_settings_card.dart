import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'local_backup_manager.dart';

class LocalBackupSettingsCard extends StatefulWidget {
  const LocalBackupSettingsCard({
    super.key,
    required this.manager,
    required this.ownerId,
    this.onRestored,
    this.onSettingsChanged,
  });

  final LocalBackupManager manager;
  final String ownerId;
  final Future<void> Function()? onRestored;
  final VoidCallback? onSettingsChanged;

  @override
  State<LocalBackupSettingsCard> createState() => _LocalBackupSettingsCardState();
}

class _LocalBackupSettingsCardState extends State<LocalBackupSettingsCard> {
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run(() => widget.manager.load(widget.ownerId));
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _configure() async {
    final manager = widget.manager;
    final folder = Platform.isAndroid
        ? await manager.storage.chooseFolder()
        : await FilePicker.getDirectoryPath(dialogTitle: 'Wybierz folder kopii Dniówki');
    if (folder == null || !mounted) return;
    var encrypted = true;
    final password = TextEditingController();
    final result = await showDialog<(bool, String?)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Automatyczna kopia lokalna'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Wybierz zabezpieczenie kopii. Hasło będzie potrzebne do przywrócenia po zmianie urządzenia lub ponownej instalacji.'),
                RadioGroup<bool>(
                  groupValue: encrypted,
                  onChanged: (value) => setDialogState(() => encrypted = value!),
                  child: const Column(children: [
                    RadioListTile<bool>(
                      title: Text('Kopia z hasłem (zalecane)'),
                      value: true,
                    ),
                    RadioListTile<bool>(
                      title: Text('Kopia bez hasła'),
                      value: false,
                    ),
                  ]),
                ),
                if (encrypted)
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Hasło kopii (min. 10 znaków)'),
                  )
                else
                  const Text('Uwaga: każdy z dostępem do folderu może przeczytać Twoje zadania, notatki i dane finansowe.'),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anuluj')),
            FilledButton(
              onPressed: () {
                if (encrypted && password.text.length < 10) return;
                Navigator.pop(context, (encrypted, encrypted ? password.text : null));
              },
              child: const Text('Włącz i zapisz'),
            ),
          ],
        ),
      ),
    );
    password.dispose();
    if (result == null) return;
    await _run(() async {
      await manager.configure(
        ownerId: widget.ownerId, folder: folder, enabled: true,
        password: result.$2,
      );
      widget.onSettingsChanged?.call();
      await manager.createNow(widget.ownerId);
    });
  }

  Future<void> _restore() async {
    final backups = await widget.manager.listBackups();
    if (!mounted) return;
    if (backups.isEmpty) {
      setState(() => _error = 'Nie znaleziono kopii w wybranym folderze.');
      return;
    }
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Wybierz kopię'),
        children: [for (final name in backups)
          SimpleDialogOption(onPressed: () => Navigator.pop(context, name), child: Text(name))],
      ),
    );
    if (selected == null || !mounted) return;
    final password = TextEditingController();
    final enteredPassword = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hasło kopii'),
        content: TextField(
          controller: password,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Pozostaw puste, jeśli kopia nie ma hasła'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anuluj')),
          FilledButton(onPressed: () => Navigator.pop(context, password.text), child: const Text('Podgląd')),
        ],
      ),
    );
    password.dispose();
    if (enteredPassword == null) return;
    await _run(() async {
      final snapshot = await widget.manager.preview(
        selected, widget.ownerId,
        password: enteredPassword.isEmpty ? null : enteredPassword,
      );
      if (!mounted) return;
      final values = snapshot['preferences'] as Map? ?? const {};
      final files = snapshot['files'] as Map? ?? const {};
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Przywrócić kopię?'),
          content: Text(
            'Utworzono: ${snapshot['createdAt'] ?? 'nieznana data'}\n'
            '${values.length} zestawów danych, ${files.length} plików.\n\n'
            'Bieżące dane lokalne zostaną zastąpione. Przed przywróceniem utworzymy kopię bezpieczeństwa.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anuluj')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Przywróć')),
          ],
        ),
      );
      if (accepted != true) return;
      await widget.manager.restore(
        selected, widget.ownerId,
        password: enteredPassword.isEmpty ? null : enteredPassword,
      );
      await widget.onRestored?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.manager.settings;
    final date = settings.lastSuccessfulAt;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Automatyczna kopia lokalna'),
              subtitle: Text(settings.folder == null
                  ? 'Wyłączona · wybierz folder, aby rozpocząć'
                  : 'Folder: ${settings.folder}'),
              value: settings.enabled,
              onChanged: _busy ? null : (enabled) {
                if (enabled && settings.folder == null) {
                  _configure();
                } else {
                  _run(() async {
                    await widget.manager.setEnabled(widget.ownerId, enabled);
                    widget.onSettingsChanged?.call();
                  });
                }
              },
            ),
            Text('Ostatnia udana kopia: ${date == null ? 'brak' : DateFormat('dd.MM.yyyy HH:mm').format(date.toLocal())}'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton(onPressed: _busy ? null : _configure, child: const Text('Wybierz folder / hasło')),
              OutlinedButton(onPressed: _busy || settings.folder == null ? null : () => _run(() async { await widget.manager.createNow(widget.ownerId); }), child: const Text('Utwórz teraz')),
              OutlinedButton(onPressed: _busy || settings.folder == null ? null : _restore, child: const Text('Przywróć kopię')),
            ]),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
      ),
    );
  }
}
