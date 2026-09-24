# Wydania aplikacji

## Wydanie 1.2.0 — Koszty

Moduł Koszty pozwala zapisywać wydatki, wpływy, subskrypcje i własne kategorie. Przegląd pokazuje prognozę płatności na 90 dni, osobno otrzymane i oczekiwane wpływy, opłacone wydatki według kategorii oraz porównanie miesiąc do miesiąca. Subskrypcje mają miesięczny i roczny odpowiednik kosztu, a tryb prognozy zapisuje się lokalnie na urządzeniu.

## Podgląd przebudowy Notatek

Android i Windows otrzymują bibliotekę pastelowych kart, nowy edytor oraz kontekst folderów na desktopie.

Notatki mają teraz czytelniejsze, stałe kolory z kontrastowym tekstem, polską datę i godzinę ostatniej zmiany oraz kolejność od najnowszych (przypięte pozostają na górze). Foldery można tworzyć i edytować, także ustawiając jedną emoji. Edytor ma widoczne `Gotowe`, które zamyka go po zapisaniu; przy błędzie pozwala ponowić zapis. Wąski ekran i duży tekst nie ściskają przycisków ani nagłówka załączników.

Od wersji `1.1.1` aplikacja sprawdza plik `update.json` dołączony do najnowszego GitHub Release. Android pobiera paczkę ZIP, a następnie otwiera systemowy instalator zawartego APK.

## Automatyczne wydania przez GitHub Actions

Od teraz nie trzeba ręcznie budować paczek ani tworzyć Release. Po jednorazowym
dodaniu sekretów GitHub Actions zrobi to po każdym tagu `vX.Y.Z`:

1. Wejdź w repozytorium → **Settings → Secrets and variables → Actions**.
2. Dodaj jednorazowo następujące **Repository secrets** (wartości pozostają
   niewidoczne w logach):
   - `SUPABASE_URL`
   - `SUPABASE_PUBLISHABLE_KEY`
   - `ANDROID_KEYSTORE_BASE64`
   - `ANDROID_STORE_PASSWORD`
   - `ANDROID_KEY_PASSWORD`
   - `ANDROID_KEY_ALIAS`
3. Utwórz i wypchnij tag `vX.Y.Z`. Workflow zbuduje podpisany APK, paczkę
   Windows oraz `update.json`, a następnie opublikuje je jako GitHub Release.

Ręczne uruchomienie jest też dostępne w zakładce **Actions → Build and publish
release → Run workflow**. Wtedy wpisz istniejący tag, np. `v1.1.3`.

## Awaryjne ręczne wydanie

1. Zwiększ numer w `pubspec.yaml`, na przykład do `1.1.2+4`.
2. Zbuduj APK oraz pakiet Windows z tym samym numerem wersji.
3. Zmień `release/update.json`: numer wersji, link do paczki Android ZIP, link do paczki Windows ZIP i opis zmian.
4. Na GitHub utwórz Release z tagiem `vX.Y.Z` i dołącz trzy pliki jako assets:
   - `dzien-po-dniu-android-vX.Y.Z.zip` (w środku wyłącznie plik APK)
   - `dzien-po-dniu-windows-vX.Y.Z.zip` (w środku cały folder wydania Windows)
   - `update.json`

Aplikacja porównuje tylko stabilne numery w formacie `X.Y.Z`. Android otwiera systemowy instalator. Windows w wersji `1.1.4` i nowszych pobiera paczkę, podmienia pliki i uruchamia nową wersję automatycznie; starsze wydania wymagają ręcznego rozpakowania paczki ZIP i uruchomienia `dzien_po_dniu.exe`.

## Wydanie 1.1.4 — jednorazowa migracja aktualizatora

Wersja `1.1.4` naprawia numer instalacyjny Androida, więc aktualizacja z
wcześniejszej wersji może zostać przyjęta bez odinstalowywania aplikacji.
Android pobiera paczkę z banera, a następnie wymaga potwierdzenia w systemowym
instalatorze.

Na Windowsie wersję `1.1.4` trzeba zainstalować ręcznie po raz ostatni. Od
wersji `1.1.4` kolejne wydania pobierają paczkę po kliknięciu **Aktualizuj
teraz**, zamykają aplikację i uruchamiają nową wersję automatycznie. Jeśli
katalog instalacji Windows nie pozwala na zapis, aplikacja pozostaje otwarta i
pokazuje przycisk **Pobierz ręcznie** zamiast wykonywać nieudaną próbę podmiany.

## Wydanie 1.1.6 — poprawiona konfiguracja Supabase

Wydanie `1.1.6` zastępuje wcześniejsze paczki testowe `1.1.4` i `1.1.5`.
Przed jego zbudowaniem sekret GitHub `SUPABASE_PUBLISHABLE_KEY` musi zawierać
wyłącznie klucz klienta zaczynający się od `sb_publishable_`, nigdy
`sb_secret_` ani `service_role`. Dopiero paczkę `1.1.6` należy instalować,
aby logowanie Google korzystało z poprawnej i bezpiecznej konfiguracji.

## Ważne o podpisie Androida

Zachowaj ten sam klucz podpisu dla każdego wydania. Zmiana klucza uniemożliwia Androidowi aktualizację istniejącej instalacji bez odinstalowania aplikacji.

## Ważne o sekretach

Nie commituj `.env`, `android/key.properties` ani pliku keystore. GitHub
Actions tworzy je wyłącznie tymczasowo podczas budowania paczek.
