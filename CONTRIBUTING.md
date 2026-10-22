# Jak pomóc

1. Zbuduj i przetestuj:
   ```bash
   ./build.sh test
   ```
2. Zmiany w kryptografii, formacie sejfu lub komunikacji z YubiKeyem **muszą** mieć testy w `Tests/main.swift` (programowy klucz `SoftFIDO`) i zachować zgodność wstecz z istniejącymi sejfami (patrz [specyfikacja](Docs/04-Specyfikacja-formatu.md)).
3. Bez zewnętrznych zależności — tylko frameworki systemowe (CryptoKit, CommonCrypto, IOKit, CryptoTokenKit, SwiftUI).
4. Teksty interfejsu i dokumentacja są po polsku.
5. Problemy z bezpieczeństwem zgłaszaj prywatnie — patrz [SECURITY.md](SECURITY.md).
