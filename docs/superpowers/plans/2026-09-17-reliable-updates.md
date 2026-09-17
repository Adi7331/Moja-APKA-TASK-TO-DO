# Reliable Application Updates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `v1.1.4` so Android accepts the in-app update and Windows can download, replace, and restart itself after one click.

**Architecture:** Keep release discovery in `UpdateService` and the cross-platform banner in `UpdateGate`. Add a Windows-only installer service with injected filesystem/process seams for tests; it downloads the existing signed GitHub ZIP, prepares a short-lived PowerShell helper, and exits only after the helper is launched. The release workflow derives Android `versionCode` from the semver tag rather than from GitHub’s run number.

**Tech Stack:** Flutter/Dart, `dart:io`, `path_provider`, Flutter widget tests, GitHub Actions Bash/PowerShell, signed Android APK releases.

**Spec:** `docs/superpowers/specs/2026-09-17-reliable-updates-design.md`

## Global Constraints

- Release tag format is exactly `vX.Y.Z`; `v1.1.4` maps to Android code `1_001_004` with `major * 1_000_000 + minor * 1_000 + patch`.
- Android keeps the system package installer; it must never silently install an APK.
- Tokens, Supabase data, and secrets must never be passed to or read by the Windows helper.
- Windows replacement must require a writable installation directory and must restore the prior directory if activation fails.
- Download sources remain HTTPS GitHub Release asset URLs validated by `ReleaseInfo`.
- All async update controls show progress, cannot be double-started, preserve 48 dp hit areas, and have semantic labels/tooltips.
- `v1.1.4` is the one final manual Windows installation; later Windows updates must be one click plus a restart.

---

## File structure

- `lib/windows_zip_update_installer.dart` — Windows ZIP download, writable-installation preflight, helper script construction and detached launch.
- `lib/update_gate.dart` — stateful update button text/error state and platform dispatch to Android or Windows installers.
- `lib/remaster_settings_screen.dart` — displayed app version plus explicit, non-destructive update check action.
- `lib/remaster_shell.dart` — passes the version/check action through to settings without owning update state.
- `lib/main.dart` — creates the one shared `UpdateService` closure and provides version/check action to the remaster shell.
- `.github/workflows/release.yml` — validates semver tags and calculates a monotonic Android build number.
- `test/windows_zip_update_installer_test.dart` — installer preflight, helper arguments and platform safety.
- `test/update_gate_test.dart` — Windows dispatch, busy state and failure message.
- `test/remaster_settings_screen_test.dart` — visible version and manual check callback.
- `test/release_workflow_test.dart` — semver validation and calculated Android build number in the workflow.

### Task 1: Make release versioning monotonic

**Files:**
- Modify: `.github/workflows/release.yml:39-49, 76-83`
- Modify: `test/release_workflow_test.dart:5-24`

**Interfaces:**
- Produces: `ANDROID_BUILD_NUMBER` from `vX.Y.Z`, passed to `flutter build apk --build-number`.
- Produces: immediate failing workflow exit for tags outside `^v[0-9]+\.[0-9]+\.[0-9]+$`.

- [ ] **Step 1: Write the failing workflow contract test**

  Add these expectations to `test/release_workflow_test.dart`:

  ```dart
  expect(workflow, contains("[[ \"$TAG\" =~ ^v[0-9]+\\.[0-9]+\\.[0-9]+$ ]]"));
  expect(workflow, contains('ANDROID_BUILD_NUMBER=$((major * 1000000 + minor * 1000 + patch))'));
  expect(workflow, contains('--build-number "$ANDROID_BUILD_NUMBER"'));
  expect(workflow, isNot(contains('--build-number "$GITHUB_RUN_NUMBER"')));
  ```

- [ ] **Step 2: Run the workflow contract test and verify it fails**

  Run: `..\\..\\.tooling\\flutter\\bin\\flutter.bat test --no-pub test/release_workflow_test.dart`

  Expected: FAIL because the workflow still uses `GITHUB_RUN_NUMBER` for Android.

- [ ] **Step 3: Implement semver parsing in the Android build step**

  In the `Build release APK` Bash step, use this exact sequence before `flutter pub get`:

  ```bash
  TAG="${{ inputs.tag || github.ref_name }}"
  if [[ ! "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Release tag must be vX.Y.Z; received: $TAG" >&2
    exit 1
  fi
  VERSION="${TAG#v}"
  IFS='.' read -r major minor patch <<< "$VERSION"
  ANDROID_BUILD_NUMBER=$((major * 1000000 + minor * 1000 + patch))
  ```

  Replace the APK build argument with `--build-number "$ANDROID_BUILD_NUMBER"`. In the Windows build step, add the same tag validation and retain the derived `VERSION` for `--build-name`; its build suffix may remain the GitHub run number.

- [ ] **Step 4: Run the workflow contract test and verify it passes**

  Run: `..\\..\\.tooling\\flutter\\bin\\flutter.bat test --no-pub test/release_workflow_test.dart`

  Expected: PASS.

- [ ] **Step 5: Commit the isolated release correction**

  ```powershell
  git add .github/workflows/release.yml test/release_workflow_test.dart
  git commit -m "fix: derive Android version code from release tag"
  ```

### Task 2: Add a testable Windows ZIP replacement launcher

**Files:**
- Create: `lib/windows_zip_update_installer.dart`
- Create: `test/windows_zip_update_installer_test.dart`

**Interfaces:**
- Produces: `WindowsUpdateStartResult { started, message }`.
- Produces: `Future<WindowsUpdateStartResult> WindowsZipUpdateInstaller.start(Uri url, {required int parentPid, required String executablePath, bool? isWindows})`.
- Consumes: a `.zip` `Uri`, current process ID, and `Platform.resolvedExecutable` supplied by `UpdateGate`.

- [ ] **Step 1: Write failing installer tests**

  Create tests that construct `WindowsZipUpdateInstaller` with injected `download`, `applicationSupportDirectory`, `fileExists`, `directoryWritable`, `writeHelper`, and `launchHelper` callbacks. Cover these exact assertions:

  ```dart
  expect(result.started, isFalse);
  expect(result.message, contains('tylko na Windows'));
  ```

  when `isWindows: false`; and, for a writable directory containing `dzien_po_dniu.exe`:

  ```dart
  expect(result.started, isTrue);
  expect(launchArguments, contains('--parent-pid'));
  expect(launchArguments, contains('4812'));
  expect(helperText, contains('Expand-Archive'));
  expect(helperText, contains('Move-Item'));
  ```

  Add a third test where `directoryWritable` returns false and assert no helper is launched plus a message containing `brak uprawnień`.

- [ ] **Step 2: Run the installer tests and verify they fail**

  Run: `..\\..\\.tooling\\flutter\\bin\\flutter.bat test --no-pub test/windows_zip_update_installer_test.dart`

  Expected: FAIL because `windows_zip_update_installer.dart` does not exist.

- [ ] **Step 3: Implement the installer with a narrow result type**

  Implement `WindowsUpdateStartResult` as an immutable class with `const WindowsUpdateStartResult.started()` and `const WindowsUpdateStartResult.failed(String message)`. `start` must return a failure before downloading unless all conditions are true: Windows platform, `.zip` path, `executablePath` ends in `dzien_po_dniu.exe`, the EXE exists, and its parent directory passes the write/delete probe.

  Download to `<ApplicationSupportDirectory>/updates/dzien-po-dniu-update.zip`. Write `<ApplicationSupportDirectory>/updates/apply-windows-update.ps1`; launch it detached with `powershell.exe -NoProfile -ExecutionPolicy Bypass -File <script> --parent-pid <pid> --zip <zip> --install-dir <parent> --exe-name dzien_po_dniu.exe`.

  The script must: wait for the PID, expand to a unique sibling staging directory, check for the executable, rename the live directory to a `-previous` directory, rename staging to the live path, launch the new EXE, and restore `-previous` in a `catch` path. Use `-LiteralPath` for every user-derived path. It must remove only the ZIP, script, staging, and backup that it created; it must never recurse over an unresolved path.

  Keep real I/O behind constructor callbacks so tests use no process launch or user installation directory.

- [ ] **Step 4: Run the installer tests and verify they pass**

  Run: `..\\..\\.tooling\\flutter\\bin\\flutter.bat test --no-pub test/windows_zip_update_installer_test.dart`

  Expected: PASS.

- [ ] **Step 5: Commit the Windows installer service**

  ```powershell
  git add lib/windows_zip_update_installer.dart test/windows_zip_update_installer_test.dart
  git commit -m "feat: add safe Windows ZIP update installer"
  ```

### Task 3: Wire the new installer into the update banner

**Files:**
- Modify: `lib/update_gate.dart:1-152`
- Modify: `test/update_gate_test.dart:1-95`

**Interfaces:**
- Consumes: `WindowsZipUpdateInstaller.start` and returns its failure message to the UI.
- Produces: `UpdateGate` constructor parameters `startUpdate`, `onWindowsUpdateLaunched`, and an optional `checkNow` callback for manual checks.

- [ ] **Step 1: Write failing widget tests for Windows update behavior**

  Add a Windows `ReleaseInfo` with `windowsUrl`. Inject `startUpdate` that completes from a `Completer<bool>` and assert the button label changes from `Aktualizuj teraz` to `Pobieranie…` while pending. Complete with false and assert the snackbar contains `Nie udało się rozpocząć aktualizacji`.

  Add a passing Windows test with a `WindowsUpdateStartResult.started()` adapter and assert the injected `onWindowsUpdateLaunched` callback is called exactly once rather than `openDownload`.

- [ ] **Step 2: Run the focused widget test and verify it fails**

  Run: `..\\..\\.tooling\\flutter\\bin\\flutter.bat test --no-pub test/update_gate_test.dart`

  Expected: FAIL because Windows currently falls back to `openDownload` and the button says `Pobierz`.

- [ ] **Step 3: Implement platform-specific update states**

  Replace the generic button copy with `Aktualizuj teraz` and `Pobieranie…`. Retain Android dispatch to `AndroidZipUpdateInstaller`. For Windows dispatch to `WindowsZipUpdateInstaller().start(release.windowsUrl!, parentPid: pid, executablePath: Platform.resolvedExecutable)`.

  Make the default Windows launch path call `exit(0)` only after the helper reports `started: true`; inject that exit callback in tests. Keep the application open for preflight/download/helper failures and display the returned Polish failure message in a SnackBar. Do not call `url_launcher` for Windows except from an explicit manual fallback action labelled `Pobierz ręcznie`.

- [ ] **Step 4: Run the focused widget test and verify it passes**

  Run: `..\\..\\.tooling\\flutter\\bin\\flutter.bat test --no-pub test/update_gate_test.dart`

  Expected: PASS.

- [ ] **Step 5: Commit banner integration**

  ```powershell
  git add lib/update_gate.dart test/update_gate_test.dart
  git commit -m "feat: install Windows updates from the app"
  ```

### Task 4: Make version and checking visible in settings

**Files:**
- Modify: `lib/remaster_settings_screen.dart:3-178`
- Modify: `lib/remaster_shell.dart:15-146`
- Modify: `lib/main.dart:1495-1512`
- Modify: `test/remaster_settings_screen_test.dart:1-68`

**Interfaces:**
- `RemasterSettingsScreen` accepts `required String appVersion`, `Future<void> Function()? onCheckForUpdate`, and `ValueListenable<String>? updateCheckStatus`.
- `RemasterShell` forwards those values without making HTTP requests.
- `main.dart` owns a single `UpdateService` check closure that calls `UpdateGate` and updates the settings status text.

- [ ] **Step 1: Write a failing settings widget test**

  In `test/remaster_settings_screen_test.dart`, construct the screen with `appVersion: '1.1.4'` and a callback incrementing `checks`. Assert:

  ```dart
  expect(find.text('Wersja aplikacji'), findsOneWidget);
  expect(find.text('1.1.4'), findsOneWidget);
  await tester.tap(find.text('Sprawdź aktualizacje'));
  expect(checks, 1);
  ```

- [ ] **Step 2: Run the settings test and verify it fails**

  Run: `..\\..\\.tooling\\flutter\\bin\\flutter.bat test --no-pub test/remaster_settings_screen_test.dart`

  Expected: FAIL because neither version nor check action exists.

- [ ] **Step 3: Implement a compact update card**

  Add an `Aktualizacje` section below synchronization. Its card displays `Wersja aplikacji`, `appVersion`, a 48 dp `OutlinedButton.icon` labelled `Sprawdź aktualizacje`, and a one-line status supplied by `updateCheckStatus`. Disable the button while its own future is pending. It must communicate `Masz najnowszą wersję`, `Dostępna aktualizacja X`, or `Nie udało się sprawdzić aktualizacji` without relying only on color.

  In `main.dart`, extract the current `const String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0')` into one local constant and reuse the same `UpdateService().check` closure for `UpdateGate` and settings. Do not add a second endpoint or persistent version store.

- [ ] **Step 4: Run the settings test and verify it passes**

  Run: `..\\..\\.tooling\\flutter\\bin\\flutter.bat test --no-pub test/remaster_settings_screen_test.dart`

  Expected: PASS.

- [ ] **Step 5: Commit settings visibility**

  ```powershell
  git add lib/remaster_settings_screen.dart lib/remaster_shell.dart lib/main.dart test/remaster_settings_screen_test.dart
  git commit -m "feat: show application version and update check"
  ```

### Task 5: Verify, publish the corrected first updater release, and document the one-time migration

**Files:**
- Modify: `docs/WYDANIA.md`
- Modify: `pubspec.yaml:5-18`
- Test: all existing `test/` files

**Interfaces:**
- Produces: release tag `v1.1.4`, Android version code `1001004`, release assets and `update.json` published by the workflow.

- [ ] **Step 1: Write the failing release documentation contract**

  Extend `test/release_workflow_test.dart` to assert the workflow contains `1000000 + minor * 1000 + patch` semantics and `release-assets/update.json`; then change `pubspec.yaml` version to `1.1.4+1001004` so local builds identify as the upcoming release.

- [ ] **Step 2: Run focused tests and verify the documentation/version contract is green**

  Run: `..\\..\\.tooling\\flutter\\bin\\flutter.bat test --no-pub test/release_workflow_test.dart test/update_gate_test.dart test/windows_zip_update_installer_test.dart`

  Expected: PASS.

- [ ] **Step 3: Document user-facing upgrade behavior**

  In `docs/WYDANIA.md`, add a `v1.1.4` section stating exactly: Android users tap the banner then approve the Android system installer; Windows users manually install `v1.1.4` once, then later releases download and restart automatically from the banner; an unwritable Windows install directory shows `Pobierz ręcznie` instead of closing the app.

- [ ] **Step 4: Run full verification locally**

  Run in order:

  ```powershell
  $env:FLUTTER_SUPPRESS_ANALYTICS='true'; $env:CI='true'; ..\\..\\.tooling\\flutter\\bin\\flutter.bat analyze --no-pub
  $env:FLUTTER_SUPPRESS_ANALYTICS='true'; $env:CI='true'; ..\\..\\.tooling\\flutter\\bin\\flutter.bat test --no-pub
  $env:FLUTTER_SUPPRESS_ANALYTICS='true'; $env:CI='true'; ..\\..\\.tooling\\flutter\\bin\\flutter.bat build apk --release --no-pub --build-name 1.1.4 --build-number 1001004 --dart-define=APP_VERSION=1.1.4
  $env:FLUTTER_SUPPRESS_ANALYTICS='true'; $env:CI='true'; ..\\..\\.tooling\\flutter\\bin\\flutter.bat build windows --release --no-pub --build-name 1.1.4 --build-number 1001004 --dart-define=APP_VERSION=1.1.4
  ```

  Expected: analyzer has no issues; all tests pass; both release builds succeed.

- [ ] **Step 5: Commit and publish only after the user confirms the final verification output**

  ```powershell
  git add pubspec.yaml docs/WYDANIA.md test/release_workflow_test.dart
  git commit -m "release: prepare reliable updater 1.1.4"
  git push origin codex/ui-remaster-v2
  git tag -a v1.1.4 -m "Release v1.1.4"
  git push origin v1.1.4
  ```

  Confirm GitHub Actions publishes green Android, Windows, and GitHub Release jobs before asking the user to install `v1.1.4` manually on Windows and use Android’s in-app update.

## Self-review

### Spec coverage

- Android downgrade cause and monotonic semver build numbers: Task 1.
- One-click Windows helper, writable preflight, backup/restore and no secrets: Task 2.
- Update states, disabled control, system Android installer and manual Windows fallback: Task 3.
- Visible Windows version and explicit update check: Task 4.
- `v1.1.4`, validation, platform builds and user-facing migration instructions: Task 5.

### Placeholder scan

The plan contains no deferred-work markers or references that require reading a different task to complete a step.

### Type consistency

`WindowsZipUpdateInstaller.start` always returns `WindowsUpdateStartResult`; `UpdateGate` is the only component that converts that result into a snack bar or application exit. `RemasterShell` only forwards settings properties, and `main.dart` remains the single owner of the HTTP update check closure.
