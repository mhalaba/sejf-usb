# FIPS 140: co Sejf USB spełnia, a czego nie

## W skrócie

- **Sejf USB nie ma certyfikatu FIPS 140** i nie może go dostać samym kodem. Certyfikat wydaje NIST (program CMVP) po badaniu modułu w akredytowanym laboratorium. Trwa to miesiące lub lata i kosztuje dziesiątki do setek tysięcy dolarów.
- **FIPS 140-2 Level 4 jest nieosiągalny** dla jakiegokolwiek programu:
  - poziom 4 dotyczy sprzętu (HSM) z obudową wykrywającą włamanie, który przy próbie ataku sam kasuje klucze;
  - programy mogą uzyskać najwyżej poziom 1–2;
  - żaden YubiKey nie ma poziomu 4.
- **FIPS 140-2 jest wycofany.** Nowe walidacje prowadzi się od 2021 r. według FIPS 140-3, a we wrześniu 2026 r. wszystkie certyfikaty 140-2 trafiły na listę historyczną.
- **Co realnie zrobiliśmy (od wersji 1.3):** sejf używa **wyłącznie algorytmów zatwierdzonych przez NIST**, wykonywanych przez **systemowy moduł kryptograficzny Apple (corecrypto)**, który ma walidację FIPS 140-3. Aplikacja wykonuje też **samotesty przy starcie**, wzorowane na wymaganiach FIPS 140-3.

## Algorytmy i normy

| Do czego | Algorytm | Norma NIST | Parametry |
|---|---|---|---|
| szyfrowanie plików | AES-256-GCM | SP 800-38D | osobny klucz na plik; nonce deterministyczny (32 bity stałe + 64-bitowy licznik, §8.2.1) |
| ochrona klucza głównego | AES-256-GCM (AEAD) | SP 800-38D | AAD wiąże klucz z sejfem i parametrami slotu ¹ |
| klucz z hasła | PBKDF2-HMAC-SHA-256 | SP 800-132 | sól 256 bitów, 3 000 000 iteracji, wynik 256 bitów |
| łączenie hasła z kluczem sprzętowym | HKDF-SHA-256 | SP 800-56C rev. 2 | extract-and-expand, `info` z ID sejfu |
| skrót | SHA-256 | FIPS 180-4 | |
| uwierzytelnianie | HMAC-SHA-256 | FIPS 198-1 | |
| uzgodnienie klucza z YubiKeyem | ECDH P-256 | SP 800-56A rev. 3 | protokół PIN/UV 1 standardu CTAP2 |
| szyfrowanie soli / PIN-u dla klucza | AES-256-CBC | SP 800-38A | wymagane przez CTAP2 |
| liczby losowe | DRBG systemu | SP 800-90A | `SecRandomCopyBytes` (corecrypto) |

¹ Podręcznikowym trybem do „opakowywania” kluczy jest AES-KW (SP 800-38F). AES-GCM to zatwierdzony tryb AEAD, który spełnia tę samą funkcję.

Kod nie zawiera żadnej własnej implementacji kryptografii. Wszystko idzie przez CryptoKit i CommonCrypto, które korzystają z corecrypto. Numery aktualnych certyfikatów znajdziesz w wyszukiwarce NIST CMVP (hasło: *Apple corecrypto*), dla swojej wersji macOS.

## Samotesty przy starcie

Przy każdym uruchomieniu aplikacja sprawdza (`Sources/Core/SelfTest.swift`):

| Test | Wektor |
|---|---|
| SHA-256 | FIPS 180-4 („abc”) |
| HMAC-SHA-256 | RFC 4231, przypadek 1 |
| HKDF-SHA-256 | RFC 5869, przypadek 1 |
| PBKDF2-HMAC-SHA-256 | RFC 7914 |
| AES-256 | FIPS 197, dodatek C.3 |
| AES-256-GCM | szyfrowanie, odszyfrowanie i wykrycie zmiany (wektor GCM #14) |
| ECDH P-256 | test spójności par kluczy |
| generator losowy | kolejne bloki różne i niezerowe |

Wszystkie wektory sprawdzono niezależnie narzędziem OpenSSL. Jeśli którykolwiek test zawiedzie, aplikacja **odmawia przetwarzania danych**. Wynik widać w stopce okna sejfu („samotesty 10/10”).

## Czego to NIE daje

- Formalnej zgodności z FIPS 140-2/140-3: brak certyfikatu CMVP dla tej aplikacji, zdefiniowanej granicy modułu, polityki bezpieczeństwa zatwierdzonej przez NIST i ról uwierzytelnianych według normy.
- Gwarantowanego zerowania sekretów w pamięci. Klucze CryptoKit są czyszczone, ale hasła jako tekst w Swifcie — nie.
- Walidacji klucza sprzętowego: zwykły YubiKey 5 i Security Key NFC **nie** mają certyfikatu FIPS.

## Jeśli potrzebujesz formalnej zgodności (np. przetargi, administracja)

1. Klucz z walidacją: **YubiKey 5 FIPS** (USB-A/USB-C, z NFC lub bez) ma walidację FIPS 140 dla swojego modułu. Poziom certyfikatu sprawdź w NIST CMVP.
   - Uwaga: w trybie zatwierdzonym klucz wymaga ustawionego PIN-u FIDO2. Sejf USB obsługuje PIN przy rejestracji, ale **z kluczem FIPS nie był testowany**.
   - YubiKey 5 FIPS jest **droższy**, nie tańszy. Tańszy Security Key NFC nie ma walidacji FIPS.
2. Szyfrowanie dysku Maca: **FileVault** korzysta z modułów Apple z walidacją FIPS 140-3.
3. Pełna zgodność całej aplikacji wymagałaby jej walidacji jako modułu w akredytowanym laboratorium.
