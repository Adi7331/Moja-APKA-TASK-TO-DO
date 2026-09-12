# UI polish i automatyczne wydania

## Cel

Usunąć dwa widoczne niedociągnięcia remasteru Windows oraz zastąpić ręczne tworzenie GitHub Release automatycznym workflow uruchamianym przez tag wersji.

## Poprawki interfejsu

### Ukończone zadanie

- Tytuł zachowuje przekreślenie, ale dostaje grubszy dekorator i spokojnie przygaszony kolor tekstu.
- Metadane ukończonego zadania również są przygaszone, aby stan był czytelny bez polegania tylko na kolorze ikony.
- Nie zmieniamy układu ani jednoklikowych akcji statusu.

### Foldery w notatkach

- Każdy folder będzie pojedynczym, równym chipem: nazwa oraz przycisk menu pozostaną we wspólnej obwódce.
- Przycisk menu zachowa opis dla czytnika ekranu i wygodne pole dotyku; menu nadal oferuje zmianę nazwy oraz usunięcie.
- Pasek folderów zachowa układ `Wrap`, więc na telefonie elementy zawiną się bez poziomego przewijania.

## Automatyczne wydania GitHub

### Przepływ

1. Właściciel repozytorium wypycha tag stabilnej wersji, np. `v1.1.3`.
2. GitHub Actions pobiera kod, ustawia Flutter i tworzy tymczasowy `.env` wyłącznie z GitHub Secrets.
3. Job Android dekoduje podpis produkcyjny z sekretu, buduje podpisane APK, pakuje je do ZIP-a i publikuje jako artefakt workflow.
4. Job Windows buduje folder wydania Windows, pakuje cały folder do ZIP-a i publikuje artefakt workflow.
5. Job Release pobiera oba artefakty, tworzy `update.json` z linkami do dokładnie tego tagu oraz tworzy albo aktualizuje GitHub Release.

Nazwy assets:

- `dzien-po-dniu-android-vX.Y.Z.zip`
- `dzien-po-dniu-windows-vX.Y.Z.zip`
- `update.json`

Workflow będzie też możliwy do uruchomienia ręcznie dla tagu, który już istnieje. To jest tylko awaryjna droga dla wydania `v1.1.2`; późniejsze tagi wystarczą same.

### Sekrety GitHub

Workflow wymaga wyłącznie sekretów repozytorium:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`

Klucz podpisu i hasła nigdy nie trafią do commita, logów ani assetów. Publikowanie Release użyje wbudowanego `GITHUB_TOKEN` oraz ograniczenia `contents: write`; nie jest potrzebny osobny token użytkownika.

## Zachowanie aktualizacji

- Android pobiera ZIP w aplikacji, wypakowuje APK i otwiera systemowy instalator z obowiązkowym potwierdzeniem użytkownika.
- Windows pokazuje baner oraz otwiera pobranie ZIP-a. Użytkownik rozpakowuje paczkę do folderu i uruchamia `dzien_po_dniu.exe`; pełne samonadpisywanie uruchomionego pliku jest poza tym etapem.

## Testy i weryfikacja

- Test widgetu ukończonego zadania sprawdzi widoczny styl przekreślenia.
- Test folderów sprawdzi pojedynczą, spójną kontrolkę oraz dostęp do menu.
- `flutter analyze` i pełny `flutter test`.
- Lokalny build APK i Windows.
- Walidacja YAML workflow oraz kontrola, że żaden sekret nie jest śledzony przez Git.
