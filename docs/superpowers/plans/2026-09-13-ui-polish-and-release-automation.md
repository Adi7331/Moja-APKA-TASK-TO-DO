# UI Polish and Release Automation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make completed tasks and folder controls visually consistent, then automate Android and Windows GitHub Releases from version tags.

**Architecture:** The UI work stays in existing remaster widgets and is verified with widget tests. A GitHub Actions workflow builds Android and Windows independently, then creates one GitHub Release and its version manifest from the pushed tag.

**Tech Stack:** Flutter/Dart, Flutter widget tests, GitHub Actions, Android Gradle signing, PowerShell ZIP packaging.

**Spec:** `docs/superpowers/specs/2026-09-13-release-automation-and-ui-polish-design.md`

## Global Constraints

- Keep the remaster theme, visible focus and a 48 dp folder-menu target.
- Never commit `.env`, `android/key.properties`, keystores or secret values.
- Assets must be `dzien-po-dniu-android-vX.Y.Z.zip`, `dzien-po-dniu-windows-vX.Y.Z.zip` and `update.json`.
- Android remains signed using the existing production keystore.
- Windows continues to use download-and-unzip, not replacement of a running EXE.

---

### Task 1: Strengthen completed task state

**Files:**
- Modify: `lib/remaster_tasks_screen.dart:323-340`
- Create: `test/remaster_task_completion_style_test.dart`

**Interfaces:**
- Consumes: `TaskItem.isDone` and the remaster color scheme.
- Produces: a done title with line-through, thickness `2`, and muted title/meta text.

- [ ] Write a widget test that pumps a done `TaskItem`, finds its title `Text`, and asserts `TextDecoration.lineThrough` plus `decorationThickness >= 2`.
- [ ] Run `flutter test --no-pub test/remaster_task_completion_style_test.dart` and confirm it fails because thickness is currently unset.
- [ ] In `_TaskRow`, compute `completedColor = scheme.onSurfaceVariant.withValues(alpha: .62)`; set it for done title/meta and set `decorationThickness: task.isDone ? 2 : null`.
- [ ] Run the targeted test again and commit with `fix: strengthen completed task state`.

### Task 2: Make folder name and menu one aligned control

**Files:**
- Modify: `lib/remaster_notes_screen.dart:417-488`
- Modify: `test/remaster_folder_dialog_test.dart`

**Interfaces:**
- Consumes: `NoteFolder`, selection callback, rename/delete callbacks.
- Produces: `_FolderChip`, one outlined Material surface with an accessible `Opcje folderu: <name>` control.

- [ ] Add a widget test that checks the center Y of `Samochód` and the `Opcje folderu: Samochód` button differ by at most one pixel.
- [ ] Run `flutter test --no-pub test/remaster_folder_dialog_test.dart` and confirm the current separate `InputChip`/`PopupMenuButton` fails the test.
- [ ] Replace the folder `Row` with `_FolderChip`: a Material stadium surface, label `InkWell` for selection, and `IconButton` inside the same surface with a 48x48 constraint; reuse existing popup menu values and dialogs.
- [ ] Run folder tests at 390 px and commit with `fix: align folder controls`.

### Task 3: Add tag-driven GitHub release automation

**Files:**
- Create: `.github/workflows/release.yml`
- Create: `test/release_workflow_test.dart`
- Modify: `docs/WYDANIA.md`

**Interfaces:**
- Consumes: tag `vX.Y.Z`, GitHub repository secrets and the existing ignored `.env`/`android/key.properties` convention.
- Produces: Android ZIP, Windows ZIP, `update.json` and a published GitHub Release.

- [ ] Write `release_workflow_test.dart` to assert that the workflow contains `push.tags`, `workflow_dispatch`, `contents: write`, both ZIP names and `update.json` without literal secret values.
- [ ] Run `flutter test --no-pub test/release_workflow_test.dart` and confirm it fails because the workflow does not exist.
- [ ] Implement three jobs: Android on Ubuntu decodes `ANDROID_KEYSTORE_BASE64`, writes ignored signing/.env files, builds APK and ZIP; Windows builds the Release directory and ZIP; release downloads both artifacts, creates manifest URLs for `github.ref_name`, and uses `softprops/action-gh-release`.
- [ ] Add required GitHub Secrets and manual-dispatch instructions to `docs/WYDANIA.md`: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`.
- [ ] Run `flutter test --no-pub test/release_workflow_test.dart`, `flutter analyze --no-pub`, and `git ls-files .env android/key.properties`; the last command must output no tracked secret files.
- [ ] Commit with `ci: automate tagged releases`.

### Task 4: Release-quality verification

**Files:**
- Verify only.

- [ ] Run `flutter analyze --no-pub` and `flutter test --no-pub`.
- [ ] Build `1.1.3` for Android and Windows using release build name, number and `APP_VERSION` definitions.
- [ ] Inspect both ZIPs: Android contains only an APK; Windows contains `dzien_po_dniu.exe`, `data/` and DLLs.
- [ ] Confirm `git status --short` has no `.env`, signing file or keystore, then push the implementation commits.
