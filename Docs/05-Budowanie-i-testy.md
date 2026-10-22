# Budowanie i testy

## Wymagania

- macOS 14+ i Command Line Tools. Pełny Xcode nie jest potrzebny.
  ```bash
  xcode-select --install
  ```
- Brak zależności zewnętrznych i menedżerów pakietów.

## Polecenia

Testy rdzenia (kryptografia, format, wymiana klucza, bezpieczne usuwanie, parsery):

```bash
./build.sh test
```

Budowa uniwersalnej aplikacji (arm64 + x86_64), podpis ad-hoc z uprawnieniem `com.apple.security.smartcard` i instalacja w `~/Applications`:

```bash
./build.sh
```

Instalacja w innym miejscu:

```bash
DEST=/ścieżka/docelowa ./build.sh
```

Nowa ikona aplikacji (po zmianie `Tools/make_icon.swift`):

```bash
swift Tools/make_icon.swift /tmp && iconutil -c icns /tmp/AppIcon.iconset -o Resources/AppIcon.icns
```

## Struktura kodu

| Plik | Zawartość |
|---|---|
| `Sources/Core/Vault.swift` | format sejfu, keysloty, szyfrowanie plików, wymiana klucza głównego, wybór plików |
| `Sources/Core/FIDO2.swift` | CTAPHID przez IOKit HID, CTAP2 makeCredential / getAssertion z `hmac-secret` |
| `Sources/Core/CBOR.swift` | minimalny, kanoniczny koder/dekoder CBOR z limitami |
| `Sources/Core/YubiKeyCCID.swift` | wykrywanie kluczy przez FIDO2 (każdy klucz FIDO2) + model i numer seryjny przez CCID, gdy dostępne |
| `Sources/Core/SelfTest.swift` | samotesty kryptograficzne przy starcie (styl FIPS 140-3) |
| `Sources/Core/Support.swift` | błędy, losowość, PBKDF2/HKDF, hasło odzyskiwania, bezpieczne usuwanie, wykrywanie iCloud |
| `Sources/App/*.swift` | interfejs SwiftUI (model aplikacji, widoki, motyw) |
| `Tests/main.swift` | testy z programowym odpowiednikiem klucza FIDO2 |
| `Resources/` | `Info.plist`, `Entitlements.plist`, ikona |

## Co sprawdzają testy (wybór)

- szyfrowanie i odszyfrowanie plików 0 B … wiele fragmentów, ze ścieżkami i polskimi znakami;
- złe hasło, inny klucz, hasło odzyskiwania, klucz zapasowy, zmiana hasła (z weryfikacją obecnego);
- wykrycie zmiany bajtu, obcięcia, usunięcia ostatniego fragmentu, przestawienia fragmentów, spreparowanego rozmiaru fragmentu;
- wymiana klucza głównego: komplet plików, unieważnienie starych kluczy, haseł i kopii nagłówka, przerwanie w dwóch momentach;
- bezpieczne usuwanie: pliki ukryte, dowiązania symboliczne i twarde, puste foldery;
- wykrywanie folderów iCloud;
- odporność dekodera CBOR na spreparowane dane;
- klucze bez numeru seryjnego (Security Key): ciche rozpoznanie, blokada ponownego dodania;
- samotesty kryptograficzne (10 testów znanych odpowiedzi i spójności).

## Uwagi

- W tym środowisku (same Command Line Tools) brakuje wtyczki makr SwiftUI, dlatego zamiast `@State` jest używany własny wrapper `@Local` (`Theme.swift`). W Xcode można wrócić do `@State`.
- Kod jest kompilowany w trybie Swift 5 z `-warnings-as-errors`.
