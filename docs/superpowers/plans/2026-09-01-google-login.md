# Google Login Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Umożliwić bezpieczne logowanie kontem Google w aplikacji Flutter na Androidzie i Windowsie, z sesją obsługiwaną przez Supabase.

**Architecture:** Przycisk logowania wywołuje `SupabaseClient.auth.signInWithOAuth(OAuthProvider.google)` z jednym stałym adresem powrotu `dzienpodniu://login-callback/`. `supabase_flutter` obsługuje callback i wymianę PKCE wewnętrznie; aplikacja reaguje na powstanie sesji, wywołując istniejące `_enterCloudMode`. Warstwa interfejsu dostaje wstrzykiwaną akcję Google, aby widok dało się testować bez rzeczywistej sieci lub przeglądarki.

**Tech Stack:** Flutter, `supabase_flutter ^2.17.2`, Supabase Auth OAuth/PKCE, Android intent-filter, Windows URI scheme registration.

**Spec:** `docs/superpowers/specs/2026-09-01-google-login-design.md`

## Global Constraints

- Obsługiwane platformy: Android i Windows; iOS poza zakresem.
- Adres powrotu jest stały: `dzienpodniu://login-callback/`.
- Client Secret Google nigdy nie trafia do kodu, `.env` ani GitHub.
- Żadne dodatkowe scope'y poza tożsamością (`openid`, e-mail, profil).
- Istniejące logowanie e-mail/hasło i tryb lokalny muszą działać bez zmian.
- Nie zmieniaj zasad RLS ani schematu bazy danych.

---

## File structure

- `lib/google_sign_in_action.dart` — mała, testowalna granica wywołania OAuth.
- `lib/main.dart` — przekazuje akcję do ekranu logowania, reaguje na stan sesji i pokazuje błędy.
- `android/app/src/main/AndroidManifest.xml` — rejestruje schemat `dzienpodniu` dla callbacku.
- `windows/runner/Runner.rc` oraz nowy `windows/runner/uri_scheme.reg` — opis rejestracji schematu URI dla instalatora Windows; plik `.reg` służy tylko testom lokalnym, nie zawiera sekretów.
- `test/google_sign_in_action_test.dart` — test kontraktu OAuth bez przeglądarki.
- `test/widget_test.dart` — test widoku logowania: stan oczekiwania, sukces i błąd.
- `docs/google-oauth-setup.md` — instrukcja dla właściciela projektu Google Cloud i Supabase.

### Task 1: Testowalna akcja OAuth Google

**Files:**
- Create: `lib/google_sign_in_action.dart`
- Create: `test/google_sign_in_action_test.dart`

**Interfaces:**
- Produces: `abstract interface class GoogleSignInAction { Future<void> start(); }`
- Produces: `class SupabaseGoogleSignInAction implements GoogleSignInAction`
- Consumes: `SupabaseClient` oraz `OAuthProvider.google`.

- [ ] **Step 1: Write the failing test**

```dart
test('starts Google OAuth with the fixed application callback', () async {
  final calls = <String>[];
  final action = GoogleSignInAction.forTesting((redirectTo) async {
    calls.add(redirectTo);
  });

  await action.start();

  expect(calls, ['dzienpodniu://login-callback/']);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/google_sign_in_action_test.dart`

Expected: FAIL because `google_sign_in_action.dart` and `GoogleSignInAction` do not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
const googleLoginRedirectUrl = 'dzienpodniu://login-callback/';

abstract interface class GoogleSignInAction {
  Future<void> start();
}

class SupabaseGoogleSignInAction implements GoogleSignInAction {
  SupabaseGoogleSignInAction(this._client);
  final SupabaseClient _client;

  @override
  Future<void> start() => _client.auth.signInWithOAuth(
    OAuthProvider.google,
    redirectTo: googleLoginRedirectUrl,
    authScreenLaunchMode: LaunchMode.externalApplication,
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/google_sign_in_action_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib/google_sign_in_action.dart test/google_sign_in_action_test.dart
git commit -m "feat: add Google OAuth action"
```

### Task 2: Stan logowania Google i obsługa błędów

**Files:**
- Modify: `lib/main.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**
- Consumes: `GoogleSignInAction.start()` z Task 1.
- Produces: `_LoginPage(onGoogleSignIn, onSignedIn)` i widoczny stan `Łączę z Google…`.

- [ ] **Step 1: Write the failing widget test**

```dart
testWidgets('shows a Google login error and keeps local mode available', (tester) async {
  await tester.pumpWidget(LoginPageForTest(
    onGoogleSignIn: () async => throw AuthException('Google is unavailable'),
  ));

  await tester.tap(find.text('Kontynuuj z Google'));
  await tester.pumpAndSettle();

  expect(find.text('Nie udało się połączyć z Google. Spróbuj ponownie.'), findsOneWidget);
  expect(find.text('Tryb lokalny'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart --plain-name "shows a Google login error and keeps local mode available"`

Expected: FAIL because `_LoginPage` has no Google action or error state.

- [ ] **Step 3: Write minimal implementation**

```dart
Future<void> _signInWithGoogle() async {
  try {
    await _googleSignIn.start();
  } on AuthException {
    if (mounted) setState(() => _loginError = 'Nie udało się połączyć z Google. Spróbuj ponownie.');
  }
}
```

Pass `_signInWithGoogle` into `_LoginPage`; disable the Google button while it is awaiting and show `Łączę z Google…`. Keep the e-mail and local mode controls enabled after an error.

- [ ] **Step 4: Restore session and enter cloud mode**

At `initState`, after local storage restoration, check `Supabase.instance.client.auth.currentSession`. If it is non-null, call `_enterCloudMode()` exactly once. Subscribe to `onAuthStateChange`; when a non-null session is returned after an OAuth callback, call `_enterCloudMode()` only if `cloudMode` is false.

- [ ] **Step 5: Run focused tests**

Run: `flutter test test/widget_test.dart`

Expected: PASS, including existing e-mail/login/local-mode tests.

- [ ] **Step 6: Commit**

```powershell
git add lib/main.dart test/widget_test.dart
git commit -m "feat: handle Google authentication state"
```

### Task 3: Callback platformowy i instrukcja właściciela

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Create: `windows/runner/uri_scheme.reg`
- Create: `docs/google-oauth-setup.md`

**Interfaces:**
- Consumes: `googleLoginRedirectUrl == 'dzienpodniu://login-callback/'` z Task 1.
- Produces: Android otwiera aplikację dla callbacku; Windows ma jednoznaczny plik rejestracji URI dla lokalnego testu.

- [ ] **Step 1: Write the failing configuration check**

```dart
test('publishes the callback URI used by Google OAuth', () {
  expect(googleLoginRedirectUrl, 'dzienpodniu://login-callback/');
});
```

- [ ] **Step 2: Add Android callback registration**

Inside the existing `MainActivity` intent-filter add:

```xml
<data android:scheme="dzienpodniu" android:host="login-callback" />
```

Keep existing launcher filters unchanged.

- [ ] **Step 3: Add Windows local URI registration file**

Create `windows/runner/uri_scheme.reg` using the application executable path placeholder `%LOCALAPPDATA%\\DzienPoDniu\\dzien_po_dniu.exe` and the command argument `"%1"`. The documentation must state that the final installer replaces this local-test registration; do not ask users to run registry changes for a release build.

- [ ] **Step 4: Add owner checklist**

Document exact dashboard sequence:

1. Google Cloud → create OAuth Client ID of type Web application.
2. Copy the Supabase callback URL from the Google provider panel into Authorized redirect URIs.
3. Supabase → enable Google, paste Client ID and Client Secret.
4. Supabase → URL Configuration → add `dzienpodniu://login-callback/` to Redirect URLs.
5. Do not commit the Google secret.

- [ ] **Step 5: Run tests and inspect Android manifest**

Run: `flutter test test/google_sign_in_action_test.dart`

Expected: PASS.

Run: `flutter analyze`

Expected: `No issues found!`.

- [ ] **Step 6: Commit**

```powershell
git add android/app/src/main/AndroidManifest.xml windows/runner/uri_scheme.reg docs/google-oauth-setup.md test/google_sign_in_action_test.dart
git commit -m "feat: configure Google OAuth callbacks"
```

### Task 4: Końcowa weryfikacja i test ręczny

**Files:**
- Modify only if a failure from a test identifies a concrete defect.

**Interfaces:**
- Consumes: cały przepływ z Tasks 1–3.
- Produces: potwierdzony login Android i Windows po uzupełnieniu danych Google przez właściciela projektu.

- [ ] **Step 1: Automated verification**

Run:

```powershell
flutter analyze
flutter test
flutter build windows --debug
flutter build apk --debug
```

Expected: brak problemów z analizą, komplet testów przechodzi, oba buildy kończą się sukcesem.

- [ ] **Step 2: Guided manual verification**

1. Właściciel wykona checklistę z `docs/google-oauth-setup.md`.
2. Uruchomi Windows build, kliknie `Kontynuuj z Google`, zaloguje się i sprawdzi wyświetlenie zadań z chmury.
3. Utworzy jedno zadanie na Windowsie i potwierdzi je na Androidzie.
4. Anuluje kolejne logowanie i potwierdzi pozostanie na ekranie logowania.

- [ ] **Step 3: Commit only concrete fixes**

```powershell
git add <only-files-changed-by-a-reproduced-fix>
git commit -m "fix: complete Google OAuth flow"
```

## Self-review

- Spec coverage: Tasks 1–2 realizują OAuth, błędy i sesję; Task 3 realizuje konfigurację Android/Windows oraz sekrety poza repozytorium; Task 4 realizuje testy wieloplatformowe i synchronizację.
- Placeholder scan: wszystkie kroki są konkretne; zmienna ścieżka w pliku `.reg` jest celowa i opisana jako konfiguracja wyłącznie lokalnego testu.
- Type consistency: `GoogleSignInAction.start()` jest jedyną granicą OAuth używaną przez ekran; `googleLoginRedirectUrl` jest jedynym źródłem callbacku.
