# Vault format specification (version 1)

The format is backward compatible: headers from 1.1 (without `name` and `owner`) open in 1.2 and later unchanged.

All multi-byte numbers are **big-endian** unless stated otherwise. `‖` means concatenation.

## Directory layout

```
Sejf.vault/
├── header.json          header (JSON)
├── header.bak.json      identical header copy (used when the main one is damaged)
├── data/
│   └── <32 hex chars>.sejf   one encrypted file
├── header.next.json     only during a master key replacement
├── data.new/, data.old/ only during a master key replacement
```

## Header (`header.json`)

```json
{
  "format": "sejf-usb",
  "version": 1,
  "vaultID": "<16 B, base64>",
  "created": 1792936923.1,
  "chunkSize": 1048576,
  "keyslots": [ { … }, { … } ],
  "name": "Family documents"          // optional (since 1.2), plaintext
}
```

### Keyslot

| Field | Type | Description |
|---|---|---|
| `id` | text (UUID) | identifier |
| `kind` | `"fido2"` / `"recovery"` | kind |
| `label` | text | name (not protected) |
| `created` | number | creation time (Unix) |
| `serial` | number? | YubiKey serial number (informational) |
| `challenge` | base64? | FIDO2: `hmac-secret` salt (32 B, shared by all FIDO2 slots) |
| `salt` | base64 | KDF salt (32 B) |
| `iterations` | number? | PBKDF2 iterations (3,000,000) |
| `credentialID` | base64? | FIDO2: credential ID |
| `wrappedKey` | base64 | AES-256-GCM combined: `nonce(12) ‖ ciphertext(32) ‖ tag(16)` |
| `owner` | text? | user name (since 1.2, plaintext, unauthenticated — display only) |

**Keyslot AAD:**
`"sejf-usb/v1/keyslot" ‖ vaultID ‖ id(UTF-8) ‖ kind(UTF-8) ‖ challenge ‖ salt ‖ BE64(iterations or 0) ‖ credentialID`
(missing fields contribute an empty string)

### Key derivation (KEK)

- **FIDO2:**
  ```
  pw  = PBKDF2-HMAC-SHA256(NFC(password), salt, iterations, 32 B)
  hs  = FIDO2 hmac-secret(credentialID, challenge)          — 32 B, needs a touch
  KEK = HKDF-SHA256(ikm = pw ‖ hs, salt = salt, info = "sejf-usb/v1/fido2-kek" ‖ vaultID, 32 B)
  ```
- **Recovery password:** 20 B encoded as Crockford Base32 (32 characters in groups of 4; on input `O→0`, `I/L→1`)
  ```
  KEK = HKDF-SHA256(ikm = 20 B, salt = salt, info = "sejf-usb/v1/recovery-kek" ‖ vaultID, 32 B)
  ```

### FIDO2 parameters

- RP ID: `sejf-usb`.
- makeCredential: ES256, `rk = false`, extension `hmac-secret = true`, no UV. On keys that require a PIN for registration (PIN set and no `makeCredUvNotRqd`): `pinUvAuthParam` from a PIN token (clientPIN getPinToken, protocol 1).
- getAssertion: `allowList` with all `credentialID`s of the FIDO2 slots, `up = true`, `hmac-secret` with a single 32-byte salt, PIN/UV protocol 1 (ECDH P-256 → SHA-256 → AES-256-CBC with zero IV, HMAC-SHA-256 truncated to 16 B).
- The key returns the ID of its credential, which identifies the right keyslot (one touch).
- Silent recognition: getAssertion with `up = false` and the same `allowList` (no touch, no `hmac-secret`).

## Encrypted file (`data/<fileID hex>.sejf`)

```
header (25 B):  "SEJF"(4) ‖ version 0x01 (1) ‖ fileID (16) ‖ BE32(chunkSize)
chunk i:        BE32(n) ‖ ciphertext ‖ tag(16)          n = ciphertext length + 16
```

- The file name must equal `hex(fileID) + ".sejf"`, and `chunkSize` must match the vault header.
- File key: `HKDF-SHA256(ikm = master key, salt = fileID, info = "sejf-usb/v1/file" ‖ vaultID, 32 B)`.
- Nonce of chunk `i`: `0x00000000 ‖ BE64(i)`.
- AAD of chunk `i`: `header(25 B) ‖ BE64(i) ‖ (0x01 if last, else 0x00)`.
- **Chunk 0** is the JSON metadata: `{"path": "…", "size": n, "modified": t, "added": t}` (≤ 1 MiB, never last).
- **Chunks 1…k** hold the content, `chunkSize` bytes each. The last chunk has flag 1. An empty file has one empty chunk with flag 1.
- “Last” means the chunk ends exactly at the end of the file. Truncating, appending or reordering chunks causes an authentication error.

## Master key replacement (crash safety)

1. New keyslots (the chosen FIDO2 key and a new recovery password) for the new master key.
2. Every file is stream-decrypted and re-encrypted with the new key (new `fileID`) into `data.new/`.
3. `header.next.json` is written.
4. `data/ → data.old/`, `data.new/ → data/`.
5. `header.json` and `header.bak.json` are written with the new slots.
6. `data.old/` and `header.next.json` are removed.

When the vault is opened:
- `data.new` without `data.old` means **roll back** (remove `data.new` and the plan);
- `data.old` together with a valid `header.next.json` means **complete** steps 4–6;
- a lone `header.next.json` is removed.
