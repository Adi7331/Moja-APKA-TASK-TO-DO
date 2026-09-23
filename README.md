# Dzień po Dniu

Prosta aplikacja Flutter do zarządzania zadaniami. Działa w trybie lokalnym, a po zalogowaniu zapisuje zadania w Supabase i synchronizuje je w czasie rzeczywistym między urządzeniami.

## Wymagania

- [Flutter SDK](https://docs.flutter.dev/get-started/install) zgodny z wersją Dart określoną w `pubspec.yaml`;
- dla Windows: Visual Studio 2022 z pakietem **Desktop development with C++**;
- dla Androida: Android Studio, Android SDK oraz fizyczne urządzenie z włączonym debugowaniem USB lub emulator;
- projekt Supabase — tylko gdy chcesz używać logowania i synchronizacji.

Po instalacji sprawdź środowisko:

```powershell
flutter doctor
```

## Uruchomienie lokalne

```powershell
git clone <adres-repozytorium>
cd "dzien-po-dniu"
flutter pub get
```

Następnie skonfiguruj plik `.env` zgodnie z następną sekcją i uruchom wybraną platformę:

```powershell
# Windows
flutter run -d windows

# Android — najpierw sprawdź identyfikator urządzenia
flutter devices
flutter run -d <id-urzadzenia>
```

Podczas pracy `r` w terminalu uruchamia hot reload, a `R` pełny restart aplikacji.

## Konfiguracja Supabase

1. Utwórz projekt w [Supabase](https://supabase.com/dashboard).
2. W **SQL Editor** wklej i uruchom kolejno:
   - zawartość [`supabase/schema.sql`](supabase/schema.sql) — tworzy tabelę `tasks`, indeks oraz reguły RLS ograniczające dane do właściciela;
   - zawartość [`supabase/realtime.sql`](supabase/realtime.sql) — włącza aktualizacje czasu rzeczywistego dla tabeli `tasks`.
   - zawartość [`supabase/subtasks.sql`](supabase/subtasks.sql) — tworzy prywatne checklisty kroków, ich reguły RLS oraz synchronizację czasu rzeczywistego.
   - zawartość [`supabase/notes.sql`](supabase/notes.sql) — tworzy prywatne notatki, bloki, etykiety, załączniki, ustawienia kosza, RLS oraz publikację Realtime.
   - zawartość [`supabase/note_folders.sql`](supabase/note_folders.sql) — dodaje prywatne foldery, przypisanie `folder_id` i publikację Realtime. Uruchom po `notes.sql`.
3. W **Authentication → Providers → Email** włącz logowanie e-mailem. Na potrzeby szybkich testów można wyłączyć potwierdzanie adresu e-mail; w aplikacji produkcyjnej pozostaw je włączone i ustaw właściwe adresy przekierowań.
4. W **Project Settings → API** skopiuj:
   - **Project URL**;
   - **Publishable key** (w starszych projektach może być opisany jako `anon` key).

> Nigdy nie wklejaj do aplikacji ani do pliku `.env` klucza `service_role` / `secret`. Ma on pełny dostęp do bazy i może omijać RLS.

### Notatki i załączniki

Sekcja **Notatki** działa bez sieci i zapisuje dane w katalogu danych aplikacji. Po zalogowaniu tym samym kontem Google może zsynchronizować notatki przez Supabase; Google służy wyłącznie do logowania — aplikacja nie prosi o dostęp do Dysku, Gmaila ani Kalendarza.

Przed użyciem synchronizacji uruchom `supabase/notes.sql` w SQL Editor. Skrypt tworzy prywatny bucket Storage `note-attachments`, a polityki pozwalają użytkownikowi korzystać wyłącznie z plików w jego własnym katalogu. Limit pojedynczego pliku wynosi 20 MB. Nowe tabele są dodawane do publikacji `supabase_realtime`, więc zmiany notatek mogą odświeżać drugi telefon lub komputer.

Do synchronizacji folderów uruchom następnie [`supabase/note_folders.sql`](supabase/note_folders.sql). Skrypt można bezpiecznie uruchomić ponownie: istniejące tabele, kolumny, indeksy, polityki właściciela i wpis Realtime nie są dublowane ani zastępowane. Opcjonalna kolumna `emoji` może pozostać pusta; wcześniejsze foldery i notatki bez folderu nadal działają. Nie trzeba zmieniać reguł RLS ani konfiguracji Realtime.

Jeśli konto ma już notatki w chmurze, lokalny magazyn nie jest automatycznie nadpisywany — lokalne dane pozostają na urządzeniu do bezpiecznego importu. Konflikt wersji zachowuje kopię z tytułem „Konflikt — …”.

### Plik `.env`

Skopiuj przykład i uzupełnij go danymi z panelu Supabase:

```powershell
Copy-Item .env.example .env
```

Plik `.env` musi zawierać dokładnie te nazwy (aplikacja odczytuje je przy starcie):

```dotenv
SUPABASE_URL=https://twoj-projekt.supabase.co
SUPABASE_PUBLISHABLE_KEY=twoj_publiczny_publishable_lub_anon_key
```

`.env` jest ignorowany przez Git. Nie dodawaj do repozytorium prawdziwych kluczy. Po każdej zmianie `.env` wykonaj pełny restart (`R` lub ponowne `flutter run`), ponieważ plik jest ładowany podczas uruchamiania.

## Windows

Na Windows wymagane są komponenty C++ z Visual Studio. Po `flutter doctor` bez błędów uruchom:

```powershell
flutter run -d windows
```

Wersję produkcyjną zbudujesz poleceniem:

```powershell
flutter build windows
```

Wynik znajduje się w `build\windows\x64\runner\Release`. Do dystrybucji kopiuj cały katalog `Release`, nie tylko plik `.exe`.

## Android

Uruchom emulator z Android Studio albo podłącz telefon, a potem:

```powershell
flutter devices
flutter run -d <id-urzadzenia>
```

APK do testów:

```powershell
flutter build apk --debug
```

Plik będzie w `build\app\outputs\flutter-apk\app-debug.apk`.

Manifest główny (`android/app/src/main/AndroidManifest.xml`) zawiera uprawnienie do Internetu, potrzebne do połączenia z Supabase:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

## Weryfikacja

```powershell
flutter analyze
flutter test
```

Po zalogowaniu dodaj zadanie na jednym urządzeniu. Powinno pojawić się na drugim urządzeniu zalogowanym na to samo konto.

### Pierwsze logowanie z zadaniami lokalnymi

Jeśli przed zalogowaniem używałeś **Trybu lokalnego**, a konto w Supabase nie ma jeszcze żadnych zadań, aplikacja przeniesie lokalną listę do chmury podczas pierwszego udanego logowania. Chmura nie jest nadpisywana: gdy konto zawiera już choć jedno zadanie, migracja nie uruchamia się automatycznie. Lokalna kopia pozostaje na urządzeniu jako awaryjny zapis.

Po zakończeniu procesu nagłówek pokazuje `Zsynchronizowano`. Przy problemie z siecią zobaczysz `Błąd synchronizacji`, a zadania lokalne pozostaną dostępne.

## Struktura danych

- `supabase/schema.sql` — tabela zadań i polityki bezpieczeństwa RLS;
- `supabase/realtime.sql` — publikacja tabeli dla synchronizacji czasu rzeczywistego;
- `supabase/subtasks.sql` — tabela kroków checklisty, RLS i Realtime;
- `supabase/notes.sql` — notatki blokowe, etykiety, załączniki Storage, ustawienia kosza, RLS i Realtime;
- `.env.example` — szablon konfiguracji lokalnej bez prawdziwych sekretów.
