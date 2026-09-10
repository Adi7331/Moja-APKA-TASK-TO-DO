import 'package:flutter/material.dart';

class RemasterSettingsScreen extends StatelessWidget {
  const RemasterSettingsScreen({
    super.key,
    required this.syncStatus,
    required this.themeMode,
    required this.onThemeMode,
    required this.onLegacy,
    this.name,
    this.avatarUrl,
    this.onSignOut,
  });

  final String syncStatus;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeMode;
  final VoidCallback onLegacy;
  final String? name, avatarUrl;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Wróć',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Konto i ustawienia'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
              children: [
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(20),
                    leading: _Avatar(name: name, avatarUrl: avatarUrl),
                    title: Text(name ?? 'Twoja przestrzeń'),
                    subtitle: const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('Konto i dane pozostają tylko Twoje.'),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Synchronizacja', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: Icon(
                      syncStatus.contains('Błąd')
                          ? Icons.cloud_off_rounded
                          : syncStatus == 'Lokalnie'
                              ? Icons.offline_pin_outlined
                              : Icons.cloud_done_outlined,
                    ),
                    title: Text(syncStatus),
                    subtitle: Text(
                      syncStatus == 'Lokalnie'
                          ? 'Dane są zapisane na tym urządzeniu.'
                          : 'Dane są gotowe na pozostałych urządzeniach.',
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Wygląd', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final option in ThemeMode.values)
                          ChoiceChip(
                            label: Text(_themeLabel(option)),
                            selected: themeMode == option,
                            onSelected: (_) => onThemeMode(option),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Aplikacja', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.history_rounded),
                        title: const Text('Wróć do poprzedniego wyglądu'),
                        subtitle: const Text('Nowy interfejs możesz ponownie włączyć później.'),
                        onTap: onLegacy,
                      ),
                      if (onSignOut != null) ...[
                        Divider(height: 1, color: scheme.outlineVariant),
                        ListTile(
                          leading: Icon(Icons.logout_rounded, color: scheme.error),
                          title: Text('Wyloguj się', style: TextStyle(color: scheme.error)),
                          onTap: onSignOut,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _themeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.system => 'Systemowy',
  ThemeMode.light => 'Jasny',
  ThemeMode.dark => 'Ciemny',
};

class _Avatar extends StatelessWidget {
  const _Avatar({this.name, this.avatarUrl});
  final String? name, avatarUrl;

  @override
  Widget build(BuildContext context) {
    final initial = (name?.trim().isNotEmpty ?? false) ? name!.trim()[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 24,
      foregroundImage: avatarUrl == null || avatarUrl!.isEmpty ? null : NetworkImage(avatarUrl!),
      child: Text(initial),
    );
  }
}
