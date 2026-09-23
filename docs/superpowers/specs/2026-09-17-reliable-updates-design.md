# Niezawodne aktualizacje Android i Windows — spec

## Cel

Naprawić instalację aktualizacji Androida oraz zastąpić ręczne pobieranie i
rozpakowywanie paczki Windows automatycznym, bezpiecznym restartem aplikacji.
Wydanie `v1.1.4` będzie pierwszą wersją z poprawionym mechanizmem; późniejsze
aktualizacje mają wymagać tylko jednego naciśnięcia w aplikacji.

## Ustalona przyczyna obecnego błędu

Workflow buduje Androida z `--build-number "$GITHUB_RUN_NUMBER"`. Pierwszy
run GitHub Actions ma numer `1`, a zainstalowana wersja użytkownika ma kod
instalacyjny `4`. Android nie instaluje pakietu o niższym kodzie, dlatego
pokazuje „Nie zainstalowano aplikacji”. Podpis APK jest poprawny: build GitHub
przeszedł po poprawieniu sekretów.

## Android

- Workflow wylicza `versionCode` wyłącznie z tagu semver:
  `major * 1_000_000 + minor * 1_000 + patch`. Przykład: `v1.1.4` daje
  `1_001_004`.
- Tag musi mieć postać `vX.Y.Z`; workflow kończy się jasnym błędem, gdy wersja
  nie pasuje do tego formatu.
- Obecny przepływ pobrania ZIP → systemowy instalator pozostaje bez zmian.
  Android zawsze wymaga własnego potwierdzenia instalacji; aplikacja nie może
  tego legalnie ominąć.
- `v1.1.4` zostanie opublikowane jako nowy APK, dzięki czemu wersja `1.1.2`
  zainstaluje je z przycisku aktualizacji bez ręcznego ZIP-a.

## Windows

### Pierwsza instalacja

Istniejąca aplikacja Windows zna jedynie otwarcie ZIP-a w przeglądarce. Nie da
się zmienić jej zachowania zdalnie bez zainstalowania nowego kodu. Użytkownik
instaluje `v1.1.4` ręcznie jeden ostatni raz; od `v1.1.4` kolejne aktualizacje
są automatyczne.

### Przepływ od `v1.1.4`

1. Baner aktualizacji pokazuje wersję i przycisk „Aktualizuj teraz”.
2. Aplikacja pobiera ZIP Windows do prywatnego katalogu danych aplikacji i
   pokazuje stan „Pobieranie…” / „Przygotowywanie restartu…”.
3. Przed zamknięciem sprawdza, że katalog instalacji zawiera
   `dzien_po_dniu.exe` i że można w nim utworzyć oraz usunąć mały plik testowy.
   Gdy brak zapisu, nie zamyka aplikacji i jasno wyjaśnia, że trzeba użyć
   ręcznego pobrania.
4. Aplikacja zapisuje tymczasowy skrypt PowerShell poza katalogiem instalacji,
   przekazuje mu PID aplikacji, ZIP, katalog instalacji i ścieżkę EXE, a potem
   kończy działanie.
5. Skrypt czeka na zakończenie PID, rozpakowuje paczkę do katalogu tymczasowego
   i potwierdza obecność `dzien_po_dniu.exe`.
6. Skrypt przenosi stary katalog jako kopię zapasową, przenosi nowy katalog na
   jego miejsce i uruchamia `dzien_po_dniu.exe`. Przy błędzie przywraca kopię
   zapasową.

Aktualizator nie używa uprawnień administratora, nie działa w tle po sukcesie
i nie ma dostępu do zadań, notatek ani tokenów Supabase.

## Interfejs

- Baner ma opisową ikonę, tekst „Aktualizacja 1.1.4 jest gotowa”, przycisk
  główny oraz przycisk zamknięcia z opisem semantycznym.
- Każdy stan asynchroniczny blokuje ponowne kliknięcie i zmienia etykietę
  przycisku; nie opiera znaczenia wyłącznie na kolorze.
- Windows otrzyma w Ustawieniach widoczną pozycję „Wersja aplikacji” oraz
  akcję „Sprawdź aktualizacje”, by dało się jednoznacznie sprawdzić, co jest
  uruchomione.
- Kontrolki zachowują minimalne pole 48 dp, focus klawiaturowy i układ bez
  poziomego przewijania na telefonie.

## Granice i bezpieczeństwo

- ZIP-y są pobierane wyłącznie z istniejących URL-i GitHub Release przez HTTPS.
- Skrypt nie dostaje sekretów, nie zapisuje ich i usuwa własny katalog
  tymczasowy po pomyślnej aktualizacji.
- Pakiet Windows ma zawierać cały katalog `Release`; APK Androida nadal jest
  jedynym plikiem w ZIP-ie Android.
- Nie wprowadzamy MSIX, Microsoft Store ani cichej instalacji Androida w tym
  etapie.

## Testy akceptacyjne

- Konwersja `v1.1.4` do Android `1_001_004` i odrzucenie niepoprawnego tagu.
- Workflow zawiera walidację semver i przekazuje wyliczony code do builda APK.
- Tester `WindowsZipUpdateInstaller` sprawdza pobranie, kontrolę zapisu,
  przekazanie PID/ścieżek do helpera oraz brak uruchamiania poza Windowsem.
- `UpdateGate` na Windows uruchamia automatyczny instalator zamiast przeglądarki
  i prezentuje stan pobierania.
- Widok Ustawień zawiera numer wersji i akcję ręcznego sprawdzenia.
- `flutter analyze`, pełne `flutter test`, build Android i Windows.

