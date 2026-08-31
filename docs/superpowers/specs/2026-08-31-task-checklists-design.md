# Checklisty zadań — projekt

## Cel

Każde zadanie może zawierać uporządkowaną listę małych kroków. Kroki są
odznaczane niezależnie i synchronizują się między zalogowanymi urządzeniami
tego samego użytkownika.

## Dane

Nowa tabela `public.subtasks` będzie zawierać: UUID kroku, identyfikator
zadania, identyfikator właściciela, tekst kroku, pozycję na liście, stan
ukończenia i czas ostatniej zmiany. Usunięcie zadania usuwa jego kroki przez
klucz obcy `on delete cascade`.

Tabela będzie miała RLS oraz osobne polityki SELECT, INSERT, UPDATE i DELETE
dla roli `authenticated`. Każda polityka porówna `user_id` z `auth.uid()`;
polityka UPDATE użyje zarówno `using`, jak i `with check`.

## Interfejs

W panelu edycji zadania użytkownik zobaczy sekcję „Małe kroki”. Może dopisać
krok, odhaczyć go albo usunąć. Główna lista pokaże licznik, np. `2/4 kroków`,
tylko gdy zadanie ma co najmniej jeden krok.

## Synchronizacja

Kroki będą ładowane wraz z zadaniem i aktualizowane w Supabase. Tabela
`subtasks` zostanie dodana do publikacji `supabase_realtime`, dzięki czemu
zmiany z Androida pojawią się na Windows bez ręcznego odświeżania.

W trybie lokalnym kroki będą zapisane razem z zadaniem w obecnym lokalnym
magazynie. W chmurze źródłem prawdy jest Supabase; konflikt rozwiązuje późniejsza
zmiana pola `updated_at`.

## Obsługa błędów i testy

Nieudany zapis w chmurze pozostawia ekran otwarty i pokazuje komunikat.
Testy obejmą zapis oraz odczyt lokalny, licznik postępu, dodanie i odhaczenie
kroku oraz reguły SQL ograniczające dostęp do właściciela.
