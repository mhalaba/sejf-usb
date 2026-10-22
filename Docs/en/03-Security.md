# Security: threat model, cryptography, audit

## What it protects against

| Scenario | Protection |
|---|---|
| Theft or loss of the USB drive / a vault copy | ✅ without the YubiKey **and** the password (or the recovery password) the data cannot be read |
| Someone knows the password but has no key | ✅ the key's response is part of the encryption key, not a “gate” in the program |
| Someone has the key but not the password | ✅ they have to guess the password, and every attempt needs a physical touch of the key |
| Someone stole the key **and** a vault copy | ⚠️ only the password remains (PBKDF2, 3 million iterations) — so make it long |
| Tampering, truncating or reordering vault data | ✅ detected (AES-GCM with chunk number and “last” flag) |
| Old vault copy after a password change / key removal | ⚠️ opens with the old access until you run “Replace master key” |
| Infected Mac (keylogger, malware) | ❌ sees what you see while the vault is open |
| Swapped app | ⚠️ warning when run from removable media; install on the Mac and check SHA-256 checksums |
| Revoking another user's access | ⚠️ removing their key works immediately for the current vault; for a full cut-off (including old copies) use “Replace master key” |

## Cryptography

- **Master key:** 256 random bits. It is never stored in plaintext.
- **Key-encryption key (KEK)** for password + YubiKey:
  `HKDF-SHA256( PBKDF2-HMAC-SHA256(password in NFC, 32-byte salt, 3,000,000 iterations) ‖ FIDO2 hmac-secret(32-byte salt) )`.
- **KEK for the recovery password:** `HKDF-SHA256(160 random bits)`. The code is 32 characters of Crockford Base32.
- **Stored master key:** each keyslot holds the master key encrypted with AES-256-GCM. The AAD binds it to the vault ID and all slot parameters.
- **Files:**
  - each file has its own key, `HKDF(master key, random file ID)`;
  - a file is split into 1 MiB chunks, each encrypted with AES-256-GCM, with the chunk number as the nonce;
  - each chunk's AAD is the file header, the chunk number and the “last” flag;
  - the file's path and name are encrypted in chunk 0.
- **YubiKey:** FIDO2/CTAP2 `hmac-secret` (non-resident credential, user presence required, PIN/UV protocol 1).
  - The key computes HMAC-SHA-256 with a secret that **never leaves it**.
  - OTP slots 1/2 are not used or changed. The FIDO2 PIN is used only for registration on keys that require it.
- **Randomness:** `SecRandomCopyBytes`. **Libraries:** system frameworks only (CryptoKit, CommonCrypto, IOKit, CryptoTokenKit).

## Security audit (version 1.0 → 1.1)

A full code review, with the key issues confirmed by tests on test data. All items below were fixed in 1.1.

| # | Severity | Problem | Fix |
|---|---|---|---|
| 1 | critical (environment) | vault created in a Desktop folder synced with iCloud — plaintext files would reach Apple's servers before encryption | the app detects and blocks iCloud folders (for vaults and decrypted files); vault moved to `~/Sejf` |
| 2 | high | “delete originals” removed unencrypted hidden files (e.g. `.env`) together with an “empty” folder (confirmed by a test) | hidden files are encrypted; only truly empty folders are removed; links are not followed; files with several hard links are not overwritten |
| 3 | high | the app on a USB drive could be swapped | install into `~/Applications`, warning when run from removable media, SHA-256 checksums in the package |
| 4 | medium | no access revocation — a removed key / old password + an old header copy opened all files | “Replace master key” (full re-encryption, crash-safe) |
| 5 | medium | decrypted copies went to the Desktop (iCloud) by default, permissions 0644 | Downloads by default, iCloud blocked, permissions 0600, previews cleaned up after a crash |
| 6 | medium | screenshot protection only for the main window; recovery password selectable and still visible after locking | protection for all windows, code not selectable, hidden on lock |
| 7 | medium | dead code (OTP mode — cryptographically password-only, slot 2, `ykman` via `PATH`) | removed (~500 lines) |
| 8 | low | crafted data from a USB device or a vault file could crash the app or force a huge allocation | strict limits in the CTAPHID, CBOR and file-format parsers |

Version 1.1 also added **password change with current-password verification** (one touch of the key; a failed attempt leaves the header unchanged).

## Multiple users (1.2)

- Each user has a separate FIDO2 keyslot with their own YubiKey and password. All keyslots protect the same master key, so everyone has equal rights.
- **Joining happens locally only:** a person with access unlocks the vault, and the new person types a password and touches their key on the same Mac. There are no network invitations and no key files to send, so there is nothing to intercept.
- User names and vault names are stored **in plaintext** in the header, so they are visible without unlocking. They are not authenticated: someone with write access to the files could change them, but this gives no access to the data.

## Cheaper keys (1.3)

- Keys are detected via FIDO2, so keys without a smart-card interface (Security Key NFC) work too.
- A key without a serial number is recognised by its credential, using a silent check (`up = false`, no touch). The check prevents adding the same key twice and points to the right key when changing a password.

## FIPS 140

The vault uses only NIST-approved algorithms, executed by Apple's system module (corecrypto) with FIPS 140-3 validation, and runs self-tests at startup. **It is not FIPS certified**, and Level 4 is out of reach for software. Details: [06-FIPS.md](06-FIPS.md).

## Limitations you should know about

- **Flash, SSD, APFS:** overwriting a file does not guarantee that old blocks are destroyed. Local Time Machine snapshots keep the disk state for up to ~24 h. Ideally, plaintext secrets never reach the disk at all.
- **iCloud:** files deleted from Desktop and Documents stay in “Recently Deleted” on iCloud.com for another 30 days. Consider turning on Advanced Data Protection.
- **Memory:** Swift cannot reliably zero passwords in process memory. CryptoKit keys are wiped automatically.
- **Metadata:** the number of files and their approximate sizes are visible (names are not).
- **PBKDF2** rather than a GPU-hard function (Argon2). This matters only if an attacker has both a vault copy and your YubiKey.
- **Ad hoc signature** instead of an Apple Developer certificate, so no notarisation. Check integrity with the SHA-256 checksums, or build from source.
- Losing all keys **and** the recovery password means permanent data loss. There is no back door.
