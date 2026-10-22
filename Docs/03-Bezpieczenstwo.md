# Bezpieczeństwo: model, kryptografia, audyt

## Przed czym chroni

| Scenariusz | Ochrona |
|---|---|
| Kradzież lub zgubienie pendrive'a / kopii sejfu | ✅ bez YubiKeya **i** hasła (albo hasła odzyskiwania) dane są nie do odczytania |
| Ktoś zna hasło, ale nie ma klucza | ✅ odpowiedź klucza jest częścią klucza szyfrującego, nie „bramką” w programie |
| Ktoś ma klucz, ale nie zna hasła | ✅ musi zgadywać hasło; każda próba wymaga fizycznego dotknięcia klucza |
| Ktoś ukradł klucz **i** kopię sejfu | ⚠️ zostaje hasło (PBKDF2, 3 mln iteracji) — dlatego hasło ma być długie |
| Podmiana, obcięcie, przestawienie danych w sejfie | ✅ wykrywane (AES-GCM z numerem fragmentu i flagą „ostatni”) |
| Stara kopia sejfu po zmianie hasła / usunięciu klucza | ⚠️ działa starym dostępem, dopóki nie wykonasz „Wymiany klucza głównego” |
| Zainfekowany Mac (keylogger, malware) | ❌ widzi to, co Ty, gdy sejf jest otwarty |
| Podmieniona aplikacja | ⚠️ ostrzeżenie przy uruchomieniu z nośnika; instaluj na Macu, sprawdzaj sumy SHA-256 |
| Odebranie dostępu innemu użytkownikowi | ⚠️ usunięcie klucza działa od razu dla bieżącego sejfu; pełne odcięcie (także od starych kopii) — „Wymiana klucza głównego” |

## Kryptografia

- **Klucz główny:** losowe 256 bitów. Nigdy nie jest zapisywany jawnie.
- **Klucz do pliku z kluczem (KEK)** przy hasło + YubiKey:
  `HKDF-SHA256( PBKDF2-HMAC-SHA256(hasło w NFC, sól 32 B, 3 000 000 iteracji) ‖ FIDO2 hmac-secret(sól 32 B) )`.
- **KEK przy haśle odzyskiwania:** `HKDF-SHA256(160 losowych bitów)`. Kod ma postać Base32 Crockforda, 32 znaki.
- **Zapis klucza głównego:** każdy keyslot to klucz główny zaszyfrowany AES-256-GCM. AAD wiąże go z ID sejfu i wszystkimi parametrami slotu.
- **Pliki:**
  - każdy plik ma własny klucz `HKDF(klucz główny, losowe ID pliku)`;
  - plik dzieli się na fragmenty po 1 MiB, każdy szyfrowany AES-256-GCM, z nonce równym numerowi fragmentu;
  - AAD fragmentu to nagłówek pliku, numer fragmentu i flaga „ostatni”;
  - ścieżka i nazwa pliku są szyfrowane w fragmencie 0.
- **YubiKey:** FIDO2/CTAP2 `hmac-secret` (poświadczenie nierezydentne, wymagana obecność użytkownika, PIN/UV protocol 1).
  - Klucz liczy HMAC-SHA-256 sekretem, który **nigdy go nie opuszcza**.
  - Sloty OTP 1/2 i PIN FIDO2 nie są używane ani zmieniane.
- **Losowość:** `SecRandomCopyBytes`. **Biblioteki:** wyłącznie systemowe (CryptoKit, CommonCrypto, IOKit, CryptoTokenKit).

## Audyt bezpieczeństwa (wersja 1.0 → 1.1)

Pełny przegląd kodu, z potwierdzeniem kluczowych problemów testami na danych testowych. Wszystkie poniższe punkty naprawiono w 1.1.

| # | Waga | Problem | Poprawka |
|---|---|---|---|
| 1 | krytyczny (środowisko) | sejf utworzony w folderze Pulpitu synchronizowanym z iCloud — jawne pliki przed zaszyfrowaniem trafiłyby na serwery Apple | aplikacja wykrywa i blokuje foldery iCloud (sejf, odszyfrowane pliki); sejf przeniesiony do `~/Sejf` |
| 2 | wysoki | „usuń oryginały” kasowało niezaszyfrowane pliki ukryte (np. `.env`) razem z „pustym” folderem (potwierdzone testem) | ukryte pliki są szyfrowane; usuwane są tylko naprawdę puste foldery; brak śledzenia dowiązań; pliki z kilkoma dowiązaniami twardymi nie są nadpisywane |
| 3 | wysoki | aplikacja na pendrivie mogła zostać podmieniona | instalacja w `~/Applications`, ostrzeżenie przy uruchomieniu z nośnika, sumy SHA-256 w paczce |
| 4 | średni | brak unieważniania dostępu — usunięty klucz / stare hasło + stara kopia nagłówka otwierały wszystkie pliki | funkcja „Wymień klucz główny” (pełne ponowne szyfrowanie, odporne na przerwanie) |
| 5 | średni | odszyfrowane kopie domyślnie na Pulpit (iCloud), uprawnienia 0644 | domyślnie Pobrane, blokada iCloud, uprawnienia 0600, sprzątanie podglądów po awarii |
| 6 | średni | ochrona przed zrzutami ekranu tylko dla głównego okna; hasło odzyskiwania zaznaczalne i widoczne po blokadzie | ochrona wszystkich okien, kod niezaznaczalny, ukrywany przy blokadzie |
| 7 | średni | martwy kod (tryb OTP — kryptograficznie tylko hasło, slot 2, `ykman` przez `PATH`) | usunięty (~500 linii) |
| 8 | niski | spreparowane dane z urządzenia USB lub pliku sejfu mogły wywołać awarię lub ogromną alokację | ścisłe limity w parserach CTAPHID, CBOR i formatu pliku |

W 1.1 dodano też **zmianę hasła z weryfikacją obecnego hasła** (jedno dotknięcie klucza; nieudana próba nie zmienia nagłówka).

## Wielu użytkowników (1.2)

- Każdy użytkownik ma osobny keyslot FIDO2 ze swoim YubiKeyem i hasłem. Wszystkie keysloty chronią ten sam klucz główny, więc wszyscy mają równe prawa.
- **Dołączanie odbywa się tylko lokalnie:** sejf odblokowuje osoba z dostępem, nowa osoba wpisuje hasło i dotyka swojego klucza na tym samym Macu. Nie ma zaproszeń przez sieć ani plików z kluczem do przesłania, więc nie ma czego przechwycić.
- Imiona użytkowników i nazwy sejfów są zapisane **jawnie** w nagłówku, czyli widoczne bez odblokowania. Nie są uwierzytelnione: osoba z dostępem zapisu do plików mogłaby je zmienić, ale nie daje jej to dostępu do danych.

## Ograniczenia, o których trzeba wiedzieć

- **Nośniki flash, SSD, APFS:** nadpisanie pliku nie gwarantuje zniszczenia starych bloków. Lokalne migawki Time Machine trzymają stan dysku do ~24 h. Najlepiej, by jawne sekrety w ogóle nie trafiały na dysk.
- **iCloud:** pliki usunięte z Pulpitu i Dokumentów są jeszcze 30 dni w „Ostatnio usuniętych” na iCloud.com. Rozważ włączenie „Zaawansowanej ochrony danych”.
- **Pamięć:** Swift nie pozwala niezawodnie wyzerować haseł w pamięci procesu. Klucze CryptoKit są czyszczone automatycznie.
- **Metadane:** widoczna jest liczba plików i ich przybliżone rozmiary (nie nazwy).
- **PBKDF2** zamiast funkcji odpornej na GPU (Argon2). Ma to znaczenie tylko wtedy, gdy atakujący ma zarówno kopię sejfu, jak i Twój YubiKey.
- **Podpis „ad-hoc”** zamiast certyfikatu Apple Developer, więc brak notaryzacji. Integralność sprawdzaj sumami SHA-256 albo zbuduj aplikację ze źródeł.
- Zgubienie wszystkich kluczy **i** hasła odzyskiwania oznacza trwałą utratę danych. Nie ma tylnej furtki.
