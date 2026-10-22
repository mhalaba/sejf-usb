# Building and testing

## Requirements

- macOS 14+ and the Command Line Tools. Full Xcode is not required.
  ```bash
  xcode-select --install
  ```
- No external dependencies or package managers.

## Commands

Core tests (cryptography, format, master key replacement, safe deletion, parsers, translations):

```bash
./build.sh test
```

Build the universal app (arm64 + x86_64), sign it ad hoc with the `com.apple.security.smartcard` entitlement, and install it in `~/Applications`:

```bash
./build.sh
```

Install somewhere else:

```bash
DEST=/target/folder ./build.sh
```

Without warnings-as-errors (e.g. with a different compiler version, as in CI):

```bash
STRICT=0 ./build.sh
```

## Code structure

| File | Contents |
|---|---|
| `Sources/Core/Vault.swift` | vault format, keyslots, file encryption, master key replacement, file selection |
| `Sources/Core/FIDO2.swift` | CTAPHID over IOKit HID; CTAP2 makeCredential / getAssertion with `hmac-secret`, silent check, PIN |
| `Sources/Core/CBOR.swift` | minimal canonical CBOR encoder/decoder with limits |
| `Sources/Core/YubiKeyCCID.swift` | key detection via FIDO2 (any FIDO2 key) + model and serial number via CCID when available |
| `Sources/Core/SelfTest.swift` | cryptographic power-up self-tests (FIPS 140-3 style) |
| `Sources/Core/Support.swift` | errors, randomness, PBKDF2/HKDF, recovery password, safe deletion, iCloud detection |
| `Sources/Core/Localization.swift` | `L("…")` function, language choice, safe value substitution |
| `Sources/Core/Translations+EN.swift` | English dictionary (key = Polish text from the code) |
| `Sources/App/*.swift` | SwiftUI interface (app model, views, theme) |
| `Tests/main.swift` | tests with a software FIDO2 key |
| `Resources/` | `Info.plist`, `Entitlements.plist`, icon, `pl.lproj` / `en.lproj` |

## Translations

- Every user-facing text in the code goes through `L("Polish text")`. Values are inserted with `%@` (or `%1$@`, `%2$@` for a different order).
- The English version lives in `Sources/Core/Translations+EN.swift`.
- The tests check that:
  - every text has a translation;
  - the number of value placeholders matches;
  - the dictionary has no unused entries;
  - no untranslated Polish text is left in the code.

To add a text, write `L("…")` in the code and add its translation to the dictionary. `./build.sh test` will tell you if anything is missing.

## What the tests check (selection)

- encrypting and decrypting files from 0 B to many chunks, with paths and non-ASCII characters;
- wrong password, wrong key, recovery password, backup key, password change (with current-password check);
- detection of a flipped byte, truncation, a removed last chunk, reordered chunks, a crafted chunk size;
- master key replacement: all files kept, old keys/passwords/header copies invalidated, interruption at two points;
- safe deletion: hidden files, symbolic and hard links, empty folders;
- iCloud folder detection;
- CBOR decoder robustness against crafted data;
- keys without a serial number (Security Key): silent recognition, re-registration blocked;
- cryptographic self-tests (10 known-answer and consistency tests);
- completeness and correctness of the English translation.

## Notes

- This environment (Command Line Tools only) lacks the SwiftUI macro plugin, so a custom `@Local` wrapper (`Theme.swift`) is used instead of `@State`. In Xcode you can switch back to `@State`.
- The code is compiled in Swift 5 mode with `-warnings-as-errors`.
