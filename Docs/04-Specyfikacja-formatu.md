# Specyfikacja formatu sejfu (wersja 1)

Format jest zgodny wstecz: nagłówki z 1.1 (bez `name` i `owner`) otwierają się w 1.2 bez zmian.

Wszystkie liczby wielobajtowe są zapisane w kolejności **big-endian**, chyba że zaznaczono inaczej. `‖` oznacza konkatenację.

## Struktura katalogu

```
Sejf.vault/
├── header.json          nagłówek (JSON)
├── header.bak.json      identyczna kopia nagłówka (używana, gdy główny jest uszkodzony)
├── data/
│   └── <32 znaki hex>.sejf   jeden zaszyfrowany plik
├── header.next.json     tylko w trakcie wymiany klucza głównego
├── data.new/, data.old/ tylko w trakcie wymiany klucza głównego
```

## Nagłówek (`header.json`)

```json
{
  "format": "sejf-usb",
  "version": 1,
  "vaultID": "<16 B, base64>",
  "created": 1792936923.1,
  "chunkSize": 1048576,
  "keyslots": [ { … }, { … } ],
  "name": "Dokumenty rodzinne"          // opcjonalne (od 1.2), jawne
}
```

### Keyslot

| Pole | Typ | Opis |
|---|---|---|
| `id` | tekst (UUID) | identyfikator |
| `kind` | `"fido2"` / `"recovery"` | rodzaj |
| `label` | tekst | nazwa (niechroniona) |
| `created` | liczba | czas utworzenia (Unix) |
| `serial` | liczba? | numer seryjny YubiKeya (informacyjnie) |
| `challenge` | base64? | FIDO2: sól `hmac-secret` (32 B, wspólna dla wszystkich slotów FIDO2) |
| `salt` | base64 | sól KDF (32 B) |
| `iterations` | liczba? | iteracje PBKDF2 (3 000 000) |
| `credentialID` | base64? | FIDO2: ID poświadczenia |
| `wrappedKey` | base64 | AES-256-GCM combined: `nonce(12) ‖ szyfrogram(32) ‖ tag(16)` |
| `owner` | tekst? | imię użytkownika (od 1.2, jawne, nieuwierzytelnione — tylko do wyświetlania) |

**AAD keyslota:**
`"sejf-usb/v1/keyslot" ‖ vaultID ‖ id(UTF-8) ‖ kind(UTF-8) ‖ challenge ‖ salt ‖ BE64(iterations lub 0) ‖ credentialID`
(pola nieobecne dają pusty ciąg)

### Wyprowadzanie klucza (KEK)

- **FIDO2:**
  ```
  pw  = PBKDF2-HMAC-SHA256(NFC(hasło), salt, iterations, 32 B)
  hs  = FIDO2 hmac-secret(credentialID, challenge)          — 32 B, wymaga dotknięcia
  KEK = HKDF-SHA256(ikm = pw ‖ hs, salt = salt, info = "sejf-usb/v1/fido2-kek" ‖ vaultID, 32 B)
  ```
- **Hasło odzyskiwania:** 20 B zakodowane Base32 Crockforda (32 znaki, grupy po 4, przy odczycie `O→0`, `I/L→1`)
  ```
  KEK = HKDF-SHA256(ikm = 20 B, salt = salt, info = "sejf-usb/v1/recovery-kek" ‖ vaultID, 32 B)
  ```

### Parametry FIDO2

- RP ID: `sejf-usb`.
- makeCredential: ES256, `rk = false`, rozszerzenie `hmac-secret = true`, bez UV.
- getAssertion: `allowList` ze wszystkimi `credentialID` slotów FIDO2, `up = true`, `hmac-secret` z jedną solą 32 B, PIN/UV protocol 1 (ECDH P-256 → SHA-256 → AES-256-CBC z zerowym IV, HMAC-SHA-256 obcięty do 16 B).
- Klucz zwraca ID swojego poświadczenia, co wskazuje właściwy keyslot (jedno dotknięcie).

## Zaszyfrowany plik (`data/<fileID hex>.sejf`)

```
nagłówek (25 B):  "SEJF"(4) ‖ wersja 0x01 (1) ‖ fileID (16) ‖ BE32(chunkSize)
fragment i:       BE32(n) ‖ szyfrogram ‖ tag(16)          n = długość szyfrogramu + 16
```

- Nazwa pliku musi być równa `hex(fileID) + ".sejf"`, a `chunkSize` musi zgadzać się z nagłówkiem sejfu.
- Klucz pliku: `HKDF-SHA256(ikm = klucz główny, salt = fileID, info = "sejf-usb/v1/file" ‖ vaultID, 32 B)`.
- Nonce fragmentu `i`: `0x00000000 ‖ BE64(i)`.
- AAD fragmentu `i`: `nagłówek(25 B) ‖ BE64(i) ‖ (0x01 jeśli ostatni, inaczej 0x00)`.
- **Fragment 0** to metadane w JSON: `{"path": "…", "size": n, "modified": t, "added": t}` (≤ 1 MiB, nigdy ostatni).
- **Fragmenty 1…k** to treść po `chunkSize` bajtów. Ostatni fragment ma flagę 1. Pusty plik ma jeden pusty fragment z flagą 1.
- „Ostatni” oznacza, że fragment kończy się dokładnie na końcu pliku. Obcięcie, dopisanie albo przestawienie fragmentów kończy się błędem uwierzytelnienia.

## Wymiana klucza głównego (odporność na przerwanie)

1. Nowe keysloty (wybrany klucz FIDO2 i nowe hasło odzyskiwania) dla nowego klucza głównego.
2. Każdy plik jest odszyfrowywany strumieniowo i szyfrowany nowym kluczem (nowe `fileID`) do `data.new/`.
3. Zapis `header.next.json`.
4. `data/ → data.old/`, `data.new/ → data/`.
5. Zapis `header.json` i `header.bak.json` z nowymi slotami.
6. Usunięcie `data.old/` i `header.next.json`.

Przy otwarciu sejfu:
- `data.new` bez `data.old` oznacza **wycofanie** (usunięcie `data.new` i planu);
- obecność `data.old` z poprawnym `header.next.json` oznacza **dokończenie** kroków 4–6;
- sam `header.next.json` jest usuwany.
