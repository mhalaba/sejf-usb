# Changelog

## 1.4

- **English version:** full app interface and documentation in English (`Docs/en/`).
- The language follows macOS (Polish → Polish, otherwise English). It can be changed in **Vault → Język / Language** or in the system's per-app language settings.
- Dates and file sizes are formatted in the selected language.
- Tests check that every text is translated and that value placeholders match.

## 1.3

- **Cheaper keys:** support for the **Security Key NFC / C NFC** and other FIDO2 keys with `hmac-secret`. Keys are detected via FIDO2 instead of CCID; model and serial number are added when the key exposes them.
- **Silent key recognition** (no touch, no serial number needed): blocks registering the same key twice and points to the right key when changing a password or replacing the master key.
- **FIDO2 PIN** during registration on keys that require it (CTAP 2.0 with a PIN set), with the number of attempts left.
- Clear message for keys without `hmac-secret` (old U2F) and with “Always UV” enabled.
- **Cryptographic power-up self-tests** (FIPS 140-3 style): 10 tests; on failure the app does not process data.
- Document [06-FIPS.md](06-FIPS.md): mapping of algorithms to NIST standards and a plain statement that the app is not certified.

## 1.2

- **New installation:** welcome screen with three options: create a new vault, open my vault, join a vault.
- **Your own vaults:** “Your vaults” list (multiple vaults, names, locations, vaults detected on USB drives). New-vault wizard with a name and a location (Mac `~/Sejfy/<name>`, USB drive, chosen folder).
- **Users:** owner name on each key, “Add user or key” (new person or backup key of an existing one), joining an existing vault at one Mac, greeting by name, “you” marker in the key panel.
- Master key replacement names the users who will lose access.
- Backward-compatible header format (`name` and `owner` are optional).

## 1.1

**Security (after a full audit):**
- iCloud-synced folders are blocked (for vaults and decrypted files).
- Safe deletion of originals: hidden files are encrypted rather than deleted. Only truly empty folders are removed, and links are not followed.
- **Master key replacement:** full re-encryption that invalidates old keys, passwords and header copies. It survives interruptions.
- **Password change** with current-password verification (button, menu, ⇧⌘P).
- Decrypted files get 0600 permissions and go to Downloads by default. Previews are cleaned up after a crash.
- Screenshot protection for all windows. The recovery password cannot be selected and is hidden on lock.
- Warning when the app runs from removable media. `build.sh` installs into `~/Applications`.
- Hardened CTAPHID, CBOR and file-format parsers.
- Dead code removed: OTP mode, slot 2, `ykman`.

**Features:**
- “Add files” and drag-and-drop with “Encrypt and delete originals”, no intermediate folder needed.
- Touch prompts and progress from the key panel are shown in the main window.

## 1.0

- First version: AES-256-GCM vault, password + YubiKey (FIDO2 `hmac-secret`, native, no system permissions), recovery password, backup keys, automatic locking, two-step creation and unlock, detection of an accidentally “typed” OTP code.
