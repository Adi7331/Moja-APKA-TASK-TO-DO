# Redesign interfejsu „Dzień po dniu”

## Cel

Ułatwić szybkie planowanie dnia na Androidzie i Windowsie bez przeładowanego, „dashboardowego” wyglądu. Aplikacja ma przypominać lekki, systemowy produkt: duża czytelność, spokojne powierzchnie, pojedynczy niebieski kolor akcji oraz emoji tylko jako znaczniki kontekstu zadania.

## Kierunek wizualny

- Tło: systemowa jasna lub ciemna powierzchnia; nie stosujemy gradientów jako dekoracji ekranu.
- Kolor akcji: błękit dla przycisku dodawania, zaznaczenia i ukończonych kroków.
- Powierzchnie: miękkie, zaokrąglone grupy list oraz delikatne separatory zamiast wielu kart z cieniami.
- Typografia: duży nagłówek ekranu, następnie proste, krótkie etykiety pomocnicze.
- Emoji: pojedynczy znacznik przy kategorii lub tytule zadania, np. `🎨` dla pracy kreatywnej i `🌿` dla domu. Emoji nie są wymagane, nie zastępują tekstu i nie są używane w menu.

## Ekran „Dzisiaj”

### Telefon

1. Góra ekranu pokazuje datę, nagłówek „Dzisiaj” i menu ustawień.
2. Bezpośrednio pod nią jest jedna karta skupienia „Teraz”, wskazująca najbliższe pilne zadanie. Jeżeli nie ma zadania z terminem, pokazuje neutralny komunikat zachęcający do wybrania jednej rzeczy.
3. Filtry statusu są poziomo przewijanym rzędem: `Dzisiaj`, `W trakcie`, `Gotowe`, `Wszystkie`.
4. Zadania są grupowane w sekcje `Najważniejsze` i `Później`. Sekcja pokazuje liczbę pozycji.
5. Każdy wiersz zadania ma co najmniej 44 px wysokości aktywnego obszaru: okrągły checkbox, tytuł, termin/kategorię, opcjonalną ikonę emoji i postęp checklisty.
6. Dolny przycisk `＋ Szybko zapisz zadanie` otwiera skrócony edytor nowego zadania.

### Windows

1. Lewy pasek nawigacji pokazuje: `Dzisiaj`, `Skrzynka`, `Nadchodzące`, `Ukończone`, `Ustawienia`.
2. Główna kolumna pokazuje ten sam plan dnia, co telefon, bez dodatkowych kart statystyk.
3. Kliknięcie zadania otwiera panel edycji po prawej stronie. Przy mniejszej szerokości panel jest modalnym oknem, aby lista nadal pozostała czytelna.

## Edytor zadania

- Tytuł i termin są zawsze widoczne na początku.
- Checklistę tworzą duże, łatwe do kliknięcia wiersze; można dodać krok w jednym polu.
- `Więcej opcji` rozwija opis, kategorię i priorytet. Dzięki temu szybkie dodanie zadania nie wymaga przewijania pełnego formularza.
- Zapis jest pojedynczym głównym przyciskiem. Usunięcie jest drugorzędną akcją z potwierdzeniem.
- Panel pokazuje krótki komunikat po lokalnym zapisie oraz czytelny komunikat, jeśli synchronizacja się nie udała.

## Architektura Flutter

`main.dart` przestaje zawierać całą warstwę prezentacji. Stan aplikacji i istniejąca integracja `TaskSyncService`, `LocalTaskStore` oraz `NotificationService` pozostają w kontrolerze aplikacji. Interfejs jest podzielony na:

- `app_theme.dart` — jasny i ciemny motyw oraz nazwy kolorów.
- `today_screen.dart` — układ telefonu/Windows i filtrowanie widoku przekazane przez parametry.
- `task_row.dart` — pojedyncze zadanie, wskaźnik postępu i obsługa kliknięcia.
- `task_editor.dart` — adaptacyjny panel/arkusz edycji zadania.
- `task_category_icon.dart` — bezpieczne, opcjonalne mapowanie kategorii na emoji.

Nowe komponenty nie wywołują Supabase bezpośrednio. Otrzymują dane oraz callbacki od aktualnego właściciela stanu. Dzięki temu interfejs pozostaje testowalny, a dotychczasowa synchronizacja i zapis offline nie zmieniają zachowania.

## Zachowanie i błędy

- Zmiana zadania najpierw aktualizuje widok lokalny; obecny mechanizm zapisu/synchronizacji wykonuje się później.
- Udany zapis pokazuje krótką, nieblokującą informację.
- Błąd połączenia lub zapisu pokazuje prosty komunikat z możliwością ponowienia, nie usuwa treści wprowadzonej przez użytkownika.
- Nie zmieniamy formatu danych `TaskItem`, tabel Supabase, subtasków ani powiadomień w ramach tej zmiany.

## Testy

- Test widgetu potwierdza nowe grupy zadań, filtry i szybkie dodanie zadania.
- Test widgetu potwierdza wyświetlenie postępu checklisty i zmianę stanu checkboxa.
- Test edytora potwierdza, że podstawowe pola są widoczne, a dodatkowe opcje można rozwinąć.
- Pełne `flutter analyze` i `flutter test` muszą przejść przed przekazaniem zmian.

## Poza zakresem

- Nie dodajemy w tej części Google OAuth, zadań cyklicznych, widgetu Androida, ikony w zasobniku Windows ani nowych zasad synchronizacji.
- Nie kopiujemy interfejsu Apple; inspiracją jest jedynie lekkość i systemowa czytelność.
