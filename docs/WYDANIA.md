# Wydania aplikacji

Od wersji `1.1.0` aplikacja sprawdza plik `update.json` dołączony do najnowszego GitHub Release.

## Każde kolejne wydanie

1. Zwiększ numer w `pubspec.yaml`, na przykład do `1.1.1+3`.
2. Zbuduj APK o tej samej nazwie co w manifeście:
   `flutter build apk --release --build-name=1.1.1 --build-number=3 --dart-define=APP_VERSION=1.1.1`
3. Zmień `release/update.json`: numer wersji, link APK i opis zmian.
4. Na GitHub utwórz Release z tagiem `v1.1.1` i dołącz dokładnie dwa pliki jako assets:
   - `dzien-po-dniu-v1.1.1.apk`
   - `update.json`

Aplikacja porównuje tylko stabilne numery w formacie `X.Y.Z`. Aktualizacja otwiera systemowy instalator — Android i Windows zawsze wymagają końcowego potwierdzenia użytkownika.

## Ważne o podpisie Androida

Zachowaj ten sam klucz podpisu dla każdego wydania. Zmiana klucza uniemożliwia Androidowi aktualizację istniejącej instalacji bez odinstalowania aplikacji.
