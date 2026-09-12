# Wydania aplikacji

Od wersji `1.1.1` aplikacja sprawdza plik `update.json` dołączony do najnowszego GitHub Release. Android pobiera paczkę ZIP, a następnie otwiera systemowy instalator zawartego APK.

## Każde kolejne wydanie

1. Zwiększ numer w `pubspec.yaml`, na przykład do `1.1.2+4`.
2. Zbuduj APK oraz pakiet Windows z tym samym numerem wersji.
3. Zmień `release/update.json`: numer wersji, link do paczki Android ZIP, link do paczki Windows ZIP i opis zmian.
4. Na GitHub utwórz Release z tagiem `vX.Y.Z` i dołącz trzy pliki jako assets:
   - `dzien-po-dniu-android-vX.Y.Z.zip` (w środku wyłącznie plik APK)
   - `dzien-po-dniu-windows-vX.Y.Z.zip` (w środku cały folder wydania Windows)
   - `update.json`

Aplikacja porównuje tylko stabilne numery w formacie `X.Y.Z`. Android otwiera systemowy instalator. Windows otwiera pobranie paczki ZIP; po rozpakowaniu należy uruchomić `dzien_po_dniu.exe`.

## Ważne o podpisie Androida

Zachowaj ten sam klucz podpisu dla każdego wydania. Zmiana klucza uniemożliwia Androidowi aktualizację istniejącej instalacji bez odinstalowania aplikacji.
