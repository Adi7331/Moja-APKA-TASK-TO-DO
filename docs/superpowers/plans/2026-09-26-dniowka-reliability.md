# Dniówka Reliability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wdrożyć zatwierdzony projekt aktualizacji Windows, lokalnych zbiorczych przypomnień, poprawnego Google Calendar, kategorii nullable oraz stylu zadań.

**Architecture:** Zachować Flutterowy model offline-first i dodać zmiany do istniejących modeli, store/outbox oraz punktów wejścia UI. Systemowe przypomnienia i aktualizator pozostają usługami specyficznymi dla platformy; logika kwalifikacji zadań, okna ciszy, klasyfikacji API i aktualizacji pozostaje testowalna w Dart poza UI.

**Tech Stack:** Flutter/Dart, SharedPreferences, flutter_local_notifications, Flutter Secure Storage, Supabase/Postgres, PowerShell helper dla Windows.

**Spec:** `docs/superpowers/specs/2026-09-26-dniowka-reliability-design.md`

## Global Constraints

- Domyślnie przypomnienia są wyłączone; po włączeniu: 60 min i 09:00–21:00.
- Przypomnienia dotyczą tylko niewykonanych zadań na dziś i zaległych; jeden digest z maksymalnie 3 tytułami.
- Ustawienia przypomnień są lokalne dla urządzenia; autostart Windows jest osobny i domyślnie wyłączony.
- `categoryId == null` oznacza „Bez kategorii”; null musi zostać wysłany do Supabase.
- Nowe pola wyglądu są wstecznie kompatybilne, a stare rekordy są neutralne.
- Tokeny OAuth pozostają w bezpiecznym magazynie urządzenia; nigdy w logach ani Supabase.
- Windows updater zachowuje poprzednią wersję aż do potwierdzonego startu nowej.
- Build/test tymczasowy lokować na F:; zachować istniejące pliki i artefakty użytkownika.

## Review Focus

- Pusty/null `category_id` przy aktualizacji istniejącego wiersza nie może zostać pominięty w payloadzie — test jawnego wyczyszczenia kategorii.
- Odpowiedzi Google 403 zawierają różne przyczyny — test `accessNotConfigured`, `insufficientPermissions` i limity oddzielnie.
- Zakres godzin przez północ i uśpienie nie mogą generować alarmów poza oknem ani lawiny — test granic i planowania następnego slotu.
- Nowa wersja może nie wystartować po podmianie — test braku potwierdzenia oraz przywrócenia backupu.
- Zamknięcie okna Windows przy włączonych przypomnieniach nie może zakończyć procesu — test tray lifecycle/integration where supported.

---

### Task 1: Task categories and visual metadata

**Files:** `lib/task_item.dart`, `lib/task_editor.dart`, `lib/task_sync_service.dart`, `lib/task_view.dart`, task row/card widgets, `supabase/schema.sql` plus migration generated with Supabase CLI if installed; tests in `test/task_item_test.dart`, `test/task_editor_test.dart`, `test/task_view_test.dart`, sync/outbox tests.

**Interfaces:** `TaskItem` and `TaskDraft` expose nullable `emoji` and `colorKey`. `categoryId` is the source of truth; user-facing label resolves to “Bez kategorii” for null.

- [ ] Add failing serialization tests for nullable category, emoji and color in storage/Supabase/outbox.
- [ ] Add failing tests for inbox filtering independent of category and for editor selection of no category.
- [ ] Implement model/draft, explicit-null sync payload, neutral legacy defaults and six-color metadata.
- [ ] Add editor appearance controls and apply metadata to task row, Start and weekly task cards in light/dark themes.
- [ ] Generate a nullable-column migration, preserve RLS, run focused tests and existing model/view tests.

### Task 2: Google Calendar error diagnosis and connection status

**Files:** `lib/google_calendar_service.dart`, calendar status model/settings UI and app connection flow; `test/google_calendar_service_test.dart` and settings tests.

**Interfaces:** `CalendarTransportException` retains status and sanitized API reason; a classifier maps expired/auth, missing scope, API disabled, account restrictions, rate limiting and offline. Connection state is successful only after `loadCalendars` succeeds.

- [ ] Add failing tests for JSON error parsing and status mappings for 401, 403 and 429.
- [ ] Add failing integration-flow test proving failed calendar list does not store connected state.
- [ ] Implement bounded response parsing and specific Polish guidance; preserve offline cache and secure credential storage.
- [ ] Run calendar/settings/auth tests; verify no token or raw response payload appears in UI/log output.

### Task 3: Configurable aggregated task reminders

**Files:** `lib/organizer_settings.dart`, reminder scheduling/service, `lib/main.dart`, `lib/remaster_settings_screen.dart`, Android receivers/manifest, Windows runner/tray lifecycle; tests for settings, scheduler, service and UI.

**Interfaces:** Device-local settings add enabled, interval (15–1440), start/end local minutes, platform toggle/autostart as supported. Pure reminder selector returns open due-today/overdue tasks, and digest formatter yields count plus at most three titles.

- [ ] Write failing tests for defaults, persistence, custom interval, overnight hours and task eligibility.
- [ ] Write failing tests that one digest replaces recurring per-task overdue alerts but preserves one-shot task alarms.
- [ ] Implement shared pure scheduling logic and settings UI including test notification.
- [ ] Implement Android reschedule-on-boot and fresh local-state digest; cancel/recompute after task/settings/logout events.
- [ ] Implement Windows tray stay-open/menu behavior and opt-in startup; ensure sleep does not replay missed digests.
- [ ] Run focused tests and platform runner tests; manually verify Android permissions and Windows tray on available host.

### Task 4: Transactional Windows one-click updater

**Files:** `lib/update_gate.dart`, `lib/windows_zip_update_installer.dart`, update UI/service, Windows helper scripts/runner startup acknowledgement; `test/update_gate_test.dart` and `test/windows_zip_update_installer_test.dart`.

**Interfaces:** Installer reports download/preparation/launch phases, validates archive and target executable, persists outcome, and waits for helper readiness before app exit. New process acknowledges its first healthy launch before backup cleanup.

- [ ] Add failing tests for failed download, invalid ZIP, helper startup timeout, rollback and success acknowledgement.
- [ ] Add failing update-gate tests for progress/errors and not exiting before ready handshake.
- [ ] Implement helper protocol, safe diagnostic log, staged swap, backup retention, rollback and next-launch error notice.
- [ ] Validate local data/outbox remain untouched; run updater test suite and Windows integration test with two local package versions.

### Task 5: Integration, migration and release verification

**Files:** generated Supabase migration, `supabase/schema.sql`, tests and build configuration if needed.

- [ ] Verify the migration applies to an empty schema and an existing schema with RLS/owner policies intact (local Supabase if available; otherwise SQL static checks and record the limitation).
- [ ] Run `flutter analyze` and the full test suite with temporary paths on F:.
- [ ] Build Windows and a signed Android APK when release signing material is available; do not expose or print secret values.
- [ ] Run an end-to-end update from current package to candidate and verify rollback by intentionally preventing first-start acknowledgement.
- [ ] Summarize delivered platform behavior, test/build outcomes and any remaining device-only checks; do not push or publish without a separate user request.
