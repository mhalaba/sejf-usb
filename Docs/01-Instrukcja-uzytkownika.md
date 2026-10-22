# Sejf USB 1.3 — instrukcja użytkownika

Sejf USB szyfruje pliki w folderze `Sejf.vault`, który może leżeć na pendrivie albo na Macu. Do otwarcia sejfu potrzebne są dwie rzeczy:

- **hasło**, które znasz;
- **YubiKey**, którego musisz fizycznie dotknąć.

Bez którejkolwiek z nich danych nie da się odczytać. Aplikacja działa w 100% offline.

## Wymagania

- macOS 14 (Sonoma) lub nowszy, Mac z procesorem Apple albo Intel.
- Klucz FIDO2 z rozszerzeniem `hmac-secret`. Sloty OTP pozostają nietknięte, a kod PIN FIDO2 jest potrzebny tylko na starszych kluczach i tylko przy rejestracji.

### Zgodne klucze

| Klucz | Działa? | Uwagi |
|---|---|---|
| YubiKey 5 / 5C / 5 NFC / 5C NFC / 5Ci / Nano | ✅ przetestowany | widoczny model i numer seryjny |
| **Security Key NFC / Security Key C NFC** (tańszy) | ✅ wykrywanie i rozpoznawanie przetestowane | brak numeru seryjnego — aplikacja rozpoznaje go po poświadczeniu, bez dotyku |
| YubiKey Bio | ⚠️ powinien działać | nie testowany; wystarcza dotyk, odcisk palca nie jest używany |
| YubiKey 5 FIPS | ⚠️ powinien działać | w trybie FIPS wymaga PIN-u przy rejestracji; nie testowany |
| starsze klucze tylko U2F (np. niebieski „FIDO U2F Security Key”) | ❌ | brak FIDO2 `hmac-secret` — aplikacja to wykryje i powie |
| inne klucze FIDO2 z `hmac-secret` (np. Nitrokey 3, SoloKey 2, Feitian) | ⚠️ | nie testowane |

**NFC a Mac:** Maki nie mają czytnika NFC, więc także klucz „NFC” wkładasz do portu USB (A lub C, zależnie od modelu). NFC przydaje się przy telefonie, a Sejf USB jest aplikacją na Maca.

**PIN FIDO2:** jeśli klucz go wymaga (starsze klucze z ustawionym PIN-em), aplikacja poprosi o niego przy tworzeniu sejfu albo dodawaniu klucza. PIN zostaje w kluczu i nie jest nigdzie zapisywany. Po 8 błędnych próbach funkcje FIDO2 klucza zostają zablokowane.

## 1. Gdzie co trzymać

| Co | Gdzie | Dlaczego |
|---|---|---|
| Aplikacja | `~/Applications/Sejf USB.app` na **każdym** Macu, z którego korzystasz | kopię na pendrivie ktoś mógłby podmienić i przechwycić hasło |
| Sejf na Macu | np. `~/Sejf` | **poza** Pulpitem, Dokumentami i iCloud Drive (aplikacja blokuje foldery synchronizowane z iCloud) |
| Sejf na pendrivie | sam folder `Sejf.vault` | jest zaszyfrowany, więc może leżeć wszędzie |
| Hasło odzyskiwania | na papierze, w innym miejscu niż YubiKey | otwiera sejf bez klucza |
| Zapasowy YubiKey | w innym miejscu niż główny | zgubienie jedynego klucza = tylko hasło odzyskiwania |

## 2. Pierwsze uruchomienie (nowa instalacja)

Na Macu, na którym aplikacja nie zna jeszcze żadnego sejfu, zobaczysz trzy drogi:

| Wybór | Kiedy |
|---|---|
| **Utwórz nowy sejf** | zaczynasz od zera |
| **Otwórz mój sejf** | masz już sejf (np. na pendrivie) i swój YubiKey z hasłem |
| **Dołącz do sejfu** | ktoś udostępnia Ci swój sejf — patrz rozdział 7 |

Później ekran startowy to lista **„Twoje sejfy”**. Lista jest zapamiętana tylko na tym Macu, a usunięcie sejfu z listy (prawy przycisk) nie kasuje plików. Przycisk z nazwą sejfu w nagłówku okna wraca do listy.

## 3. Tworzenie sejfu

1. **„Nowy sejf”** → wpisz nazwę (jest widoczna bez odblokowania, więc nie wpisuj w niej nic tajnego) i wybierz miejsce:
   - **Na tym Macu**: `~/Sejfy/<nazwa>`, poza iCloud, z kopią w Time Machine;
   - **Na pendrivie**: w głównym folderze nośnika albo w podfolderze, jeśli na nośniku jest już inny sejf;
   - **W wybranym folderze**: poza Pulpitem, Dokumentami i iCloud Drive.
2. **Krok 1 z 2:**
   - wpisz **swoje imię** (widzą je inni użytkownicy sejfu);
   - wpisz hasło dwa razy, minimum 12 znaków, najlepiej 4–5 przypadkowych słów;
   - **klucza jeszcze nie dotykaj**.
3. **Krok 2 z 2:** gdy pojawi się „Teraz dotknij złotego przycisku (1/2)”, dotknij klucza krótko, potem jeszcze raz przy „(2/2)”.
4. **Hasło odzyskiwania** (32 znaki) przepisz ręcznie na papier. Nie kopiuj go, nie fotografuj i nie zapisuj w pliku.

Każda osoba może mieć dowolnie wiele własnych sejfów, np. „Prywatne”, „Firma”, „Rodzina”. Każdy ma osobny klucz główny i osobne hasło odzyskiwania.

> **Klucz „wpisał” dziwny ciąg znaków?** Dotknięcie YubiKeya w chwili, gdy aplikacja o to nie prosi, wpisuje kod OTP jak klawiatura. Aplikacja wykrywa to i usuwa go z pola hasła.

## 4. Odblokowanie

1. Wpisz hasło i kliknij **„Dalej: YubiKey”**.
2. Dotknij klucza, gdy aplikacja o to poprosi. Wystarczy jedno dotknięcie.

**Gdy zgubisz YubiKey:**
1. Kliknij „Zgubiłem YubiKey — użyj hasła odzyskiwania” i wpisz kod z kartki.
2. Potem od razu zrób **🔑 → Wymień klucz główny** z nowym kluczem (rozdział 8).

## 5. Szyfrowanie plików

- **„Dodaj pliki”** albo przeciągnięcie plików lub folderów do okna. Do wyboru masz dwie opcje:
  - **„Zaszyfruj i usuń oryginały”**: oryginał znika dopiero wtedy, gdy kontrolne odszyfrowanie da identyczny plik (SHA-256).
  - **„Tylko zaszyfruj”**: oryginały zostają.
- **„Zaszyfruj pendrive” / „Zaszyfruj pliki z folderu”** zabezpiecza to, co leży obok sejfu.
- Szyfrowane są także pliki ukryte (np. `.env`). Pomijane są tylko śmieci systemowe (`.DS_Store`, `._*`). Folder jest usuwany tylko wtedy, gdy nic w nim nie zostało.
- Dowiązania symboliczne są pomijane i zgłaszane, a ich cel nie jest ruszany.

## 6. Odczyt plików

- **Podwójne kliknięcie** otwiera podgląd. Plik jest odszyfrowywany do prywatnego katalogu tymczasowego, który zostaje zniszczony przy blokadzie sejfu.
- **„Odszyfruj…”** zapisuje kopię we wskazanym folderze, domyślnie w Pobranych. Kopia dostaje uprawnienia tylko dla Ciebie (0600).
  - Zapis do folderów iCloud jest zablokowany.
  - Usuń kopię, gdy przestanie być potrzebna.

## 7. Użytkownicy: dołączanie do sejfu

Jeden sejf może mieć kilku użytkowników. Każdy ma **własny YubiKey i własne hasło**, wszyscy widzą te same pliki i każdy może zarządzać kluczami. Dodawaj więc tylko zaufane osoby.

**Dołączenie nowej osoby (oboje przy jednym Macu, także na nowej instalacji):**
1. Nowa osoba instaluje aplikację (patrz `02-Instalacja.md`) i wybiera **„Dołącz do sejfu”**, wskazując folder sejfu (np. na wspólnym pendrivie).
2. Osoba, która ma już dostęp, **odblokowuje sejf swoim kluczem i hasłem** (albo hasłem odzyskiwania).
3. Otworzy się okno **„Dodaj użytkownika lub klucz”**:
   - wpisz imię nowej osoby;
   - wyjmij klucz osoby z dostępem i włóż klucz nowej osoby (podłączony może być tylko ten jeden);
   - **nowa osoba sama wpisuje swoje hasło**;
   - kliknij „Dodaj” i dotknij nowego klucza dwa razy.
4. Gotowe. Od teraz nowa osoba otwiera sejf swoim kluczem i hasłem, a aplikacja wita ją po imieniu.

Klucz główny nie opuszcza przy tym komputera i nie jest nigdzie wysyłany.

To samo okno służy do dodania **zapasowego klucza** istniejącej osoby (opcja „Zapasowy klucz istniejącej osoby”). Okno otworzysz też w dowolnej chwili: **🔑 → Dodaj użytkownika lub klucz**.

**Ważne przy wspólnym sejfie:** wszyscy pracują na tym samym folderze `Sejf.vault`. Kopie sejfu nie synchronizują się same, a dodanie użytkownika zmienia tylko kopię, na której to zrobiono.

## 8. Hasło i klucze

| Funkcja | Gdzie | Uwagi |
|---|---|---|
| **Zmień hasło** | przycisk w oknie sejfu, menu Sejf, skrót **⇧⌘P** | dotyczy Twojego klucza; wymaga obecnego hasła i jednego dotknięcia |
| **Dodaj użytkownika lub klucz** | 🔑 | rozdział 7 |
| **Nowe hasło odzyskiwania** | 🔑 | stare hasło odzyskiwania przestaje działać |
| **Usuń klucz / użytkownika** | 🔑 | ostatniego klucza nie da się usunąć |
| **Wymień klucz główny** | 🔑 | patrz niżej |

Zmiana hasła, nowe hasło odzyskiwania i usunięcie klucza działają **dla bieżącego sejfu**. Stara kopia sejfu (np. z Time Machine) nadal otwiera się starym dostępem.

**Wymiana klucza głównego** to zabezpieczenie po zgubieniu klucza, wycieku hasła albo odebraniu komuś dostępu:
- wszystkie pliki są szyfrowane od nowa;
- zostaje tylko Twój podłączony klucz i **nowe** hasło odzyskiwania;
- **pozostali użytkownicy tracą dostęp**, więc dodaj ich potem ponownie;
- operacja jest odporna na przerwanie.

## 9. Blokada

Sejf blokuje się:
- ręcznie (**⌘L** lub „Zablokuj”);
- po 5 minutach bezczynności;
- przy uśpieniu Maca lub zablokowaniu ekranu;
- po odłączeniu nośnika.

Przy blokadzie znikają klucz z pamięci, podglądy i widoczne hasło odzyskiwania.

## 10. Ten sam sejf na kilku Macach

- Zainstaluj aplikację na każdym Macu (patrz `02-Instalacja.md`).
- Otwórz ten sam folder `Sejf.vault` (pendrive albo kopia) tym samym YubiKeyem i hasłem. Nic nie trzeba rejestrować.
- Nie edytuj jednocześnie dwóch kopii sejfu. Zmiany z jednej kopii nie przenoszą się same do drugiej.

## 11. Kopia zapasowa

Folder `Sejf.vault` jest zaszyfrowany, więc kopiuj go śmiało: na drugi dysk, do Time Machine, nawet do chmury. Do odczytu kopii nadal potrzebny jest YubiKey i hasło albo hasło odzyskiwania. Pendrive'y psują się bez ostrzeżenia.

## 12. Najczęstsze komunikaty

| Komunikat | Co zrobić |
|---|---|
| „Włóż YubiKey” | podłącz klucz; jeśli jest podłączony, wyjmij go i włóż ponownie |
| „nie dotknięto klucza na czas” | kliknij „Spróbuj ponownie” i dotknij w ciągu ~30 s |
| „Nieprawidłowe hasło lub YubiKey” | sprawdź hasło (Caps Lock) i czy to klucz zarejestrowany w tym sejfie |
| „Podłączonych jest kilka kluczy” | zostaw tylko jeden YubiKey |
| „Ten folder jest synchronizowany z iCloud” | wybierz folder poza Pulpitem, Dokumentami i iCloud Drive |
| „Uruchamiasz aplikację z nośnika wymiennego” | zainstaluj aplikację na Macu i uruchamiaj ją stamtąd |
| „Ten klucz jest już w sejfie” (przy dodawaniu) | wyjmij klucz osoby z dostępem i włóż klucz nowej osoby |
| sejf na liście „niedostępny” | podłącz pendrive z sejfem albo usuń sejf z listy (pliki zostają) |
