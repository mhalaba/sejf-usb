# FIPS 140: what Sejf USB meets and what it does not

## In short

- **Sejf USB has no FIPS 140 certificate**, and code alone cannot earn one. The certificate is issued by NIST (the CMVP programme) after a module is tested in an accredited laboratory. That takes months or years and costs tens to hundreds of thousands of dollars.
- **FIPS 140-2 Level 4 is out of reach** for any software:
  - Level 4 covers hardware (HSMs) whose enclosure detects intrusion and erases its keys when attacked;
  - software can reach at most Level 1–2;
  - no YubiKey has Level 4.
- **FIPS 140-2 is retired.** New validations have been done under FIPS 140-3 since 2021, and in September 2026 all FIPS 140-2 certificates moved to the historical list.
- **What we actually did (since version 1.3):** the vault uses **only NIST-approved algorithms**, executed by **Apple's system cryptographic module (corecrypto)**, which holds FIPS 140-3 validation. The app also runs **power-up self-tests** modelled on FIPS 140-3 requirements.

## Algorithms and standards

| Purpose | Algorithm | NIST standard | Parameters |
|---|---|---|---|
| file encryption | AES-256-GCM | SP 800-38D | separate key per file; deterministic nonce (32 fixed bits + 64-bit counter, §8.2.1) |
| master key protection | AES-256-GCM (AEAD) | SP 800-38D | AAD binds the key to the vault and slot parameters ¹ |
| key from password | PBKDF2-HMAC-SHA-256 | SP 800-132 | 256-bit salt, 3,000,000 iterations, 256-bit output |
| combining password and hardware key | HKDF-SHA-256 | SP 800-56C rev. 2 | extract-and-expand, `info` contains the vault ID |
| hash | SHA-256 | FIPS 180-4 | |
| authentication | HMAC-SHA-256 | FIPS 198-1 | |
| key agreement with the YubiKey | ECDH P-256 | SP 800-56A rev. 3 | CTAP2 PIN/UV protocol 1 |
| encrypting the salt / PIN for the key | AES-256-CBC | SP 800-38A | required by CTAP2 |
| random numbers | system DRBG | SP 800-90A | `SecRandomCopyBytes` (corecrypto) |

¹ The textbook key-wrapping mode is AES-KW (SP 800-38F). AES-GCM is an approved AEAD mode that serves the same purpose.

The code contains no cryptography implemented by itself. Everything goes through CryptoKit and CommonCrypto, which use corecrypto. Look up current certificate numbers for your macOS version in the NIST CMVP search (term: *Apple corecrypto*).

## Power-up self-tests

On every launch the app checks (`Sources/Core/SelfTest.swift`):

| Test | Vector |
|---|---|
| SHA-256 | FIPS 180-4 (“abc”) |
| HMAC-SHA-256 | RFC 4231, case 1 |
| HKDF-SHA-256 | RFC 5869, case 1 |
| PBKDF2-HMAC-SHA-256 | RFC 7914 |
| AES-256 | FIPS 197, appendix C.3 |
| AES-256-GCM | encryption, decryption and tamper detection (GCM vector #14) |
| ECDH P-256 | pairwise consistency test |
| random generator | consecutive blocks differ and are non-zero |

All vectors were independently verified with OpenSSL. If any test fails, the app **refuses to process data**. The result is shown in the vault window footer (“self-tests 10/10”).

## What this does NOT give you

- Formal FIPS 140-2/140-3 compliance. That would need a CMVP certificate for this app, a defined module boundary, a NIST-approved security policy and standard-conformant authenticated roles.
- Guaranteed zeroisation of secrets in memory. CryptoKit keys are wiped, but passwords as Swift strings are not.
- Validation of the hardware key: a regular YubiKey 5 and the Security Key NFC are **not** FIPS certified.

## If you need formal compliance (e.g. tenders, government)

1. A validated key: the **YubiKey 5 FIPS** (USB-A/USB-C, with or without NFC) has FIPS 140 validation for its module. Check the certificate level in NIST CMVP.
   - Note: in approved mode the key requires a FIDO2 PIN. Sejf USB supports a PIN during registration, but has **not been tested** with a FIPS key.
   - The YubiKey 5 FIPS is **more expensive**, not cheaper. The cheaper Security Key NFC has no FIPS validation.
2. Mac disk encryption: **FileVault** uses Apple modules with FIPS 140-3 validation.
3. Full compliance for the whole app would require validating it as a module in an accredited laboratory.
