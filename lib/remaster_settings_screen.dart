import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'organizer_settings.dart';
import 'calendar_store.dart';

class RemasterSettingsScreen extends StatelessWidget {
  const RemasterSettingsScreen({
    super.key,
    required this.appVersion,
    required this.syncStatus,
    required this.themeMode,
    required this.onThemeMode,
    required this.onLegacy,
    this.name,
    this.avatarUrl,
    this.onSignOut,
    this.onCheckForUpdate,
    this.updateCheckStatus,
    this.calendarConnected = false,
    this.calendarConnecting = false,
    this.calendarStatus = CalendarConnectionStatus.disconnected,
    this.calendarCachedEventCount = 0,
    this.calendarLastSyncedAt,
    this.onConnectCalendar,
    this.onChooseCalendars,
    this.onRefreshCalendar,
    this.onDisconnectCalendar,
    this.onManageTaskCategories,
    this.organizerSettings = const OrganizerSettings(),
    this.onOrganizerSettings,
    this.onTestReminder,
    this.notificationPermissionGranted,
    this.onOpenNotificationSettings,
  });

  final String appVersion;
  final String syncStatus;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeMode;
  final VoidCallback onLegacy;
  final String? name, avatarUrl;
  final VoidCallback? onSignOut;
  final Future<void> Function()? onCheckForUpdate;
  final ValueListenable<String>? updateCheckStatus;
  final bool calendarConnected;
  final bool calendarConnecting;
  final CalendarConnectionStatus calendarStatus;
  final int calendarCachedEventCount;
  final DateTime? calendarLastSyncedAt;
  final VoidCallback? onConnectCalendar,
      onChooseCalendars,
      onRefreshCalendar,
      onDisconnectCalendar;
  final VoidCallback? onManageTaskCategories;
  final OrganizerSettings organizerSettings;
  final ValueChanged<OrganizerSettings>? onOrganizerSettings;
  final VoidCallback? onTestReminder;
  final bool? notificationPermissionGranted;
  final Future<void> Function()? onOpenNotificationSettings;

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
                Text(
                  'Synchronizacja',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
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
                Text(
                  'Aktualizacje',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _UpdateSettingsCard(
                  appVersion: appVersion,
                  onCheckForUpdate: onCheckForUpdate,
                  status: updateCheckStatus,
                ),
                const SizedBox(height: 24),
                Text(
                  'Przypomnienia',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _ReminderSettingsCard(
                  settings: organizerSettings,
                  onChanged: onOrganizerSettings,
                  onTest: onTestReminder,
                  notificationPermissionGranted: notificationPermissionGranted,
                  onOpenNotificationSettings: onOpenNotificationSettings,
                ),
                const SizedBox(height: 24),
                Text(
                  'Google Calendar',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _calendarStatusIcon(
                                calendarStatus,
                                connecting: calendarConnecting,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _calendarStatusTitle(
                                  calendarStatus,
                                  connecting: calendarConnecting,
                                ),
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _calendarStatusDescription(
                            calendarStatus,
                            connecting: calendarConnecting,
                            cachedEventCount: calendarCachedEventCount,
                          ),
                        ),
                        if (calendarLastSyncedAt != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Ostatnia synchronizacja: ${_calendarSyncLabel(calendarLastSyncedAt!)}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (!calendarConnected && !calendarConnecting)
                              FilledButton.icon(
                                onPressed: onConnectCalendar,
                                icon: const Icon(Icons.link_rounded),
                                label: Text(
                                  calendarStatus ==
                                              CalendarConnectionStatus
                                                  .expired ||
                                          calendarStatus ==
                                              CalendarConnectionStatus.offline
                                      ? 'Połącz ponownie'
                                      : 'Połącz Google Calendar',
                                ),
                              ),
                            if (calendarConnected && !calendarConnecting)
                              OutlinedButton.icon(
                                onPressed: onChooseCalendars,
                                icon: const Icon(
                                  Icons.calendar_view_month_rounded,
                                ),
                                label: const Text('Wybierz kalendarze'),
                              ),
                            if (calendarConnected)
                              OutlinedButton.icon(
                                onPressed: onRefreshCalendar,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Odśwież'),
                              ),
                            if (calendarConnected)
                              TextButton.icon(
                                onPressed: onDisconnectCalendar,
                                icon: const Icon(Icons.link_off_rounded),
                                label: const Text('Odłącz'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Zadania', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.category_outlined),
                    title: const Text('Kategorie zadań'),
                    subtitle: const Text(
                      'Twórz własne kategorie, kolory i emoji.',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: onManageTaskCategories,
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
                if (onSignOut != null) ...[
                  const SizedBox(height: 24),
                  Text('Konto', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: Icon(Icons.logout_rounded, color: scheme.error),
                      title: Text(
                        'Wyloguj się',
                        style: TextStyle(color: scheme.error),
                      ),
                      onTap: onSignOut,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReminderSettingsCard extends StatelessWidget {
  const _ReminderSettingsCard({
    required this.settings,
    this.onChanged,
    this.onTest,
    this.notificationPermissionGranted,
    this.onOpenNotificationSettings,
  });

  final OrganizerSettings settings;
  final ValueChanged<OrganizerSettings>? onChanged;
  final VoidCallback? onTest;
  final bool? notificationPermissionGranted;
  final Future<void> Function()? onOpenNotificationSettings;

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: settings.dailyPlanHour,
        minute: settings.dailyPlanMinute,
      ),
      helpText: 'Godzina planu dnia',
      cancelText: 'Anuluj',
      confirmText: 'Ustaw',
    );
    if (picked == null) return;
    onChanged?.call(
      _copy(dailyPlanHour: picked.hour, dailyPlanMinute: picked.minute),
    );
  }

  OrganizerSettings _copy({
    bool? dailyPlanEnabled,
    int? dailyPlanHour,
    int? dailyPlanMinute,
    int? overdueReminderIntervalMinutes,
  }) => OrganizerSettings(
    defaultReminderMinutes: settings.defaultReminderMinutes,
    defaultSnoozeMinutes: settings.defaultSnoozeMinutes,
    weeklyReviewHour: settings.weeklyReviewHour,
    weeklyReviewMinute: settings.weeklyReviewMinute,
    dailyPlanEnabled: dailyPlanEnabled ?? settings.dailyPlanEnabled,
    dailyPlanHour: dailyPlanHour ?? settings.dailyPlanHour,
    dailyPlanMinute: dailyPlanMinute ?? settings.dailyPlanMinute,
    overdueReminderIntervalMinutes:
        overdueReminderIntervalMinutes ??
        settings.overdueReminderIntervalMinutes,
  );

  @override
  Widget build(BuildContext context) {
    final enabled = settings.dailyPlanEnabled;
    final time =
        '${settings.dailyPlanHour.toString().padLeft(2, '0')}:${settings.dailyPlanMinute.toString().padLeft(2, '0')}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Dzienny plan'),
              subtitle: Text(
                enabled
                    ? 'Przypomnę o planie o $time'
                    : 'Wyłączone domyślnie — włącz, gdy tego potrzebujesz.',
              ),
              value: enabled,
              onChanged: onChanged == null
                  ? null
                  : (value) => onChanged!(_copy(dailyPlanEnabled: value)),
            ),
            if (enabled)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_rounded),
                title: const Text('Godzina przypomnienia'),
                trailing: TextButton(
                  onPressed: onChanged == null
                      ? null
                      : () => _pickTime(context),
                  child: Text(time),
                ),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Zaległe zadania'),
              subtitle: const Text('Jak często ponawiać przypomnienie'),
              trailing: DropdownButton<int>(
                value: settings.overdueReminderIntervalMinutes,
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Wyłączone')),
                  DropdownMenuItem(value: 30, child: Text('30 min')),
                  DropdownMenuItem(value: 60, child: Text('1 godz.')),
                  DropdownMenuItem(value: 120, child: Text('2 godz.')),
                ],
                onChanged: onChanged == null
                    ? null
                    : (value) {
                        if (value != null) {
                          onChanged!(
                            _copy(overdueReminderIntervalMinutes: value),
                          );
                        }
                      },
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onTest,
                icon: const Icon(Icons.send_outlined),
                label: const Text('Wyślij test'),
              ),
            ),
            if (notificationPermissionGranted == false)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.notifications_off_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: const Text('Powiadomienia są zablokowane'),
                subtitle: const Text(
                  'Włącz je w ustawieniach systemu, aby alarmy działały.',
                ),
                trailing: TextButton(
                  onPressed: onOpenNotificationSettings,
                  child: const Text('Ustawienia'),
                ),
              ),
          ],
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

IconData _calendarStatusIcon(
  CalendarConnectionStatus status, {
  required bool connecting,
}) {
  if (connecting || status == CalendarConnectionStatus.connecting) {
    return Icons.sync_rounded;
  }
  return switch (status) {
    CalendarConnectionStatus.connected => Icons.event_available_rounded,
    CalendarConnectionStatus.offline => Icons.cloud_off_rounded,
    CalendarConnectionStatus.expired => Icons.lock_clock_outlined,
    CalendarConnectionStatus.disconnected => Icons.event_outlined,
    CalendarConnectionStatus.connecting => Icons.sync_rounded,
  };
}

String _calendarStatusTitle(
  CalendarConnectionStatus status, {
  required bool connecting,
}) {
  if (connecting || status == CalendarConnectionStatus.connecting) {
    return 'Łączenie z Google Calendar…';
  }
  return switch (status) {
    CalendarConnectionStatus.connected => 'Kalendarz połączony',
    CalendarConnectionStatus.offline => 'Kalendarz offline',
    CalendarConnectionStatus.expired => 'Połączenie z Calendar wygasło',
    CalendarConnectionStatus.disconnected => 'Kalendarz nie jest połączony',
    CalendarConnectionStatus.connecting => 'Łączenie z Google Calendar…',
  };
}

String _calendarStatusDescription(
  CalendarConnectionStatus status, {
  required bool connecting,
  required int cachedEventCount,
}) {
  if (connecting || status == CalendarConnectionStatus.connecting) {
    return 'Po powrocie z Chrome aplikacja pobierze listę kalendarzy. Nie zamykaj jej w trakcie.';
  }
  return switch (status) {
    CalendarConnectionStatus.connected =>
      'Wydarzenia są widoczne jako blokady czasu w widoku Tydzień.',
    CalendarConnectionStatus.offline =>
      cachedEventCount > 0
          ? 'Pokazuję $cachedEventCount zapisanych blokad offline. Połącz ponownie, aby je odświeżyć.'
          : 'Brak połączenia z Google. Połącz ponownie, aby pobrać wydarzenia.',
    CalendarConnectionStatus.expired => 'Google wymaga ponownego połączenia. Zapisane wydarzenia pozostają na tym urządzeniu.',
    CalendarConnectionStatus.disconnected =>
      cachedEventCount > 0
          ? 'Masz $cachedEventCount zapisanych blokad offline. Połącz ponownie, aby je odświeżyć.'
          : 'Połącz tylko do odczytu — aplikacja nie zmieni wydarzeń w Google.',
    CalendarConnectionStatus.connecting => 'Po powrocie z Chrome aplikacja pobierze listę kalendarzy. Nie zamykaj jej w trakcie.',
  };
}

String _calendarSyncLabel(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

class _Avatar extends StatelessWidget {
  const _Avatar({this.name, this.avatarUrl});
  final String? name, avatarUrl;

  @override
  Widget build(BuildContext context) {
    final initial = (name?.trim().isNotEmpty ?? false)
        ? name!.trim()[0].toUpperCase()
        : '?';
    return CircleAvatar(
      radius: 24,
      foregroundImage: avatarUrl == null || avatarUrl!.isEmpty
          ? null
          : NetworkImage(avatarUrl!),
      child: Text(initial),
    );
  }
}

class _UpdateSettingsCard extends StatefulWidget {
  const _UpdateSettingsCard({
    required this.appVersion,
    required this.onCheckForUpdate,
    required this.status,
  });

  final String appVersion;
  final Future<void> Function()? onCheckForUpdate;
  final ValueListenable<String>? status;

  @override
  State<_UpdateSettingsCard> createState() => _UpdateSettingsCardState();
}

class _UpdateSettingsCardState extends State<_UpdateSettingsCard> {
  bool _checking = false;

  Future<void> _check() async {
    final callback = widget.onCheckForUpdate;
    if (callback == null || _checking) return;
    setState(() => _checking = true);
    try {
      await callback();
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.system_update_alt_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Wersja aplikacji',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(widget.appVersion),
            ],
          ),
          const SizedBox(height: 10),
          _StatusText(status: widget.status),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: widget.onCheckForUpdate == null || _checking
                ? null
                : _check,
            icon: _checking
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            label: Text(_checking ? 'Sprawdzanie…' : 'Sprawdź aktualizacje'),
          ),
        ],
      ),
    ),
  );
}

class _StatusText extends StatelessWidget {
  const _StatusText({required this.status});

  final ValueListenable<String>? status;

  @override
  Widget build(BuildContext context) {
    final listenable = status;
    if (listenable == null) {
      return Text(
        'Sprawdź, czy masz najnowszą wersję.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return ValueListenableBuilder<String>(
      valueListenable: listenable,
      builder: (context, value, _) => Text(
        value.isEmpty ? 'Sprawdź, czy masz najnowszą wersję.' : value,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
