// Tłumaczenia angielskie. Klucz = tekst polski z kodu (L("…")). Wygenerowane i sprawdzane testem.
// Miejsca na wartości (%@) muszą się zgadzać liczbą z kluczem.

extension Translations {
    static let en: [String: String] = [
        "Łączenie z YubiKey…":
            "Connecting to the YubiKey…",
        "Teraz dotknij złotego przycisku%@":
            "Now touch the gold button%@",
        "Uruchamiasz aplikację z nośnika wymiennego. Ktoś, kto miał dostęp do pendrive'a, mógł ją podmienić i przechwycić hasło oraz odpowiedź YubiKeya.\n\nBezpieczniej: zainstaluj aplikację na Macu (np. w ~/Applications) i uruchamiaj ją stamtąd — na pendrivie wystarczy sam folder Sejf.vault.":
            "You are running the app from removable media. Someone with access to the USB drive could have replaced it and captured your password and the YubiKey response.\n\nSafer: install the app on your Mac (e.g. in ~/Applications) and run it from there — the USB drive only needs the Sejf.vault folder.",
        "Sejfu „%@” nie ma pod ścieżką %@. Podłącz nośnik albo usuń sejf z listy.":
            "Vault “%@” is not at %@. Connect the drive or remove the vault from the list.",
        "Otwórz":
            "Open",
        "Wskaż folder Sejf.vault albo folder, w którym się znajduje (np. na pendrivie)":
            "Select the Sejf.vault folder or the folder that contains it (e.g. on a USB drive)",
        "W „%@” nie ma sejfu (folderu Sejf.vault z plikiem header.json).":
            "There is no vault in “%@” (no Sejf.vault folder with a header.json file).",
        " Przenieś cały folder sejfu (np. do ~/Sejf) i spróbuj ponownie.":
            " Move the whole vault folder (e.g. to ~/Sejf) and try again.",
        "Wybierz":
            "Choose",
        "Wybierz pusty folder na sejf — poza Pulpitem, Dokumentami i iCloud Drive":
            "Choose an empty folder for the vault — outside Desktop, Documents and iCloud Drive",
        "Wybierz osobny folder tylko na sejf, a nie „%@”.":
            "Choose a separate folder just for the vault, not “%@”.",
        "W „%@” jest już sejf. Wybierz inną nazwę albo miejsce.":
            "There is already a vault in “%@”. Choose a different name or location.",
        "Nie można utworzyć folderu: %@":
            "Cannot create the folder: %@",
        "Nie można odczytać sejfu: %@":
            "Cannot read the vault: %@",
        "Nośnik „%@” można bezpiecznie wyjąć.":
            "Drive “%@” can now be safely removed.",
        "Nie udało się wysunąć: %@":
            "Could not eject: %@",
        "Dotknięto YubiKey, gdy aplikacja o to nie prosiła — klucz „wpisał” swój kod OTP jak klawiatura. Usunąłem go z pola hasła.\n\nJak zrobić to dobrze:\n1. Wpisz hasło.\n2. Kliknij „Dalej”.\n3. Dopiero gdy pojawi się „Teraz dotknij złotego przycisku”, dotknij klucza.":
            "The YubiKey was touched when the app did not ask for it — the key “typed” its OTP code like a keyboard. I removed it from the password field.\n\nHow to do it right:\n1. Enter your password.\n2. Click “Next”.\n3. Only when “Now touch the gold button” appears, touch the key.",
        "Tworzenie sejfu…":
            "Creating the vault…",
        "Odblokowywanie…":
            "Unlocking…",
        "Sprawdzanie hasła…":
            "Checking the password…",
        "Odblokowywanie hasłem odzyskiwania…":
            "Unlocking with the recovery password…",
        "Odblokowano hasłem odzyskiwania. Jeśli zgubiłeś YubiKey: 🔑 → Wymień klucz główny (z nowym kluczem).":
            "Unlocked with the recovery password. If you lost your YubiKey: 🔑 → Replace master key (with a new key).",
        "Witaj, %@!":
            "Welcome, %@!",
        "Hasło odzyskiwania ukryto przy blokadzie. Jeśli go nie zapisałeś: 🔑 → Nowe hasło.":
            "The recovery password was hidden when the vault locked. If you did not write it down: 🔑 → New password.",
        "Wybierz pliki lub foldery do zaszyfrowania w sejfie":
            "Choose files or folders to encrypt in the vault",
        "Szyfrowanie…":
            "Encrypting…",
        "%@: pominięto (dowiązanie lub plik specjalny) — zostaje na miejscu":
            "%@: skipped (link or special file) — left in place",
        "Szyfrowanie %@/%@: %@":
            "Encrypting %@/%@: %@",
        "Weryfikacja i usuwanie oryginału: %@":
            "Verifying and deleting the original: %@",
        "%@: weryfikacja nie powiodła się — oryginał zachowany":
            "%@: verification failed — original kept",
        "%@: %@":
            "%@: %@",
        "%@: folder nie jest pusty — zostawiony":
            "%@: folder is not empty — left in place",
        "Zaszyfrowano plików: %@":
            "Files encrypted: %@",
        ". Oryginały usunięte.":
            ". Originals deleted.",
        "Zaszyfrowano plików: %@. Uwagi:\n":
            "Files encrypted: %@. Notes:\n",
        "Odszyfruj tutaj":
            "Decrypt here",
        "Gdzie zapisać odszyfrowane pliki? Nie na Pulpicie ani w Dokumentach (iCloud) i nie na pendrivie.":
            "Where should the decrypted files be saved? Not on the Desktop or in Documents (iCloud), and not on the USB drive.",
        "Ten folder jest synchronizowany z iCloud — odszyfrowane pliki trafiłyby na serwery Apple. Wybierz np. Pobrane.":
            "This folder is synced with iCloud — decrypted files would end up on Apple's servers. Choose e.g. Downloads.",
        "Odszyfrowywanie…":
            "Decrypting…",
        "Odszyfrowywanie %@/%@: %@":
            "Decrypting %@/%@: %@",
        "Odszyfrowano plików: %@. Usuń je, gdy przestaną być potrzebne.":
            "Files decrypted: %@. Delete them when you no longer need them.",
        "Otwieranie %@…":
            "Opening %@…",
        "Usuwanie…":
            "Deleting…",
        "Stare kopie sejfu (np. z kopii zapasowej) nadal otwiera poprzedni dostęp — aby to wykluczyć: 🔑 → Wymień klucz główny.":
            "Old copies of the vault (e.g. from a backup) still open with the previous access — to rule this out: 🔑 → Replace master key.",
        "Dodawanie zapasowego klucza…":
            "Adding a backup key…",
        "Dodawanie użytkownika…":
            "Adding a user…",
        "Zapisywanie…":
            "Saving…",
        "Dodano zapasowy klucz dla: %@.":
            "Backup key added for: %@.",
        "Dodano użytkownika „%@”. Od teraz otwiera ten sejf swoim kluczem i hasłem.":
            "User “%@” added. From now on they open this vault with their own key and password.",
        "Włóż YubiKey, którego hasło chcesz zmienić.":
            "Insert the YubiKey whose password you want to change.",
        "Podłączony klucz nie należy do „%@”. Włóż właściwy klucz.":
            "The connected key does not belong to “%@”. Insert the right key.",
        "Zmiana hasła…":
            "Changing the password…",
        "Zapisywanie nowego hasła…":
            "Saving the new password…",
        "Hasło zmienione. ":
            "Password changed.",
        "Generowanie hasła odzyskiwania…":
            "Generating a recovery password…",
        "Usuwanie klucza…":
            "Removing the key…",
        "Usunięto „%@”. ":
            "Removed “%@”.",
        "Wymiana klucza głównego…":
            "Replacing the master key…",
        "Szyfrowanie plików od nowa…":
            "Re-encrypting files…",
        "Szyfrowanie plików od nowa: %@/%@":
            "Re-encrypting files: %@/%@",
        "Klucz główny wymieniony. Stare klucze, hasła i kopie nagłówka nie otwierają już tego sejfu.":
            "Master key replaced. Old keys, passwords and header copies no longer open this vault.",
        "Sejf zablokowano automatycznie po %@ min bezczynności.":
            "The vault was locked automatically after %@ min of inactivity.",
        "Nośnik został odłączony — sejf zablokowany.":
            "The drive was disconnected — vault locked.",
        "Sejf":
            "Vault",
        "Zablokuj":
            "Lock",
        "Zmień hasło…":
            "Change password…",
        "Za krótkie (min. %@ znaków)":
            "Too short (min. %@ characters)",
        "Słabe":
            "Weak",
        "Średnie":
            "Medium",
        "Silne":
            "Strong",
        "Upuść, aby zaszyfrować":
            "Drop to encrypt",
        "Zaszyfrować %@ element(ów)?":
            "Encrypt %@ item(s)?",
        "Zaszyfruj i usuń oryginały":
            "Encrypt and delete originals",
        "Tylko zaszyfruj (oryginały zostają)":
            "Encrypt only (keep originals)",
        "Anuluj":
            "Cancel",
        "Oryginał jest usuwany dopiero po sprawdzeniu, że zaszyfrowana kopia jest identyczna. Pliki z Pulpitu/Dokumentów (iCloud) Apple przechowuje jeszcze 30 dni w „Ostatnio usuniętych” na iCloud.com — usuń je tam ręcznie.":
            "An original is deleted only after checking that the encrypted copy is identical. Files from Desktop/Documents (iCloud) are kept by Apple for another 30 days in “Recently Deleted” on iCloud.com — delete them there manually.",
        "Usunąć %@ plik(ów) z sejfu?":
            "Delete %@ file(s) from the vault?",
        "Usuń na zawsze":
            "Delete permanently",
        "Zaszyfrowane kopie zostaną usunięte. Tej operacji nie można cofnąć.":
            "The encrypted copies will be deleted. This cannot be undone.",
        "Dodaj pliki":
            "Add files",
        "Zaszyfruj folder":
            "Encrypt folder",
        "Zaszyfruj pendrive":
            "Encrypt USB drive",
        "Zaszyfruj niezaszyfrowane pliki leżące obok sejfu":
            "Encrypt the unencrypted files next to the vault",
        "Odszyfruj…":
            "Decrypt…",
        "Usuń":
            "Delete",
        "Szukaj":
            "Search",
        "Zmień hasło":
            "Change password",
        "Zmień hasło sejfu (⇧⌘P)":
            "Change the vault password (⇧⌘P)",
        "Klucze, hasło odzyskiwania, wymiana klucza głównego":
            "Keys, recovery password, master key replacement",
        "Zablokuj i wysuń pendrive":
            "Lock and eject the USB drive",
        "Nazwa":
            "Name",
        "Rozmiar":
            "Size",
        "Zmodyfikowano":
            "Modified",
        "Otwórz podgląd":
            "Open preview",
        "Odszyfruj do…":
            "Decrypt to…",
        "Usuń z sejfu":
            "Delete from vault",
        "Sejf jest pusty":
            "The vault is empty",
        "Przeciągnij tu pliki lub użyj „Zaszyfruj pliki z folderu”, żeby zabezpieczyć to, co leży w „%@”.":
            "Drag files here or use “Encrypt folder” to protect what is in “%@”.",
        "Przeciągnij tu pliki lub użyj „Zaszyfruj pendrive”, żeby zabezpieczyć to, co już na nim leży.":
            "Drag files here or use “Encrypt USB drive” to protect what is already on it.",
        "%@ plików · %@":
            "%@ files · %@",
        "%@ uszkodzonych":
            "%@ damaged",
        "W folderze są niezaszyfrowane pliki: %@":
            "There are unencrypted files in the folder: %@",
        "Na pendrivie są niezaszyfrowane pliki: %@":
            "There are unencrypted files on the USB drive: %@",
        "AES-256-GCM · YubiKey · samotesty %@/10":
            "AES-256-GCM · YubiKey · self-tests %@/10",
        "Algorytmy zatwierdzone przez NIST, wykonywane przez moduł kryptograficzny systemu (corecrypto). Samotesty przy starcie: ":
            "NIST-approved algorithms, executed by the system cryptographic module (corecrypto). Power-up self-tests:",
        "Zaszyfruj pliki z folderu":
            "Encrypt files from the folder",
        "Zaszyfruj pliki z pendrive'a":
            "Encrypt files from the USB drive",
        "Te pliki leżą na „%@” bez szyfrowania. Zaznacz, które przenieść do sejfu.":
            "These files are on “%@” without encryption. Select which ones to move into the vault.",
        "Wszystko jest zaszyfrowane.":
            "Everything is encrypted.",
        "Usuń oryginały po zaszyfrowaniu i weryfikacji":
            "Delete originals after encryption and verification",
        "Każdy plik jest najpierw odszyfrowywany kontrolnie i porównywany (SHA-256), dopiero potem oryginał jest nadpisywany i usuwany.":
            "Each file is first test-decrypted and compared (SHA-256); only then is the original overwritten and deleted.",
        "Pamięć flash może zachować kopie starych bloków. Dla pewności: po zaszyfrowaniu skopiuj folder Sejf.vault na Maca, sformatuj pendrive i skopiuj go z powrotem.":
            "Flash memory may keep copies of old blocks. To be sure: after encrypting, copy the Sejf.vault folder to your Mac, format the USB drive and copy it back.",
        "Zaszyfruj (%@)":
            "Encrypt (%@)",
        "Zaszyfrować %@ element(ów) i usunąć oryginały?":
            "Encrypt %@ item(s) and delete the originals?",
        "Oryginał zostanie usunięty tylko wtedy, gdy kontrolne odszyfrowanie da identyczny plik. Upewnij się, że znasz hasło i masz kod odzyskiwania.":
            "An original is deleted only if the test decryption produces an identical file. Make sure you know your password and have your recovery code.",
        "Użytkownicy i klucze":
            "Users and keys",
        "Zamknij":
            "Close",
        "Każdy użytkownik otwiera ten sejf swoim YubiKeyem i własnym hasłem — wszyscy widzą te same pliki. Hasło odzyskiwania otwiera sejf bez klucza.":
            "Each user opens this vault with their own YubiKey and password — everyone sees the same files. The recovery password opens the vault without a key.",
        "Bez nazwy":
            "Unnamed",
        "Hasło odzyskiwania":
            "Recovery password",
        "to Ty":
            "you",
        "otwiera sejf bez klucza":
            "opens the vault without a key",
        " · dodano ":
            " · added",
        "Nowe hasło":
            "New password",
        "Dodaj użytkownika lub klucz":
            "Add user or key",
        "Utwórz hasło odzyskiwania":
            "Create recovery password",
        "Wymień klucz główny…":
            "Replace master key…",
        "Szyfruje wszystko od nowa — unieważnia usunięte klucze, stare hasła i stare kopie sejfu":
            "Re-encrypts everything — invalidates removed keys, old passwords and old copies of the vault",
        "Wszystkie pliki zostaną zaszyfrowane od nowa nowym kluczem głównym. Zostanie tylko klucz „%@” (z hasłem wpisanym poniżej) i NOWE hasło odzyskiwania.":
            "All files will be re-encrypted with a new master key. Only the key “%@” (with the password entered below) and a NEW recovery password will remain.",
        " Stracą dostęp i trzeba będzie ich dodać ponownie: %@.":
            " These users will lose access and must be added again: %@.",
        " Stare hasła, stare hasło odzyskiwania i stare kopie sejfu przestaną działać.":
            " Old passwords, the old recovery password and old copies of the vault will stop working.",
        "Hasło (min. %@ znaków)":
            "Password (min. %@ characters)",
        "Powtórz hasło":
            "Repeat password",
        "Wymień klucz":
            "Replace key",
        "Zapisz":
            "Save",
        "Usunąć „%@” z sejfu?":
            "Remove “%@” from the vault?",
        "Ten klucz przestanie otwierać ten sejf. Stare kopie sejfu (np. z kopii zapasowej) unieważnisz dopiero „Wymianą klucza głównego”.":
            "This key will no longer open this vault. Old copies of the vault (e.g. from a backup) are invalidated only by “Replace master key”.",
        "Wymiana klucza głównego":
            "Master key replacement",
        "Nowe hasło musi mieć co najmniej %@ znaków.":
            "The new password must be at least %@ characters long.",
        "Nowe hasło musi różnić się od obecnego.":
            "The new password must differ from the current one.",
        "Nowe hasła się różnią.":
            "The new passwords do not match.",
        "Dla klucza: %@":
            "For key: %@",
        "Obecne hasło":
            "Current password",
        "Nowe hasło (min. %@ znaków — najlepiej kilka słów)":
            "New password (min. %@ characters — a few words work best)",
        "Powtórz nowe hasło":
            "Repeat new password",
        "Po kliknięciu „Zmień hasło” dotknij YubiKey, gdy aplikacja o to poprosi (jeden raz).":
            "After clicking “Change password”, touch the YubiKey when the app asks for it (once).",
        "Sprawdzanie klucza…":
            "Checking the key…",
        "Włóż klucz „%@”":
            "Insert the key “%@”",
        " (tylko jeden naraz)":
            " (only one at a time)",
        ", aby zmienić jego hasło.":
            " to change its password.",
        "Zmiana dotyczy tego sejfu. Stare kopie sejfu (np. z kopii zapasowej) nadal otwiera stare hasło — aby to wykluczyć, użyj potem 🔑 → Wymień klucz główny.":
            "The change applies to this vault. Old copies of the vault (e.g. from a backup) still open with the old password — to rule this out, then use 🔑 → Replace master key.",
        "Sejf „%@”":
            "Vault “%@”",
        "Nowa osoba":
            "New person",
        "Zapasowy klucz istniejącej osoby":
            "Backup key of an existing person",
        "Imię nowej osoby":
            "New person's name",
        "Taki użytkownik już jest — wybierz „Zapasowy klucz istniejącej osoby”.":
            "This user already exists — choose “Backup key of an existing person”.",
        "Dla kogo":
            "For whom",
        "Hasło wpisuje NOWA OSOBA — sama, tak by nikt go nie widział:":
            "The NEW PERSON types the password — themselves, so that nobody sees it:",
        "Hasło dla tego klucza (może być inne niż dotychczasowe):":
            "Password for this key (may differ from the current one):",
        "Hasło (min. %@ znaków — najlepiej kilka słów)":
            "Password (min. %@ characters — a few words work best)",
        "Każdy użytkownik widzi wszystkie pliki tego sejfu i może zarządzać kluczami. Dodawaj tylko zaufane osoby.":
            "Every user sees all files in this vault and can manage keys. Only add people you trust.",
        "Dodaj":
            "Add",
        "Gotowy: %@":
            "Ready: %@",
        " · nr %@":
            " · no. %@",
        " — po „Dodaj” dotkniesz go dwa razy.":
            " — after “Add” you will touch it twice.",
        "Podłączonych jest kilka kluczy — zostaw tylko klucz, który dodajesz.":
            "Several keys are connected — leave only the key you are adding.",
        "Włóż YubiKey, który chcesz dodać.":
            "Insert the YubiKey you want to add.",
        "Ten klucz nie obsługuje FIDO2 hmac-secret — użyj YubiKey 5 albo Security Key z FIDO2.":
            "This key does not support FIDO2 hmac-secret — use a YubiKey 5 or a Security Key with FIDO2.",
        "Ten klucz jest już w sejfie. Wyjmij go i włóż klucz nowej osoby.":
            "This key is already in the vault. Remove it and insert the new person's key.",
        "Błąd":
            "Error",
        "Twoje sejfy — przełącz na inny":
            "Your vaults — switch to another",
        "Odblokowany · %@:%@":
            "Unlocked · %@:%@",
        "Automatyczna blokada po bezczynności":
            "Automatic lock after inactivity",
        " +%@":
            " +%@",
        "Włóż YubiKey":
            "Insert YubiKey",
        "Witaj w Sejf USB":
            "Welcome to Sejf USB",
        "Szyfrowany sejf na pliki — otwierasz go hasłem i dotknięciem YubiKeya.":
            "An encrypted vault for your files — you open it with a password and a touch of your YubiKey.",
        "Utwórz nowy sejf":
            "Create a new vault",
        "Pierwszy sejf na tym Macu albo na pendrivie. Potrzebujesz YubiKeya.":
            "Your first vault on this Mac or on a USB drive. You need a YubiKey.",
        "Otwórz mój sejf":
            "Open my vault",
        "Masz już sejf (np. na pendrivie) i swój YubiKey z hasłem.":
            "You already have a vault (e.g. on a USB drive) and your YubiKey with a password.",
        "Dołącz do sejfu":
            "Join a vault",
        "Ktoś udostępnia Ci swój sejf. Osoba z dostępem odblokuje go przy Tobie, a Ty dodasz swój klucz.":
            "Someone is sharing their vault with you. A person with access unlocks it next to you, and you add your key.",
        "Twoje sejfy":
            "Your vaults",
        "Otwórz istniejący":
            "Open existing",
        "Nowy sejf":
            "New vault",
        "Pokaż w Finderze":
            "Show in Finder",
        "Usuń z listy (pliki zostają)":
            "Remove from list (files stay)",
        "Sejf na „%@”":
            "Vault on “%@”",
        "Znaleziono na podłączonym nośniku":
            "Found on a connected drive",
        "Sejfy są na liście tylko na tym Macu. Usunięcie z listy nie kasuje plików.":
            "Vaults are listed only on this Mac. Removing a vault from the list does not delete any files.",
        "Pendrive „":
            "USB drive “",
        " · niedostępny":
            " · unavailable",
        "Nazwa sejfu jest widoczna bez odblokowania — nie wpisuj w niej nic tajnego.":
            "The vault name is visible without unlocking — do not put anything secret in it.",
        "Nazwa, np. Dokumenty rodzinne":
            "Name, e.g. Family documents",
        "Gdzie zapisać sejf?":
            "Where should the vault be stored?",
        "Na tym Macu":
            "On this Mac",
        "~/Sejfy/%@ — poza iCloud, z kopią w Time Machine":
            "~/Sejfy/%@ — outside iCloud, backed up by Time Machine",
        "Na pendrivie „%@”":
            "On USB drive “%@”",
        "w folderze „%@” (na nośniku jest już inny sejf)":
            "in folder “%@” (there is already another vault on the drive)",
        "%@ wolne":
            "%@ free",
        "W wybranym folderze…":
            "In a chosen folder…",
        "poza Pulpitem, Dokumentami i iCloud Drive":
            "outside Desktop, Documents and iCloud Drive",
        "Dalej":
            "Next",
        "Włóż YubiKey do portu USB":
            "Insert the YubiKey into a USB port",
        "%@ — nieobsługiwany":
            "%@ — not supported",
        "%@ gotowy":
            "%@ ready",
        "Klucz FIDO2: YubiKey 5, Security Key NFC / C NFC lub inny z obsługą hmac-secret. Na Macu wkładasz go do USB.":
            "FIDO2 key: YubiKey 5, Security Key NFC / C NFC or another key with hmac-secret support. On a Mac you plug it into USB.",
        "Ten klucz nie obsługuje FIDO2 hmac-secret (np. starszy klucz tylko U2F). Użyj YubiKey 5 albo Security Key z FIDO2.":
            "This key does not support FIDO2 hmac-secret (e.g. an older U2F-only key). Use a YubiKey 5 or a Security Key with FIDO2.",
        "Nie dotykaj klucza teraz. Kliknij przycisk poniżej — gdy pojawi się „Dotknij przycisku na YubiKey…”, wtedy dotknij.":
            "Do not touch the key now. Click the button below — when “Touch the button on the YubiKey…” appears, touch it.",
        "Nowy sejf na „%@”":
            "New vault on “%@”",
        "Krok 1 z 2 · ustaw hasło":
            "Step 1 of 2 · set a password",
        "Krok 2 z 2 · dodaj YubiKey":
            "Step 2 of 2 · add your YubiKey",
        "Dodaj YubiKey":
            "Add YubiKey",
        "Twoje imię":
            "Your name",
        "Np. Anna — widoczne dla innych użytkowników tego sejfu":
            "E.g. Anna — visible to other users of this vault",
        "Twoje hasło":
            "Your password",
        "Hasła się różnią":
            "Passwords do not match",
        "Na tym etapie nie dotykaj YubiKeya. Klucz dodasz w następnym kroku.":
            "Do not touch the YubiKey at this stage. You will add the key in the next step.",
        "Na koniec dostaniesz hasło odzyskiwania. Otwiera ono sejf, gdy zgubisz YubiKey.":
            "At the end you will get a recovery password. It opens the vault if you lose your YubiKey.",
        "Dalej: dodaj YubiKey":
            "Next: add YubiKey",
        "Wstecz":
            "Back",
        "Spróbuj ponownie":
            "Try again",
        "Ten klucz nie obsługuje FIDO2":
            "This key does not support FIDO2",
        "Teraz dotknij złotego przycisku":
            "Now touch the gold button",
        "Nie udało się — spróbuj ponownie":
            "That did not work — try again",
        "Gdy klucz będzie gotowy, aplikacja sama poprosi o dotknięcie.":
            "When the key is ready, the app will ask for a touch by itself.",
        "Kliknij „Spróbuj ponownie”, a gdy pojawi się prośba, dotknij klucza (masz 30 sekund).":
            "Click “Try again”, and when asked, touch the key (you have 30 seconds).",
        "Dotknij krótko złotego przycisku (masz 30 sekund). Aplikacja sama przejdzie dalej.":
            "Briefly touch the gold button (you have 30 seconds). The app will continue by itself.",
        "„%@” jest zablokowany":
            "“%@” is locked",
        "Odblokowywanie":
            "Unlocking",
        "Dołączasz do sejfu „%@”. Poproś osobę, która ma już dostęp (%@), aby odblokowała go tutaj swoim kluczem i hasłem. Potem włożysz swój YubiKey i ustawisz własne hasło.":
            "You are joining the vault “%@”. Ask a person who already has access (%@) to unlock it here with their key and password. Then you will insert your YubiKey and set your own password.",
        "Hasło sejfu":
            "Vault password",
        "Nie dotykaj jeszcze YubiKeya — poproszę o to w następnym kroku.":
            "Do not touch the YubiKey yet — I will ask for it in the next step.",
        "Zgubiłem YubiKey — użyj hasła odzyskiwania":
            "I lost my YubiKey — use the recovery password",
        "Użyj hasła i YubiKeya":
            "Use password and YubiKey",
        "Dalej: YubiKey":
            "Next: YubiKey",
        "Odblokuj":
            "Unlock",
        "Krok 2 z 2 · YubiKey":
            "Step 2 of 2 · YubiKey",
        "Krok 1 z 2 · wpisz hasło":
            "Step 1 of 2 · enter your password",
        "Wpisz 32-znakowe hasło odzyskiwania.":
            "Enter the 32-character recovery password.",
        "Twoje hasło odzyskiwania":
            "Your recovery password",
        "Zapisz go ręcznie na papierze i schowaj w bezpiecznym miejscu.":
            "Write it down by hand on paper and keep it in a safe place.",
        "NIE zapisuj go na tym pendrivie ani w zdjęciu/notatce na telefonie.":
            "Do NOT save it on this USB drive or in a photo/note on your phone.",
        "Otwiera sejf bez YubiKeya i hasła — chroń je jak klucz do sejfu.":
            "It opens the vault without the YubiKey and password — protect it like the key to the vault.",
        "Nie kopiuj go do schowka ani nie rób zrzutu ekranu.":
            "Do not copy it to the clipboard or take a screenshot.",
        "Nie zostanie pokazane ponownie (możesz później wygenerować nowe).":
            "It will not be shown again (you can generate a new one later).",
        "Zapisałem hasło odzyskiwania w bezpiecznym miejscu":
            "I have written down the recovery password in a safe place",
        "Gotowe":
            "Done",
        "Kod PIN FIDO2 klucza":
            "FIDO2 PIN of the key",
        "Ten klucz wymaga swojego kodu PIN FIDO2 przy rejestracji (ustawionego np. w Yubico Authenticator). To nie jest hasło sejfu — PIN zostaje tylko w kluczu i nie jest nigdzie zapisywany.":
            "This key requires its FIDO2 PIN for registration (set e.g. in Yubico Authenticator). This is not the vault password — the PIN stays only in the key and is never stored.",
        "PIN FIDO2 (min. 4 znaki)":
            "FIDO2 PIN (min. 4 characters)",
        "Po 8 błędnych próbach funkcje FIDO2 klucza zostaną zablokowane do czasu resetu.":
            "After 8 wrong attempts the key's FIDO2 functions will be blocked until it is reset.",
        "Samotest kryptograficzny nie powiódł się":
            "Cryptographic self-test failed",
        "Zamknij aplikację":
            "Quit the app",
        "YubiKey: ten klucz nie jest zarejestrowany w tym sejfie.":
            "YubiKey: this key is not registered in this vault.",
        "YubiKey: operacja odrzucona.":
            "YubiKey: operation rejected.",
        "YubiKey: nie dotknięto klucza na czas — spróbuj ponownie.":
            "YubiKey: the key was not touched in time — try again.",
        "Ten klucz wymaga kodu PIN FIDO2.":
            "This key requires a FIDO2 PIN.",
        "Nieprawidłowy kod PIN FIDO2.":
            "Wrong FIDO2 PIN.",
        " Pozostało prób: %@.":
            " Attempts left: %@.",
        "Kod PIN FIDO2 jest zablokowany (zbyt wiele błędnych prób). Klucz trzeba zresetować w Yubico Authenticator.":
            "The FIDO2 PIN is blocked (too many wrong attempts). The key must be reset in Yubico Authenticator.",
        "Zbyt wiele błędnych prób PIN — wyjmij klucz, włóż go ponownie i spróbuj jeszcze raz.":
            "Too many wrong PIN attempts — remove the key, insert it again and try once more.",
        "Kod PIN FIDO2 jest za krótki (minimum 4 znaki).":
            "The FIDO2 PIN is too short (minimum 4 characters).",
        "YubiKey: anulowano.":
            "YubiKey: cancelled.",
        "YubiKey: błąd FIDO2 (kod 0x%@).":
            "YubiKey: FIDO2 error (code 0x%@).",
        "Klucz FIDO2":
            "FIDO2 key",
        "Włóż YubiKey.":
            "Insert the YubiKey.",
        "Podłączonych jest kilka kluczy — zostaw tylko jeden.":
            "Several keys are connected — leave only one.",
        "Nie można połączyć się z kluczem — wyjmij go i włóż ponownie.":
            "Cannot connect to the key — remove it and insert it again.",
        "Nieprawidłowa odpowiedź klucza FIDO.":
            "Invalid response from the FIDO key.",
        "Nie można wysłać danych do klucza.":
            "Cannot send data to the key.",
        "Klucz nie odpowiada — spróbuj ponownie.":
            "The key is not responding — try again.",
        "Nieprawidłowa odpowiedź klucza.":
            "Invalid response from the key.",
        "Pusta odpowiedź klucza.":
            "Empty response from the key.",
        "Klucz nie podał swoich możliwości.":
            "The key did not report its capabilities.",
        "Ten klucz nie obsługuje FIDO2 hmac-secret — nie może chronić sejfu.":
            "This key does not support FIDO2 hmac-secret — it cannot protect a vault.",
        "Klucz ma włączone „Always UV” — wyłącz tę opcję w Yubico Authenticator.":
            "The key has “Always UV” enabled — turn this option off in Yubico Authenticator.",
        "Nieprawidłowa odpowiedź przy tworzeniu poświadczenia.":
            "Invalid response while creating the credential.",
        "Brak danych poświadczenia.":
            "Missing credential data.",
        "Nieprawidłowe poświadczenie.":
            "Invalid credential.",
        "Nie udało się uzgodnić klucza z YubiKey.":
            "Key agreement with the YubiKey failed.",
        "Klucz nie wydał tokenu PIN.":
            "The key did not issue a PIN token.",
        "Nieprawidłowe parametry hmac-secret.":
            "Invalid hmac-secret parameters.",
        "Klucz nie wskazał poświadczenia.":
            "The key did not indicate a credential.",
        "Klucz nie zwrócił hmac-secret.":
            "The key did not return hmac-secret.",
        "Samotest kryptograficzny „%@” nie powiódł się. Aplikacja nie będzie przetwarzać danych — zgłoś problem.":
            "Cryptographic self-test “%@” failed. The app will not process any data — please report the problem.",
        "AES-256-GCM (szyfrowanie)":
            "AES-256-GCM (encryption)",
        "AES-256-GCM (odszyfrowanie)":
            "AES-256-GCM (decryption)",
        "AES-256-GCM (wykrycie zmiany)":
            "AES-256-GCM (tamper detection)",
        "Generator losowy":
            "Random generator",
        "Sejf jest zablokowany.":
            "The vault is locked.",
        "Nie udało się wygenerować losowych danych.":
            "Could not generate random data.",
        "Błąd wyprowadzania klucza.":
            "Key derivation error.",
        "Nieprawidłowe hasło lub YubiKey.":
            "Wrong password or YubiKey.",
        "Uszkodzone dane: %@":
            "Damaged data: %@",
        "YubiKey: %@":
            "YubiKey: %@",
        "Nie można usunąć ostatniego klucza YubiKey.":
            "The last YubiKey cannot be removed.",
        "Ten folder jest synchronizowany z iCloud — jawne pliki trafiłyby na serwery Apple. Wybierz folder poza Pulpitem, Dokumentami i iCloud Drive (np. ~/Sejf).":
            "This folder is synced with iCloud — plaintext files would end up on Apple's servers. Choose a folder outside Desktop, Documents and iCloud Drive (e.g. ~/Sejf).",
        "„%@” nie jest zwykłym plikiem.":
            "“%@” is not a regular file.",
        "brak nagłówka sejfu":
            "missing vault header",
        "nieznany format nagłówka":
            "unknown header format",
        "Na tym nośniku już jest sejf.":
            "There is already a vault on this drive.",
        "Hasło musi mieć co najmniej %@ znaków.":
            "The password must be at least %@ characters long.",
        "Ten sejf nie ma klucza FIDO2.":
            "This vault has no FIDO2 key.",
        "Kod odzyskiwania ma nieprawidłowy format.":
            "The recovery code has an invalid format.",
        "Ten YubiKey jest już w sejfie — użyj „Zmień hasło”.":
            "This YubiKey is already in the vault — use “Change password”.",
        "Ten klucz jest już w sejfie (%@).":
            "This key is already in the vault (%@).",
        "Nie znaleziono klucza.":
            "Key not found.",
        "Obecne hasło jest nieprawidłowe.":
            "The current password is wrong.",
        "Nieoczekiwana długość odpowiedzi.":
            "Unexpected response length.",
        "Nie można zapisać na nośniku (brak miejsca lub tylko do odczytu?).":
            "Cannot write to the drive (out of space or read-only?).",
        "nieprawidłowy rozmiar fragmentu":
            "invalid chunk size",
        "nazwa pliku nie zgadza się z zawartością":
            "file name does not match its contents",
        "plik obcięty":
            "file truncated",
        "długość fragmentu":
            "chunk length",
        "dane zostały zmodyfikowane lub uszkodzone (%@)":
            "data has been modified or damaged (%@)",
        "brak treści":
            "missing content",
        "Nie można zapisać w %@.":
            "Cannot write to %@.",
        "YubiKey / Security Key (FIDO2)":
            "YubiKey / Security Key (FIDO2)",
        "Czytnik klucza jest niedostępny.":
            "The key reader is unavailable.",
        "Klucz jest zajęty.":
            "The key is busy.",
        "Brak aplikacji OTP.":
            "No OTP application.",
    ]
}
