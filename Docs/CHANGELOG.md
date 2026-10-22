# Historia zmian

## 1.2

- **Nowa instalacja:** ekran powitalny z trzema drogami: utwórz nowy sejf, otwórz mój sejf, dołącz do sejfu.
- **Własne sejfy:** lista „Twoje sejfy” (wiele sejfów, nazwy, miejsca, sejfy wykryte na pendrive'ach). Kreator nowego sejfu z nazwą i wyborem miejsca (Mac `~/Sejfy/<nazwa>`, pendrive, wybrany folder).
- **Użytkownicy:** imię właściciela klucza, „Dodaj użytkownika lub klucz” (nowa osoba albo zapasowy klucz istniejącej), dołączanie do istniejącego sejfu przy jednym Macu, powitanie po imieniu, oznaczenie „to Ty” w panelu kluczy.
- Wymiana klucza głównego wymienia z imienia użytkowników, którzy stracą dostęp.
- Format nagłówka zgodny wstecz (pola `name` i `owner` są opcjonalne).

## 1.1

**Bezpieczeństwo (po pełnym audycie):**
- Blokada folderów synchronizowanych z iCloud (sejf i odszyfrowane pliki).
- Bezpieczne usuwanie oryginałów: pliki ukryte są szyfrowane, a nie kasowane. Usuwane są tylko naprawdę puste foldery. Dowiązania nie są śledzone.
- **Wymiana klucza głównego**: pełne ponowne szyfrowanie, które unieważnia stare klucze, hasła i kopie nagłówka. Jest odporna na przerwanie.
- **Zmiana hasła** z weryfikacją obecnego hasła (przycisk, menu, ⇧⌘P).
- Odszyfrowane pliki z uprawnieniami 0600, domyślnie w Pobranych. Podglądy są sprzątane po awarii.
- Ochrona przed zrzutami ekranu dla wszystkich okien. Hasło odzyskiwania jest niezaznaczalne i ukrywane przy blokadzie.
- Ostrzeżenie przy uruchomieniu aplikacji z nośnika wymiennego. `build.sh` instaluje w `~/Applications`.
- Utwardzone parsery CTAPHID, CBOR i formatu pliku.
- Usunięty martwy kod: tryb OTP, slot 2, `ykman`.

**Funkcje:**
- „Dodaj pliki” i przeciąganie z wyborem „Zaszyfruj i usuń oryginały”, bez folderu pośredniego.
- Prośby o dotknięcie i postęp operacji z panelu kluczy są widoczne w głównym oknie.

## 1.0

- Pierwsza wersja: sejf AES-256-GCM, hasło + YubiKey (FIDO2 `hmac-secret`, natywnie, bez zgód systemowych), hasło odzyskiwania, zapasowe klucze, automatyczna blokada, dwuetapowe tworzenie i odblokowanie, wykrywanie przypadkowo „wpisanego” kodu OTP.
