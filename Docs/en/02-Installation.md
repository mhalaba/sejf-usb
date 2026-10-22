# Installing on another Mac

## Requirements

- macOS 14 (Sonoma) or later, on an Apple silicon or Intel Mac (the app is universal).
- A FIDO2 YubiKey (YubiKey 5 or Security Key NFC). No need to install `ykman` or any other software.

## 1. Check the package has not been tampered with

In Terminal, inside the unpacked package folder:

```bash
shasum -a 256 -c SHA256SUMS.txt
```

Every line should end with `OK`. Ideally, also compare the checksum of the `.zip` file itself with the one you noted on a trusted computer.

## 2. Install the app

1. Copy `Sejf USB.app` into **`~/Applications`** (your home folder → Applications). `/Applications` works too.
2. **Do not run the app from a USB drive.** Someone could swap a copy on removable media.

## 3. First launch: Gatekeeper

The app is signed locally (“ad hoc”), not with an Apple Developer certificate. On another Mac the system may therefore say it cannot verify the app. In that case:

1. Try to open the app once and close the message.
2. Open **System Settings → Privacy & Security**, scroll down and click **“Open Anyway”** next to “Sejf USB”.
3. Confirm with your Mac password.

Alternatively, **after checking the checksums**, remove the quarantine flag in Terminal:

```bash
xattr -dr com.apple.quarantine ~/Applications/"Sejf USB.app"
```

## 4. Permissions

The app needs no special system permissions: no “Input Monitoring” and no network access. The first time you open a vault on a USB drive, macOS may ask for access to files on removable volumes. Allow it.

## 5. Language

The app follows the macOS language: Polish if your system is in Polish, English otherwise. You can change it in the **Vault → Język / Language** menu, or in **System Settings → General → Language & Region → Applications**.

## 6. First launch

The app shows a welcome screen with three options:
- **Create a new vault**: you are starting from scratch;
- **Open my vault**: you already have a vault (USB drive, or a copy outside iCloud) plus your YubiKey and password;
- **Join a vault**: someone is sharing their vault with you. A person with access unlocks it next to you, and you add your own key and password (`01-User-guide.md`, section 7).

## 7. Building from source instead of using the ready-made app (safest)

If you prefer not to trust a ready-made `.app`, build it yourself from source (see `05-Building-and-testing.md`). Command Line Tools are enough:

```bash
xcode-select --install
```

```bash
./build.sh test && ./build.sh
```

## Uninstalling

Delete `Sejf USB.app`. The app stores only the “Your vaults” list (paths and names, no secrets) and your language choice. Remove them with:

```bash
defaults delete local.sejfusb.app
```

Your vaults (`Sejf.vault`) are left untouched.
