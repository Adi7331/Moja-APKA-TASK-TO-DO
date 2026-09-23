# Google login — projekt integracji

## Cel

Użytkownik może zalogować się do „Dzień po dniu” kontem Google zarówno na Androidzie, jak i Windowsie. Po poprawnym logowaniu aplikacja przechodzi do zsynchronizowanej listy zadań. Logowanie e-mail i hasło pozostaje bez zmian.

## Wybrany przepływ

Jedna ścieżka OAuth uruchamia systemową przeglądarkę. Google uwierzytelnia użytkownika, Supabase odbiera odpowiedź OAuth, a następnie przekierowuje do zarejestrowanego adresu aplikacji. Aplikacja kończy wymianę kodu PKCE i rozpoczyna istniejącą synchronizację.

Nie używamy osobnego SDK Google dla Androida ani Windowsa. Ogranicza to liczbę różnych konfiguracji i pozwala utrzymać ten sam sposób logowania na obu platformach.

## Zmiany w aplikacji

- Przycisk „Kontynuuj z Google” uruchamia `signInWithOAuth` dla dostawcy Google.
- Aplikacja rejestruje głęboki link `dzienpodniu://login-callback` dla Androida i Windowsa.
- Po otrzymaniu adresu zwrotnego klient Supabase wymienia kod na sesję, a ekran przechodzi do istniejącego `_enterCloudMode`.
- Ekran logowania pokazuje stan „Otwieram Google…” i czytelny komunikat błędu zamiast cichego niepowodzenia.
- Sesja jest zarządzana przez `supabase_flutter`; po restarcie aplikacja sprawdza istniejącą sesję i odtwarza tryb chmury.

## Konfiguracja poza kodem

1. W Google Cloud powstaje klient OAuth typu **Web application**.
2. Do klienta Google dodajemy dokładny adres callback wskazany przez panel Google Provider w projekcie Supabase.
3. Client ID i Client Secret trafiają tylko do **Supabase Dashboard → Authentication → Sign In / Providers → Google**. Nie trafiają do pliku `.env`, repozytorium ani aplikacji.
4. W Supabase Redirect URLs dodajemy `dzienpodniu://login-callback`.
5. W Google ustawiamy tylko wymagane scope'y: `openid`, e-mail i podstawowy profil.

## Bezpieczeństwo

- Klucz publikowalny Supabase może pozostać w aplikacji; sekret OAuth Google nie może.
- Nie prosimy o dostęp do Gmaila, Dysku ani Kalendarza.
- Nie używamy danych z `user_metadata` do autoryzacji. Obecne RLS na tabelach ogranicza dane do `auth.uid()`.
- Przekierowanie jest stałe, nie pobieramy go z pola w interfejsie ani z parametrów URL.

## Obsługa błędów

- Anulowanie w przeglądarce pozostawia użytkownika na ekranie logowania.
- Brak konfiguracji Google w Supabase pokazuje komunikat, że administrator musi dokończyć konfigurację.
- Błąd wymiany kodu nie włącza trybu chmury i nie dotyka lokalnych zadań.

## Testy

- Test interfejsu: kliknięcie Google przełącza stan ładowania i obsługuje sukces/błąd przez wstrzykniętą funkcję logowania.
- Test usługi: poprawny callback kończy sesję, błędny callback zwraca błąd bez zmiany trybu.
- Test ręczny Android i Windows: logowanie, anulowanie, restart z aktywną sesją i synchronizacja utworzonego zadania.

## Poza zakresem

Nie dodajemy iOS, dostępu do usług Google poza tożsamością użytkownika, łączenia kont ani udostępniania list.
