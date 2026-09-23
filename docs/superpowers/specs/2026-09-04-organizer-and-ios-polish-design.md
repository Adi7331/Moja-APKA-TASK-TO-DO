# Dzień po dniu — organizer, przypomnienia i spokojny styl systemowy

## Cel

Rozwinąć aplikację z listy zadań w osobisty organizer na Androida i Windows. Użytkownik ma szybko planować dzień, otrzymywać przypomnienia, powtarzać rutynowe zadania i w poniedziałek oglądać wiarygodne podsumowanie zakończonego tygodnia.

## Zakres

Ten etap obejmuje:

- responsywny, lekki interfejs telefonu i komputera;
- subtelny gradient w nagłówkach, bez gradientów na listach zadań;
- plan dnia z najwyżej trzema przypiętymi zadaniami;
- przypomnienia i odłożenie zadania;
- powtarzalne zadania;
- historię ukończeń;
- ekran podsumowania tygodnia oraz przypomnienie o przeglądzie w poniedziałek o 00:00;
- ustawienia organizera.

Nie obejmuje współdzielonych list, płatności, reklam ani funkcji iOS.

## Wygląd i responsywność

Interfejs ma czerpać z systemowego stylu Apple: dużo oddechu, zaokrąglone powierzchnie, czysta typografia, dobrze widoczne stany interakcji i oszczędny akcent niebieski.

Gradient jest tylko tłem dwóch ważnych powierzchni: karty „Teraz” oraz karty podsumowania tygodnia. Jest pionowy, bardzo subtelny i używa odcieni granatu, błękitu oraz powierzchni motywu. Karty listy pozostają jednolite, aby zadania były łatwe do skanowania. Emoji zostają małymi znakami kategorii, nigdy dekoracją całej karty.

Na telefonie (szerokość poniżej 720 px) treść ma pojedynczą kolumnę, przycisk szybkiego dodania ma łatwy zasięg kciuka, a elementy nawigacji pozostają kompaktowe. Na komputerze jest boczna nawigacja, szersza treść oraz pływający przycisk szybkiego dodania. Listy nie używają ciężkich animacji; zmieniają tylko stan pojedynczego zadania, dzięki czemu przewijanie pozostaje płynne.

## Model danych

`tasks` pozostaje główną tabelą synchronizowaną przez Supabase. Dodane pola:

- `completed_at timestamptz`: data ukończenia konkretnego wystąpienia zadania;
- `reminder_at timestamptz`: osobny czas przypomnienia; gdy jest pusty, używany jest termin zadania, jeśli zawiera godzinę;
- `repeat_rule jsonb`: `null` albo reguła `{ "unit": "day" | "week" | "month", "interval": positive integer, "weekdays": [1..7] }`;
- `pinned_today boolean`: uczestniczy w planie dnia.

Obecne kolumny `repeat_rule`, `reminder_at` i `pinned_today` już istnieją w bazie; migracja dodaje tylko `completed_at` oraz indeks do przeglądów tygodniowych. Lokalne zadania zapisują te same pola w `SharedPreferences`.

Zadanie cykliczne po ukończeniu nie jest nadpisywane. Bieżące wystąpienie otrzymuje `status = done` i `completed_at`, a kolejne zadanie dostaje nowy identyfikator, zachowuje opis, kategorię, priorytet i `repeat_rule`, lecz zaczyna jako `todo`, bez przypięcia i z odznaczonymi checklistami. Dzięki temu historia tygodnia jest zachowana.

## Plan dnia

Każde aktywne zadanie ma w menu akcję „Przypnij do dzisiaj” lub „Odepnij z planu”. Plan pokazuje przypięte zadania przed zwykłą listą. Próba przypięcia czwartego zadania wyświetla zrozumiały komunikat i nie zmienia danych. Zadania ukończone automatycznie tracą przypięcie.

## Przypomnienia i odłożenie

Przypomnienie jest planowane lokalnie na Androidzie i Windowsie. Użytkownik wybiera w edytorze: brak, termin zadania albo własną godzinę przypomnienia. Powiadomienie zawiera tytuł i akcje „Zrobione” oraz „Odłóż”.

„Odłóż” oferuje 15 minut, godzinę i jutro o 09:00. Wybranie opcji aktualizuje lokalny harmonogram oraz `reminder_at`; nie przesuwa samego terminu zadania. Jeśli system nie pozwala aplikacji wykonać akcji w zamkniętym procesie, aplikacja przywraca spójny stan po następnym uruchomieniu i pokazuje użytkownikowi tę samą decyzję w aplikacji.

## Powtarzalne zadania

Edytor udostępnia prosty wybór: brak, codziennie, co tydzień, co miesiąc, co N dni i co N tygodni. Dla tygodniowego wyboru użytkownik może wskazać dni tygodnia. Najbliższa data jest wyliczana po terminie ukończonego wystąpienia; jeśli data była pusta, używany jest moment ukończenia. Checklisty kolejnego wystąpienia są kopiowane jako nieukończone.

## Podsumowanie tygodnia

Tydzień trwa od poniedziałku 00:00 do niedzieli 23:59 w lokalnej strefie użytkownika. W poniedziałek o 00:00 aplikacja planuje lekkie lokalne przypomnienie: „Czas na przegląd tygodnia”. Treść danych jest wyliczana w aplikacji przy jej otwarciu, żeby nie udawać działania w tle na systemach, które mogły zamknąć proces.

Widok „Przegląd tygodnia” zawiera:

- liczbę ukończonych zadań w poprzednim tygodniu;
- listę nieukończonych zadań z minionym terminem;
- trzy najbliższe aktywne terminy;
- przycisk przejścia do planu dnia.

## Ustawienia

Istniejący motyw jasny, ciemny i systemowy zostaje zachowany. Nowa sekcja „Organizer” pozwala ustawić domyślny czas przypomnień, domyślne odłożenie oraz godzinę przeglądu tygodnia. Domyślnie przegląd jest ustawiony na poniedziałek 00:00.

## Synchronizacja i błędy

Każda zmiana zadania, przypięcia, przypomnienia, ukończenia i następnego wystąpienia jest najpierw zapisana lokalnie, a potem synchronizowana dla zalogowanego użytkownika. Dla istniejącej strategii konfliktów pozostaje zasada ostatniej zmiany. Awaria synchronizacji nie usuwa lokalnego stanu; użytkownik widzi komunikat o ponownej próbie.

## Testy akceptacyjne

- Można przypiąć trzy zadania i nie można przypiąć czwartego.
- Ukończenie przypiętego zadania usuwa je z planu.
- Każdy typ powtarzalności tworzy właściwe kolejne wystąpienie i zachowuje poprzednie w historii.
- Checklisty kolejnego wystąpienia są odznaczone.
- Przypomnienie jest harmonogramowane, anulowane po ukończeniu oraz aktualizowane po odłożeniu.
- Przegląd tygodnia poprawnie oddziela poprzedni tydzień od bieżącego według lokalnej daty.
- Telefon i komputer używają tego samego zestawu danych po synchronizacji.
- Widoki mieszczą się na telefonie i komputerze, a analiza oraz testy Fluttera przechodzą bez błędów.
