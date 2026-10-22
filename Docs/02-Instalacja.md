# Instalacja na innym Macu

## Wymagania

- macOS 14 (Sonoma) lub nowszy, Mac z procesorem Apple lub Intel (aplikacja jest uniwersalna).
- YubiKey z FIDO2. Nie trzeba instalować `ykman` ani innych programów.

## 1. Sprawdź, czy paczka nie została podmieniona

W Terminalu, w rozpakowanym folderze paczki:

```bash
shasum -a 256 -c SHA256SUMS.txt
```

Każda linia powinna kończyć się `OK`. Najlepiej porównaj też sumę samego pliku `.zip` z tą, którą zanotowałeś na zaufanym komputerze.

## 2. Zainstaluj aplikację

1. Skopiuj `Aplikacja/Sejf USB.app` do folderu **`~/Applications`** (Twój katalog domowy → Aplikacje). Może być też `/Applications`.
2. **Nie uruchamiaj aplikacji z pendrive'a.** Kopię na nośniku wymiennym ktoś mógłby podmienić.

## 3. Pierwsze uruchomienie: Gatekeeper

Aplikacja jest podpisana lokalnie („ad-hoc”), a nie certyfikatem dewelopera Apple. Na innym Macu system może więc pokazać komunikat, że nie może sprawdzić aplikacji. Wtedy:

1. Spróbuj otworzyć aplikację raz i zamknij komunikat.
2. Otwórz **Ustawienia systemowe → Prywatność i ochrona**, przewiń w dół i kliknij **„Otwórz mimo to”** przy „Sejf USB”.
3. Potwierdź hasłem Maca.

Możesz też, **po sprawdzeniu sum kontrolnych**, zdjąć znacznik kwarantanny w Terminalu:

```bash
xattr -dr com.apple.quarantine ~/Applications/"Sejf USB.app"
```

## 4. Uprawnienia

Aplikacja nie potrzebuje żadnych zgód systemowych: ani „Monitorowania wejścia”, ani dostępu do sieci. Przy pierwszym otwarciu sejfu na pendrivie macOS może zapytać o dostęp do plików na nośniku wymiennym. Zgódź się.

## 5. Pierwsze uruchomienie

Aplikacja pokaże ekran powitalny z trzema drogami:
- **Utwórz nowy sejf**: zaczynasz od zera;
- **Otwórz mój sejf**: masz już sejf (pendrive albo kopia poza iCloud) oraz swój YubiKey i hasło;
- **Dołącz do sejfu**: ktoś udostępnia Ci swój sejf. Osoba z dostępem odblokowuje go przy Tobie, a Ty dodajesz swój klucz i hasło (`01-Instrukcja-uzytkownika.md`, rozdział 7).

## 6. Budowanie ze źródeł zamiast gotowej aplikacji (najbezpieczniej)

Jeśli wolisz nie ufać gotowemu plikowi `.app`, zbuduj aplikację sam z folderu `Kod` (patrz `05-Budowanie-i-testy.md`). Wystarczą Command Line Tools:

```bash
xcode-select --install
```

```bash
cd Kod && ./build.sh test && ./build.sh
```

## Odinstalowanie

Usuń `Sejf USB.app`. Aplikacja zapisuje tylko listę „Twoje sejfy” (ścieżki i nazwy, bez sekretów). Usuniesz ją tak:

```bash
defaults delete local.sejfusb.app
```

Twoje sejfy (`Sejf.vault`) zostają nietknięte.
