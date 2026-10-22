# Sejf USB 1.4 — user guide

Sejf USB encrypts files in a `Sejf.vault` folder, which can live on a USB drive or on your Mac. Opening the vault takes two things:

- a **password** you know;
- a **YubiKey** you have to physically touch.

Without either of them the data cannot be read. The app works 100% offline.

**Language:** the app follows the macOS language: Polish if your system is in Polish, English otherwise. You can change it in the **Vault → Język / Language** menu, or per app in **System Settings → General → Language & Region → Applications**.

## Requirements

- macOS 14 (Sonoma) or later, on an Apple silicon or Intel Mac.
- A FIDO2 key with the `hmac-secret` extension. The OTP slots are left untouched. A FIDO2 PIN is needed only on older keys, and only during registration.

### Compatible keys

| Key | Works? | Notes |
|---|---|---|
| YubiKey 5 / 5C / 5 NFC / 5C NFC / 5Ci / Nano | ✅ tested | model and serial number shown |
| **Security Key NFC / Security Key C NFC** (cheaper) | ✅ detection and recognition tested | no serial number — the app recognises the key by its credential, without a touch |
| YubiKey Bio | ⚠️ should work | not tested; a touch is enough, the fingerprint is not used |
| YubiKey 5 FIPS | ⚠️ should work | in FIPS mode it needs a PIN during registration; not tested |
| older U2F-only keys (e.g. the blue “FIDO U2F Security Key”) | ❌ | no FIDO2 `hmac-secret` — the app detects this and tells you |
| other FIDO2 keys with `hmac-secret` (e.g. Nitrokey 3, SoloKey 2, Feitian) | ⚠️ | not tested |

**NFC and the Mac:** Macs have no NFC reader, so an “NFC” key is plugged into a USB port too (A or C, depending on the model). NFC is useful with a phone, and Sejf USB is a Mac app.

**FIDO2 PIN:** if the key requires one (older keys with a PIN set), the app asks for it when you create a vault or add a key. The PIN stays in the key and is never stored. After 8 wrong attempts the key's FIDO2 functions are blocked.

## 1. Where to keep what

| What | Where | Why |
|---|---|---|
| The app | `~/Applications/Sejf USB.app` on **every** Mac you use | a copy on a USB drive could be swapped by someone to capture your password |
| Vault on a Mac | e.g. `~/Sejf` | **outside** Desktop, Documents and iCloud Drive (the app blocks iCloud-synced folders) |
| Vault on a USB drive | just the `Sejf.vault` folder | it is encrypted, so it can be anywhere |
| Recovery password | on paper, kept apart from the YubiKey | it opens the vault without a key |
| Backup YubiKey | kept apart from the main one | losing your only key leaves you with just the recovery password |

## 2. First launch (new installation)

On a Mac where the app does not know any vault yet, you see three options:

| Choice | When |
|---|---|
| **Create a new vault** | you are starting from scratch |
| **Open my vault** | you already have a vault (e.g. on a USB drive) and your YubiKey with a password |
| **Join a vault** | someone is sharing their vault with you — see section 7 |

After that, the start screen is the **“Your vaults”** list. The list is remembered only on this Mac, and removing a vault from the list (right-click) does not delete any files. The vault-name button in the window header takes you back to the list.

## 3. Creating a vault

1. **“New vault”** → enter a name and choose a location. The name is visible without unlocking, so do not put anything secret in it. Locations:
   - **On this Mac**: `~/Sejfy/<name>`, outside iCloud, backed up by Time Machine;
   - **On USB drive**: in the root of the drive, or in a subfolder if the drive already holds another vault;
   - **In a chosen folder**: outside Desktop, Documents and iCloud Drive.
2. **Step 1 of 2:**
   - enter **your name** (other users of the vault see it);
   - enter a password twice: at least 12 characters, ideally 4–5 random words;
   - **do not touch the key yet**.
3. **Step 2 of 2:** when “Now touch the gold button (1/2)” appears, touch the key briefly, then once more at “(2/2)”.
4. **Recovery password** (32 characters): write it down by hand on paper. Do not copy it, photograph it or save it in a file.

Everyone can have as many vaults of their own as they like, e.g. “Private”, “Company”, “Family”. Each one has its own master key and its own recovery password.

> **The key “typed” a strange string?** Touching the YubiKey when the app has not asked for it types an OTP code like a keyboard. The app detects this and removes it from the password field.

## 4. Unlocking

1. Enter your password and click **“Next: YubiKey”**.
2. Touch the key when the app asks. One touch is enough.

**If you lose your YubiKey:**
1. Click “I lost my YubiKey — use the recovery password” and enter the code from your sheet of paper.
2. Then immediately do **🔑 → Replace master key** with a new key (section 8).

## 5. Encrypting files

- **“Add files”**, or drag files or folders onto the window. You then choose:
  - **“Encrypt and delete originals”**: an original disappears only after a test decryption produces an identical file (SHA-256);
  - **“Encrypt only (keep originals)”**: the originals stay.
- **“Encrypt USB drive” / “Encrypt folder”** protects whatever lies next to the vault.
- Hidden files (e.g. `.env`) are encrypted too. Only system junk (`.DS_Store`, `._*`) is skipped. A folder is deleted only if nothing is left in it.
- Symbolic links are skipped and reported; their targets are not touched.

## 6. Reading files

- **Double-click** opens a preview. The file is decrypted into a private temporary folder, which is destroyed when the vault locks.
- **“Decrypt…”** saves a copy to a folder you choose (Downloads by default). The copy is readable only by you (0600).
  - Saving into iCloud folders is blocked.
  - Delete the copy when you no longer need it.

## 7. Users: joining a vault

A vault can have several users. Each has **their own YubiKey and their own password**. Everyone sees the same files and anyone can manage keys, so only add people you trust.

**Adding a new person (both at the same Mac, also on a new installation):**
1. The new person installs the app (see `02-Installation.md`) and chooses **“Join a vault”**, pointing at the vault folder (e.g. on a shared USB drive).
2. A person who already has access **unlocks the vault with their key and password** (or with the recovery password).
3. The **“Add user or key”** window opens. There:
   - enter the new person's name;
   - remove the existing user's key and insert the new person's key (only that one key may be connected);
   - the **new person types their own password**;
   - click “Add” and touch the new key twice.
4. Done. From now on the new person opens the vault with their own key and password, and the app greets them by name.

The master key never leaves the computer and is not sent anywhere.

The same window adds a **backup key** for an existing person (option “Backup key of an existing person”). You can open it at any time: **🔑 → Add user or key**.

**Important for shared vaults:** everyone works on the same `Sejf.vault` folder. Copies of a vault do not sync by themselves, and adding a user changes only the copy where you did it.

## 8. Password and keys

| Function | Where | Notes |
|---|---|---|
| **Change password** | button in the vault window, Vault menu, **⇧⌘P** | applies to your key; requires the current password and one touch |
| **Add user or key** | 🔑 | section 7 |
| **New recovery password** | 🔑 | the old recovery password stops working |
| **Remove key / user** | 🔑 | the last key cannot be removed |
| **Replace master key** | 🔑 | see below |

Changing a password, creating a new recovery password and removing a key all apply **to the current vault**. An old copy of the vault (e.g. from Time Machine) still opens with the old access.

**Replacing the master key** is the safeguard after losing a key, leaking a password or revoking someone's access:
- all files are re-encrypted;
- only your connected key and a **new** recovery password remain;
- **other users lose access** and have to be added again;
- the operation survives interruptions.

## 9. Locking

The vault locks:
- manually (**⌘L** or “Lock”);
- after 5 minutes of inactivity;
- when the Mac sleeps or the screen locks;
- when the drive is disconnected.

Locking wipes the key from memory and removes previews and any visible recovery password.

## 10. The same vault on several Macs

- Install the app on each Mac (see `02-Installation.md`).
- Open the same `Sejf.vault` folder (USB drive or copy) with the same YubiKey and password. Nothing needs to be registered.
- Do not edit two copies of a vault at the same time. Changes in one copy do not carry over to the other by themselves.

## 11. Backups

The `Sejf.vault` folder is encrypted, so copy it freely: to a second drive, Time Machine, even the cloud. Reading a copy still needs the YubiKey and password, or the recovery password. USB drives fail without warning.

## 12. Common messages

| Message | What to do |
|---|---|
| “Insert YubiKey” | plug the key in; if it is plugged in, remove it and insert it again |
| “the key was not touched in time” | click “Try again” and touch within ~30 s |
| “Wrong password or YubiKey” | check the password (Caps Lock) and that this key is registered in this vault |
| “Several keys are connected” | leave only one YubiKey |
| “This folder is synced with iCloud” | choose a folder outside Desktop, Documents and iCloud Drive |
| “You are running the app from removable media” | install the app on your Mac and run it from there |
| “This key is already in the vault” (when adding) | remove the existing user's key and insert the new person's key |
| a vault shown as “unavailable” | connect the USB drive with the vault, or remove the vault from the list (files stay) |
