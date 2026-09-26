# Dniówka — aktualizacje Windows, przypomnienia i wygląd zadań

## Cel

Naprawić zawodność aktualizacji Windows i Google Calendar, wprowadzić powtarzane przypomnienia o zadaniach bieżących oraz doprecyzować semantykę kategorii i wygląd kart zadań. Zmiany obejmują Androida i Windowsa; lokalny zapis oraz kolejka synchronizacji pozostają źródłem odporności na chwilowy brak sieci.

## Aktualizacje Windows

Aktualizator ma pobierać i pokazywać postęp w aplikacji, przygotowywać i sprawdzać archiwum przed podmianą, zamykać aplikację dopiero po gotowości helpera oraz zachować poprzednią instalację do potwierdzenia pierwszego startu nowej wersji. Błąd ma uruchomić rollback i pozostawić czytelny komunikat oraz bezpieczny log. Lokalny stan aplikacji i oczekująca synchronizacja muszą przetrwać restart. Istniejąca wersja ma otrzymać ścieżkę jednorazowego helpera, niewymagającą ręcznego rozpakowywania ZIP.

## Przypomnienia o zadaniach

Dodaj lokalne dla urządzenia ustawienie włącz/wyłącz, interwał 15/30/60/120 minut lub własny 15–1440 minut oraz zakres godzin. Domyślnie przypomnienia są wyłączone; po włączeniu: 60 minut, 09:00–21:00. Zakres może przechodzić przez północ. Powiadomienie zbiorcze zawiera liczbę i najwyżej trzy tytuły zadań na dziś lub zaległych; pomija wykonane, przyszłe i bez terminu. Kliknięcie otwiera Dzisiaj.

Android używa alarmów systemowych odtwarzanych po restarcie i odczytuje aktualne lokalne dane przy wysyłce; uwzględnia uprawnienia. Windows pozostaje w zasobniku, gdy funkcja jest włączona, z pozycjami Otwórz/Zakończ. Autostart systemowy jest osobny i domyślnie wyłączony. Nie nadrabiać alarmów po uśpieniu. Ukończenie/zmiana terminu, ustawień lub wylogowanie odświeża/anuluje harmonogram. Nowe zbiorcze przypomnienia zastępują cykliczne alerty overdue per-task, ale zachowują pojedyncze przypomnienia ustawione w zadaniu.

## Google Calendar

Przechwytywać bezpiecznie kod HTTP i `error.errors[].reason` odpowiedzi Google, klasyfikować brak uprawnień OAuth, wyłączone API, ograniczenia konta, limity oraz token nieważny. Interfejs pokazuje „Połączony” dopiero po udanym pobraniu listy kalendarzy. Zachować odczyt tylko, token w lokalnym bezpiecznym magazynie i wydarzenia offline. Brakujące scope naprawia ponowna zgoda; `accessNotConfigured` wymaga włączenia Calendar API w projekcie Google Cloud.

## Kategorie i wygląd zadań

`categoryId == null` oznacza „Bez kategorii”; stare tekstowe `category` nie może ustawić automatycznie kategorii. Widok Skrzynka wybiera wszystkie niewykonane zadania bez terminu, niezależnie od kategorii. Przesłanie jawnego null musi usunąć przypisanie po stronie serwera.

Dodaj opcjonalne `emoji` i `colorKey` do modelu, szkicu, lokalnego zapisu, kolejki i Supabase. Stare zadania mają neutralny wygląd. Edytor oferuje pojedyncze emoji, wyczyszczenie emoji i paletę neutralny/niebieski/lawendowy/miętowy/brzoskwiniowy/piaskowy. Tytuł i treść zachowują czytelny kontrast; emoji pokazuje się przy tytule w listach, Start i widoku tygodnia.

## Ochrona danych i zgodność

Nowe pola Supabase są nullable albo mają neutralne wartości domyślne; nie zmieniają właściciela rekordów ani istniejących polityk RLS. Nie umieszczać tokenów ani sekretów w logach. Zachować kompatybilność z istniejącą lokalną kolejką oraz starymi rekordami.

## Odbiór

- Testy modelu, lokalnego zapisu, kolejki i payloadu potwierdzają kategorię null oraz zachowanie emoji/koloru.
- Testy kalendarza rozróżniają powody błędów 401/403/429 oraz stan po udanym i nieudanym pobraniu.
- Testy przypomnień obejmują godziny zwykłe/przez północ, interwał własny, brak pasujących zadań, restart Androida i zamknięcie okna Windows.
- Testy aktualizatora obejmują błąd pobrania/ZIP/podmiany, rollback, pierwszy start i potwierdzenie gotowości.
- Uruchomić analizę, pełny Flutter test oraz build Windows i APK podpisany, o ile lokalny klucz wydaniowy jest dostępny; nie logować jego wartości.
- Kierować tymczasowe i ciężkie build artefakty na dysk F:.
