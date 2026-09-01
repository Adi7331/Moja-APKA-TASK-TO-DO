# Konfiguracja logowania Google

Wykonaj tę konfigurację dopiero po zbudowaniu aplikacji z obsługą Google OAuth. Hasło i sekret Google pozostają wyłącznie w panelach Google i Supabase.

## 1. Google Cloud

1. Otwórz [Google Cloud Console](https://console.cloud.google.com/).
2. Utwórz projekt, np. `Dzien po dniu`.
3. Wejdź w **Google Auth Platform** i skonfiguruj ekran zgody: nazwę aplikacji oraz swój e-mail kontaktowy.
4. W **Data Access** zostaw tylko `openid`, e-mail i podstawowy profil. Nie dodawaj Gmaila, Dysku ani Kalendarza.
5. W **Clients** wybierz **Create client** → **Web application**.
6. Skopiuj Client ID i Client Secret w bezpieczne miejsce. Nie wklejaj ich do plików projektu.

## 2. Supabase

1. Otwórz projekt Supabase → **Authentication** → **Sign In / Providers** → **Google**.
2. Włącz Google.
3. Z tego panelu skopiuj dokładny adres **Callback URL** i wklej go w Google Cloud jako **Authorized redirect URI**.
4. W Supabase wklej Client ID oraz Client Secret z Google Cloud i zapisz.
5. Wejdź w **Authentication** → **URL Configuration** i dodaj do listy Redirect URLs dokładnie:

   ```text
   dzienpodniu://login-callback/
   ```

## 3. Test

1. Uruchom aplikację Windows lub Android.
2. Kliknij **Kontynuuj z Google**.
3. Po zalogowaniu wróć do aplikacji i sprawdź, czy otwiera się lista zadań.
4. Dodaj zadanie na jednym urządzeniu i sprawdź je na drugim.

## Bezpieczeństwo

- Client Secret Google nie może trafić do `.env`, kodu, komunikatu na czacie ani GitHuba.
- Publikowalny klucz Supabase jest inny niż Client Secret Google; tylko pierwszy jest przeznaczony do aplikacji klienckiej.
- Jeśli przypadkowo ujawnisz Client Secret, usuń go w Google Cloud i utwórz nowy, następnie podmień go w Supabase.
