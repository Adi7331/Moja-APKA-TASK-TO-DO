# Wydania aplikacji

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

## Ważne o podpisie Androida

Zachowaj ten sam klucz podpisu dla każdego wydania. Zmiana klucza uniemożliwia Androidowi aktualizację istniejącej instalacji bez odinstalowania aplikacji.

## Ważne o sekretach

Nie commituj `.env`, `android/key.properties` ani pliku keystore. GitHub
Actions tworzy je wyłącznie tymczasowo podczas budowania paczek.
