import SwiftUI
import AppKit

struct VolumeInfo: Identifiable, Hashable {
    var id: URL { url }
    let url: URL
    let name: String
    let capacity: Int64
    let available: Int64
    let format: String
    let hasVault: Bool
}

extension VolumeInfo {
    /// Opis lokalizacji sejfu: korzeń nośnika wymiennego albo zwykły folder.
    static func make(url: URL, name: String) -> VolumeInfo {
        let keys: Set<URLResourceKey> = [.volumeURLKey, .volumeIsRemovableKey, .volumeIsEjectableKey,
                                         .volumeLocalizedFormatDescriptionKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey]
        let v = try? url.resourceValues(forKeys: keys)
        let isVolumeRoot = v?.volume?.standardizedFileURL == url.standardizedFileURL
            && (v?.volumeIsRemovable == true || v?.volumeIsEjectable == true)
        return VolumeInfo(url: url, name: name,
                          capacity: Int64(v?.volumeTotalCapacity ?? 0), available: Int64(v?.volumeAvailableCapacity ?? 0),
                          format: isVolumeRoot ? (v?.volumeLocalizedFormatDescription ?? "nośnik") : "folder",
                          hasVault: Vault.exists(on: url))
    }
}

/// Sejf zapamiętany na liście „Twoje sejfy” (tylko ścieżka i nazwa — żadnych sekretów).
struct KnownVault: Codable, Hashable, Identifiable {
    var path: String
    var name: String
    var id: String { path }
    var url: URL { URL(fileURLWithPath: path) }
    var isAvailable: Bool { Vault.exists(on: url) }
}

struct BusyState {
    var message: String
    var touch = false
    var progress: Double?
}

/// Przekazuje postęp z wątku roboczego do interfejsu.
final class Reporter: @unchecked Sendable {
    private weak var model: AppModel?
    init(_ model: AppModel) { self.model = model }
    func update(_ message: String? = nil, touch: Bool? = nil, progress: Double?? = nil) {
        DispatchQueue.main.async { [weak model] in
            guard let model, model.busy != nil else { return }
            if let message { model.busy?.message = message }
            if let touch { model.busy?.touch = touch }
            if let progress { model.busy?.progress = progress }
        }
    }
}

/// Klucz FIDO2, który pokazuje „dotknij” dokładnie wtedy, gdy YubiKey zaczyna migać.
final class TouchingFIDO: FIDOAuthenticator, @unchecked Sendable {
    private let reporter: Reporter
    private let after: String
    private let total: Int
    private let pin: String?
    private var step = 0

    init(reporter: Reporter, after: String, touches total: Int = 1, pin: String? = nil) {
        self.reporter = reporter
        self.after = after
        self.total = total
        self.pin = pin
    }

    private func run<T>(_ body: (YubiKeyFIDO) throws -> T) throws -> T {
        step += 1
        let label = total > 1 ? " (\(step)/\(total))" : ""
        reporter.update(L("Łączenie z YubiKey…"), touch: false)
        let key = YubiKeyFIDO(pin: pin) { [reporter] in reporter.update(L("Teraz dotknij złotego przycisku%@", label), touch: true) }
        defer { reporter.update(after, touch: false) }
        return try body(key)
    }

    func makeCredential(rpID: String) throws -> Data {
        try run { try $0.makeCredential(rpID: rpID) }
    }

    func hmacSecret(rpID: String, credentialIDs: [Data], salt: Data) throws -> (credentialID: Data, output: Data) {
        try run { try $0.hmacSecret(rpID: rpID, credentialIDs: credentialIDs, salt: salt) }
    }

    func probe(rpID: String, credentialIDs: [Data]) throws -> Data? {
        try YubiKeyFIDO().probe(rpID: rpID, credentialIDs: credentialIDs)   // bez dotyku — bez komunikatu
    }
}

/// Prośba o kod PIN FIDO2 (tylko przy rejestracji klucza, który go wymaga).
struct PinPrompt: Identifiable {
    let id = UUID()
    let message: String?
    let retry: (String) -> Void
}

@MainActor
final class AppModel: ObservableObject {
    enum Screen { case pickDrive, setup, unlock, vault }

    @Published var screen: Screen = .pickDrive
    @Published var volumes: [VolumeInfo] = []
    @Published var volume: VolumeInfo?
    @Published var keys: [YubiKeyDevice] = []
    @Published var busy: BusyState?
    @Published var errorMessage: String?
    @Published var notice: String?
    @Published var entries: [FileEntry] = []
    @Published var unreadable = 0
    @Published var recoveryCode: String?
    @Published var keyslots: [Keyslot] = []
    @Published var autoLockRemaining: Int = 0
    /// Klucz, dla którego otwarty jest arkusz „Zmień hasło”.
    @Published var changePasswordSlot: Keyslot?
    @Published var library: [KnownVault] = []
    /// "system", "pl" albo "en" — zmiana odświeża cały interfejs.
    @Published var language: String = Lang.override ?? "system"

    func setLanguage(_ code: String) {
        Lang.set(code == "system" ? nil : code)
        language = code
    }
    @Published var pinPrompt: PinPrompt?
    /// Wynik cichego sprawdzenia podłączonego klucza (gdy otwarty jest panel kluczy / hasła / użytkownika).
    @Published var connectedSlotID: String?
    @Published var connectedKeyChecked = false
    /// Samotesty kryptograficzne przy starcie — gdy zawiodą, aplikacja nie przetwarza danych.
    @Published var selfTestFailure: String?
    @Published var selfTestsPassed: [String] = []
    private var probedKeys: [YubiKeyDevice] = []
    @Published var showNewVault = false
    @Published var showAddUser = false
    /// Nowa osoba dołącza do istniejącego sejfu — po odblokowaniu otworzy się „Dodaj użytkownika”.
    @Published var joining = false
    /// Nazwa sejfu wybrana w kreatorze „Nowy sejf”.
    var pendingVaultName: String?

    static let autoLockSeconds = 5 * 60
    static let lastFolderKey = "lastVaultFolder"
    static let libraryKey = "knownVaults"
    static let previewPrefix = "SejfUSB-podglad-"
    private(set) var vault: Vault?
    private var lastActivity = Date()
    private var previewDirs: [URL] = []
    private var pollTask: Task<Void, Never>?
    private var tickTimer: Timer?
    private var observers: [NSObjectProtocol] = []

    init() {
        do {
            selfTestsPassed = try SelfTest.run()
        } catch {
            selfTestFailure = error.localizedDescription
        }
        Self.removeStalePreviews()
        loadLibrary()
        refreshVolumes()
        let appVolume = Bundle.main.bundleURL.deletingLastPathComponent().standardizedFileURL
        let candidates = library.filter(\.isAvailable).map(\.url) + discoveredVaults.map(\.url)
        if let own = volumes.first(where: { $0.url.standardizedFileURL == appVolume && $0.hasVault }) {
            select(own)
        } else if candidates.count == 1, let only = candidates.first {
            open(url: only)
        }
        warnIfRunningFromRemovableMedia()
        startPolling()
        installObservers()
    }

    /// Kopia aplikacji na pendrivie mogła zostać podmieniona przez kogoś, kto miał do niego dostęp.
    private func warnIfRunningFromRemovableMedia() {
        let values = try? Bundle.main.bundleURL.resourceValues(forKeys: [.volumeIsRemovableKey, .volumeIsEjectableKey])
        guard values?.volumeIsRemovable == true || values?.volumeIsEjectable == true else { return }
        errorMessage = L("Uruchamiasz aplikację z nośnika wymiennego. Ktoś, kto miał dostęp do pendrive'a, mógł ją podmienić i przechwycić hasło oraz odpowiedź YubiKeya.\n\nBezpieczniej: zainstaluj aplikację na Macu (np. w ~/Applications) i uruchamiaj ją stamtąd — na pendrivie wystarczy sam folder Sejf.vault.")
    }

    // MARK: - Nośniki

    func refreshVolumes() {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeIsRemovableKey, .volumeIsEjectableKey, .volumeIsInternalKey,
                                      .volumeTotalCapacityKey, .volumeAvailableCapacityKey, .volumeLocalizedFormatDescriptionKey]
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []
        volumes = urls.compactMap { url in
            guard let v = try? url.resourceValues(forKeys: Set(keys)),
                  v.volumeIsRemovable == true || v.volumeIsEjectable == true,
                  url.path != "/" else { return nil }
            return VolumeInfo(url: url, name: v.volumeName ?? url.lastPathComponent,
                              capacity: Int64(v.volumeTotalCapacity ?? 0), available: Int64(v.volumeAvailableCapacity ?? 0),
                              format: v.volumeLocalizedFormatDescription ?? "", hasVault: Vault.exists(on: url))
        }
    }

    // MARK: - Biblioteka sejfów

    private func loadLibrary() {
        if let data = UserDefaults.standard.data(forKey: Self.libraryKey),
           let list = try? JSONDecoder().decode([KnownVault].self, from: data) {
            library = list
        }
        // Migracja z 1.1: ostatnio używany folder trafia na listę.
        if let path = UserDefaults.standard.string(forKey: Self.lastFolderKey) {
            let url = URL(fileURLWithPath: path)
            if Vault.exists(on: url), !library.contains(where: { $0.path == path }) {
                library.append(KnownVault(path: path, name: (try? Vault.open(on: url).displayName) ?? url.lastPathComponent))
                saveLibrary()
            }
            UserDefaults.standard.removeObject(forKey: Self.lastFolderKey)
        }
    }

    private func saveLibrary() {
        if let data = try? JSONEncoder().encode(library) { UserDefaults.standard.set(data, forKey: Self.libraryKey) }
    }

    private func remember(_ url: URL, name: String) {
        let path = url.standardizedFileURL.path
        if let i = library.firstIndex(where: { $0.path == path }) {
            library[i].name = name
        } else {
            library.append(KnownVault(path: path, name: name))
        }
        library.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        saveLibrary()
    }

    func forget(_ known: KnownVault) {
        library.removeAll { $0.id == known.id }
        saveLibrary()
    }

    /// Sejfy na podłączonych nośnikach, których nie ma jeszcze na liście.
    var discoveredVaults: [VolumeInfo] {
        volumes.filter { v in v.hasVault && !library.contains { $0.path == v.url.standardizedFileURL.path } }
    }

    func open(_ known: KnownVault) {
        guard known.isAvailable else {
            errorMessage = L("Sejfu „%@” nie ma pod ścieżką %@. Podłącz nośnik albo usuń sejf z listy.", known.name, known.path)
            return
        }
        open(url: known.url)
    }

    func open(url: URL) {
        select(VolumeInfo.make(url: url, name: library.first { $0.path == url.standardizedFileURL.path }?.name ?? url.lastPathComponent))
    }

    /// „Mam już sejf” / „Dołączam do czyjegoś sejfu”: wybór folderu z istniejącym sejfem.
    func addExistingVault(joining: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = L("Otwórz")
        panel.message = L("Wskaż folder Sejf.vault albo folder, w którym się znajduje (np. na pendrivie)")
        panel.directoryURL = volumes.first(where: \.hasVault)?.url ?? FileManager.default.homeDirectoryForCurrentUser
        guard panel.runModal() == .OK, var url = panel.url else { return }
        if url.lastPathComponent == Vault.folderName { url.deleteLastPathComponent() }
        guard Vault.exists(on: url) else {
            errorMessage = L("W „%@” nie ma sejfu (folderu Sejf.vault z plikiem header.json).", url.lastPathComponent)
            return
        }
        guard !CloudCheck.isInICloud(url) else {
            errorMessage = SejfError.inICloud.localizedDescription + L(" Przenieś cały folder sejfu (np. do ~/Sejf) i spróbuj ponownie.")
            return
        }
        self.joining = joining
        open(url: url)
    }

    // MARK: - Nowy sejf

    enum NewVaultLocation: Hashable { case mac, volume(URL), custom }

    /// Przygotowuje miejsce na nowy sejf i przechodzi do kreatora (hasło → YubiKey).
    func prepareNewVault(name: String, location: NewVaultLocation) {
        let cleanName = Vault.cleanName(name) ?? "Sejf"
        let folderName = cleanName.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        let fm = FileManager.default
        var target: URL
        switch location {
        case .mac:
            target = fm.homeDirectoryForCurrentUser.appendingPathComponent("Sejfy", isDirectory: true)
                .appendingPathComponent(folderName, isDirectory: true)
        case .volume(let root):
            target = Vault.exists(on: root) ? root.appendingPathComponent(folderName, isDirectory: true) : root
        case .custom:
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.canCreateDirectories = true
            panel.prompt = L("Wybierz")
            panel.message = L("Wybierz pusty folder na sejf — poza Pulpitem, Dokumentami i iCloud Drive")
            panel.directoryURL = fm.homeDirectoryForCurrentUser
            guard panel.runModal() == .OK, let url = panel.url else { return }
            guard !Self.isProtectedFolder(url) else {
                errorMessage = L("Wybierz osobny folder tylko na sejf, a nie „%@”.", url.lastPathComponent)
                return
            }
            target = url
        }
        guard !CloudCheck.isInICloud(target) else { errorMessage = SejfError.inICloud.localizedDescription; return }
        guard !Vault.exists(on: target) else {
            errorMessage = L("W „%@” jest już sejf. Wybierz inną nazwę albo miejsce.", target.path)
            return
        }
        do {
            try fm.createDirectory(at: target, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        } catch {
            errorMessage = L("Nie można utworzyć folderu: %@", error.localizedDescription)
            return
        }
        pendingVaultName = cleanName
        joining = false
        select(VolumeInfo.make(url: target, name: cleanName))
    }

    func select(_ info: VolumeInfo) {
        lock()
        if CloudCheck.isInICloud(info.url) {
            errorMessage = SejfError.inICloud.localizedDescription
            volume = nil
            vault = nil
            screen = .pickDrive
            return
        }
        volume = info
        if Vault.exists(on: info.url) {
            do {
                let opened = try Vault.open(on: info.url)
                vault = opened
                volume = VolumeInfo(url: info.url, name: opened.displayName, capacity: info.capacity,
                                    available: info.available, format: info.format, hasVault: true)
                remember(info.url, name: opened.displayName)
                screen = .unlock
            } catch {
                errorMessage = L("Nie można odczytać sejfu: %@", error.localizedDescription)
                screen = .pickDrive
            }
        } else {
            vault = nil
            screen = .setup
        }
    }

    var isFolder: Bool { volume?.format == "folder" }

    /// Foldery, których nie wolno traktować jak "nośnika" (szyfrowanie przeniosłoby całą ich zawartość).
    static func isProtectedFolder(_ url: URL) -> Bool {
        let fm = FileManager.default
        let path = url.standardizedFileURL.resolvingSymlinksInPath().path
        let home = fm.homeDirectoryForCurrentUser.standardizedFileURL.path
        let dirs: [FileManager.SearchPathDirectory] = [.desktopDirectory, .documentDirectory, .downloadsDirectory,
                                                       .picturesDirectory, .moviesDirectory, .musicDirectory,
                                                       .libraryDirectory, .applicationDirectory]
        let protected = Set([home, "/", "/Users", "/Applications", "/System", "/Volumes"] +
                            dirs.compactMap { fm.urls(for: $0, in: .userDomainMask).first?.standardizedFileURL.path })
        return protected.contains(path)
    }

    func goHome() {
        lock()
        volume = nil
        vault = nil
        joining = false
        refreshVolumes()
        screen = .pickDrive
    }

    func eject() {
        guard let url = volume?.url else { return }
        lock()
        do {
            try NSWorkspace.shared.unmountAndEjectDevice(at: url)
            notice = L("Nośnik „%@” można bezpiecznie wyjąć.", volume?.name ?? "")
            volume = nil
            vault = nil
            refreshVolumes()
            screen = .pickDrive
        } catch {
            errorMessage = L("Nie udało się wysunąć: %@", error.localizedDescription)
        }
    }

    // MARK: - YubiKey

    private func startPolling() {
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if self.busy == nil, self.screen != .vault || self.wantsKeyPolling {
                    let found = await Task.detached { KeyScanner.scan() }.value
                    if found != self.keys { self.keys = found }
                    await self.checkConnectedKey()
                }
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    /// Ustawiane, gdy otwarty jest arkusz zarządzania kluczami.
    var wantsKeyPolling = false {
        didSet { if wantsKeyPolling { probedKeys = []; connectedKeyChecked = false; Task { await checkConnectedKey() } } }
    }

    /// Bez dotyku sprawdza, który keyslot należy do podłączonego klucza (działa też bez numeru seryjnego).
    private func checkConnectedKey() async {
        guard screen == .vault, wantsKeyPolling, busy == nil, let vault else { return }
        guard keys.count == 1 else {
            connectedSlotID = nil
            connectedKeyChecked = false
            probedKeys = keys
            return
        }
        guard keys != probedKeys else { return }
        probedKeys = keys
        let result = await Task.detached { Result { try vault.connectedSlot(fido: YubiKeyFIDO()) } }.value
        switch result {
        case .success(let slot):
            connectedSlotID = slot?.id
            connectedKeyChecked = true
        case .failure:
            probedKeys = []          // klucz chwilowo zajęty — spróbujemy przy następnym odświeżeniu
            connectedKeyChecked = false
        }
    }

    // MARK: - Przypadkowe dotknięcie klucza

    private var strayTouchAt: Date?

    func warnStrayTouch() {
        strayTouchAt = Date()
        errorMessage = L("Dotknięto YubiKey, gdy aplikacja o to nie prosiła — klucz „wpisał” swój kod OTP jak klawiatura. Usunąłem go z pola hasła.\n\nJak zrobić to dobrze:\n1. Wpisz hasło.\n2. Kliknij „Dalej”.\n3. Dopiero gdy pojawi się „Teraz dotknij złotego przycisku”, dotknij klucza.")
    }

    /// Enter wysłany przez YubiKey zaraz po kodzie nie powinien uruchamiać odblokowania.
    var justStrayTouched: Bool { strayTouchAt.map { Date().timeIntervalSince($0) < 1.5 } ?? false }

    // MARK: - Sejf

    func createVault(owner: String, password: String, pin: String? = nil, failed: (() -> Void)? = nil) {
        guard let volume, let key = keys.first else { return }
        let label = key.name + (key.serial.map { " · \($0)" } ?? "")
        let name = pendingVaultName ?? volume.name
        let retry: (String) -> Void = { [weak self] pin in self?.createVault(owner: owner, password: password, pin: pin, failed: failed) }
        run(L("Tworzenie sejfu…"), { reporter -> (Vault, String) in
            let fido = TouchingFIDO(reporter: reporter, after: L("Tworzenie sejfu…"), touches: 2, pin: pin)
            return try Vault.create(on: volume.url, password: password, fido: fido, serial: key.serial, label: label,
                                    name: name, owner: owner)
        }, then: { [weak self] (result: (Vault, String)) in
            guard let self else { return }
            self.vault = result.0
            self.pendingVaultName = nil
            self.remember(volume.url, name: result.0.displayName)
            self.volume = VolumeInfo(url: volume.url, name: result.0.displayName, capacity: volume.capacity,
                                     available: volume.available, format: volume.format, hasVault: true)
            self.recoveryCode = result.1
            self.didUnlock()
        }, failed: failed, pinRetry: retry)
    }

    func unlock(password: String, failed: (() -> Void)? = nil) {
        guard let vault else { return }
        run(L("Odblokowywanie…"), { reporter in
            try vault.unlock(password: password, fido: TouchingFIDO(reporter: reporter, after: L("Sprawdzanie hasła…")))
        }, then: { [weak self] in self?.didUnlock() }, failed: failed)
    }

    func unlock(recoveryCode: String) {
        guard let vault else { return }
        run(L("Odblokowywanie hasłem odzyskiwania…"), { _ in try vault.unlock(recoveryCode: recoveryCode) }) { [weak self] in
            self?.didUnlock()
            self?.notice = L("Odblokowano hasłem odzyskiwania. Jeśli zgubiłeś YubiKey: 🔑 → Wymień klucz główny (z nowym kluczem).")
        }
    }

    private func didUnlock() {
        screen = .vault
        touch()
        startTick()
        reloadEntries()
        if let owner = vault?.unlockedSlot?.owner, notice == nil { notice = L("Witaj, %@!", owner) }
        if joining {
            joining = false
            showAddUser = true
        }
    }

    var currentUser: String? { vault?.unlockedSlot?.owner }

    func lock() {
        changePasswordSlot = nil
        showAddUser = false
        vault?.lockVault()
        entries = []
        keyslots = []
        tickTimer?.invalidate()
        tickTimer = nil
        if recoveryCode != nil {
            recoveryCode = nil
            notice = L("Hasło odzyskiwania ukryto przy blokadzie. Jeśli go nie zapisałeś: 🔑 → Nowe hasło.")
        }
        for dir in previewDirs { try? Shredder.shredTree(dir) }
        previewDirs = []
        if vault != nil, screen == .vault { screen = .unlock }
    }

    func reloadEntries() {
        guard let vault else { return }
        do {
            let (list, bad) = try vault.listEntries()
            entries = list
            unreadable = bad
            keyslots = vault.header.keyslots
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Pliki

    func pickFiles() -> [URL] {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = L("Wybierz")
        panel.message = L("Wybierz pliki lub foldery do zaszyfrowania w sejfie")
        return panel.runModal() == .OK ? panel.urls : []
    }

    /// Elementy leżące obok sejfu (na pendrivie / w folderze sejfu), które nie są jeszcze zaszyfrowane.
    func unencryptedItems() -> [URL] {
        guard let volume else { return [] }
        let skip: Set<String> = ["Sejf USB.app", "SejfUSB"]
        let items = (try? FileManager.default.contentsOfDirectory(at: volume.url, includingPropertiesForKeys: nil)) ?? []
        return items.filter { !skip.contains($0.lastPathComponent) && !Vault.isJunk($0.lastPathComponent) && !Vault.exists(on: $0) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    func encrypt(_ items: [URL], base: URL?, shredOriginals: Bool) {
        guard let vault else { return }
        touch()
        let existing = Dictionary(entries.map { ($0.path, $0) }, uniquingKeysWith: { a, _ in a })
        run(L("Szyfrowanie…"), { reporter -> (Int, [String]) in
            let (files, skipped) = Vault.collectFiles(items, base: base)
            let total = max(1, files.reduce(Int64(0)) { $0 + ((try? $1.url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0) })
            var done: Int64 = 0
            var problems: [String] = skipped.map { L("%@: pominięto (dowiązanie lub plik specjalny) — zostaje na miejscu", $0) }
            var encrypted = 0
            for (i, file) in files.enumerated() {
                reporter.update(L("Szyfrowanie %@/%@: %@", i + 1, files.count, file.url.lastPathComponent))
                do {
                    let start = done
                    let (entry, sha) = try vault.encryptFile(at: file.url, relativePath: file.relative) { n in
                        reporter.update(progress: .some(Double(start + n) / Double(total)))
                    }
                    done += entry.size
                    encrypted += 1
                    if let old = existing[file.relative] { try? vault.delete(old) }
                    if shredOriginals {
                        reporter.update(L("Weryfikacja i usuwanie oryginału: %@", file.url.lastPathComponent))
                        guard try vault.verify(entry, sha256: sha) else {
                            problems.append(L("%@: weryfikacja nie powiodła się — oryginał zachowany", file.relative))
                            continue
                        }
                        try Shredder.shred(file.url)
                    }
                } catch {
                    problems.append(L("%@: %@", file.relative, error.localizedDescription))
                }
            }
            if shredOriginals {
                // Usuwamy tylko foldery, w których naprawdę nic nie zostało.
                for item in items where (try? FileManager.default.attributesOfItem(atPath: item.path))?[.type] as? FileAttributeType == .typeDirectory {
                    if !Shredder.removeEmptyDirectories(item) {
                        problems.append(L("%@: folder nie jest pusty — zostawiony", item.lastPathComponent))
                    }
                }
            }
            return (encrypted, problems)
        }) { [weak self] (result: (Int, [String])) in
            guard let self else { return }
            self.reloadEntries()
            if result.1.isEmpty {
                self.notice = L("Zaszyfrowano plików: %@", result.0) + (shredOriginals ? L(". Oryginały usunięte.") : ".")
            } else {
                self.errorMessage = L("Zaszyfrowano plików: %@. Uwagi:\n", result.0) + result.1.prefix(10).joined(separator: "\n")
            }
        }
    }

    func decrypt(_ selected: [FileEntry]) {
        guard let vault, !selected.isEmpty else { return }
        touch()
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = L("Odszyfruj tutaj")
        panel.message = L("Gdzie zapisać odszyfrowane pliki? Nie na Pulpicie ani w Dokumentach (iCloud) i nie na pendrivie.")
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        guard panel.runModal() == .OK, let dir = panel.url else { return }
        guard !CloudCheck.isInICloud(dir) else {
            errorMessage = L("Ten folder jest synchronizowany z iCloud — odszyfrowane pliki trafiłyby na serwery Apple. Wybierz np. Pobrane.")
            return
        }
        run(L("Odszyfrowywanie…"), { reporter -> Int in
            let total = max(1, selected.reduce(Int64(0)) { $0 + $1.size })
            var done: Int64 = 0
            for (i, e) in selected.enumerated() {
                reporter.update(L("Odszyfrowywanie %@/%@: %@", i + 1, selected.count, e.name))
                let start = done
                try vault.decrypt(e, into: dir) { n in reporter.update(progress: .some(Double(start + n) / Double(total))) }
                done += e.size
            }
            return selected.count
        }) { [weak self] (count: Int) in
            self?.notice = L("Odszyfrowano plików: %@. Usuń je, gdy przestaną być potrzebne.", count)
            NSWorkspace.shared.activateFileViewerSelecting([dir])
        }
    }

    /// Podgląd: odszyfrowanie do prywatnego katalogu tymczasowego, niszczonego przy blokadzie.
    func preview(_ entry: FileEntry) {
        guard let vault else { return }
        touch()
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(Self.previewPrefix + UUID().uuidString)
        previewDirs.append(dir)
        run(L("Otwieranie %@…", entry.name), { _ -> URL in
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
            return try vault.decrypt(entry, into: dir, keepFolders: false)
        }) { (url: URL) in
            NSWorkspace.shared.open(url)
        }
    }

    /// Podglądy pozostawione po awarii lub wymuszonym zamknięciu aplikacji.
    private static func removeStalePreviews() {
        let tmp = FileManager.default.temporaryDirectory
        let items = (try? FileManager.default.contentsOfDirectory(at: tmp, includingPropertiesForKeys: nil)) ?? []
        for item in items where item.lastPathComponent.hasPrefix(previewPrefix) || item.lastPathComponent.hasPrefix("SejfUSB-") {
            try? Shredder.shredTree(item)
        }
    }

    func delete(_ selected: [FileEntry]) {
        guard let vault else { return }
        touch()
        run(L("Usuwanie…"), { _ in for e in selected { try vault.delete(e) } }) { [weak self] in self?.reloadEntries() }
    }

    // MARK: - Klucze

    private static var rotationHint: String {
        L("Stare kopie sejfu (np. z kopii zapasowej) nadal otwiera poprzedni dostęp — aby to wykluczyć: 🔑 → Wymień klucz główny.")
    }

    /// Nowy użytkownik albo zapasowy klucz istniejącego (ten sam `owner`).
    func addUser(owner: String, serial: Int?, keyName: String, password: String, pin: String? = nil) {
        guard let vault else { return }
        touch()
        let label = keyName + (serial.map { " · \($0)" } ?? "")
        let existing = vault.users.contains(owner)
        let retry: (String) -> Void = { [weak self] pin in
            self?.addUser(owner: owner, serial: serial, keyName: keyName, password: password, pin: pin)
        }
        run(existing ? L("Dodawanie zapasowego klucza…") : L("Dodawanie użytkownika…"), { reporter in
            try vault.addFIDOKey(password: password,
                                 fido: TouchingFIDO(reporter: reporter, after: L("Zapisywanie…"), touches: 2, pin: pin),
                                 serial: serial, label: label, owner: owner)
        }, then: { [weak self] in
            self?.keyslots = vault.header.keyslots
            self?.notice = existing ? L("Dodano zapasowy klucz dla: %@.", owner) : L("Dodano użytkownika „%@”. Od teraz otwiera ten sejf swoim kluczem i hasłem.", owner)
        }, pinRetry: retry)
    }

    /// Otwiera arkusz zmiany hasła — dla wskazanego klucza albo dla podłączonego YubiKeya.
    func beginChangePassword(_ slot: Keyslot? = nil) {
        guard screen == .vault else { return }
        touch()
        let fido = keyslots.filter { $0.kind == .fido2 }
        guard let target = slot ?? connectedFIDOSlot ?? (fido.count == 1 ? fido.first : nil) else {
            errorMessage = L("Włóż YubiKey, którego hasło chcesz zmienić.")
            return
        }
        changePasswordSlot = target
    }

    func changePassword(slot: Keyslot, currentPassword: String, newPassword: String) {
        guard let vault else { return }
        touch()
        if connectedKeyChecked, connectedSlotID != slot.id {
            errorMessage = L("Podłączony klucz nie należy do „%@”. Włóż właściwy klucz.", slot.displayName)
            return
        }
        run(L("Zmiana hasła…"), { reporter in
            try vault.changePassword(slotID: slot.id, currentPassword: currentPassword, newPassword: newPassword,
                                     fido: TouchingFIDO(reporter: reporter, after: L("Zapisywanie nowego hasła…")))
        }) { [weak self] in
            self?.keyslots = vault.header.keyslots
            self?.notice = L("Hasło zmienione. ") + Self.rotationHint
        }
    }

    func regenerateRecovery() {
        guard let vault else { return }
        touch()
        run(L("Generowanie hasła odzyskiwania…"), { _ in try vault.regenerateRecoveryCode() }) { [weak self] (code: String) in
            self?.keyslots = vault.header.keyslots
            self?.recoveryCode = code
        }
    }

    func removeSlot(_ slot: Keyslot) {
        guard let vault else { return }
        touch()
        run(L("Usuwanie klucza…"), { _ in try vault.removeSlot(id: slot.id) }) { [weak self] in
            self?.keyslots = vault.header.keyslots
            self?.notice = L("Usunięto „%@”. ", slot.label) + Self.rotationHint
        }
    }

    /// Klucz FIDO2 sejfu odpowiadający podłączonemu YubiKeyowi.
    var connectedFIDOSlot: Keyslot? {
        if connectedKeyChecked { return keyslots.first { $0.id == connectedSlotID } }
        let fido = keyslots.filter { $0.kind == .fido2 }
        let serials = Set(keys.compactMap(\.serial))
        if let current = vault?.unlockedSlot, current.kind == .fido2, current.serial.map(serials.contains) ?? false {
            return current
        }
        return fido.first { $0.serial.map(serials.contains) ?? false } ?? (fido.count == 1 && keys.count == 1 ? fido.first : nil)
    }

    func rotateMasterKey(slot: Keyslot, password: String) {
        guard let vault else { return }
        touch()
        run(L("Wymiana klucza głównego…"), { reporter -> String in
            try vault.rotateMasterKey(keepSlotID: slot.id, password: password,
                                      fido: TouchingFIDO(reporter: reporter, after: L("Szyfrowanie plików od nowa…"))) { done, total in
                reporter.update(L("Szyfrowanie plików od nowa: %@/%@", done, total), progress: .some(total == 0 ? 1 : Double(done) / Double(total)))
            }
        }) { [weak self] (code: String) in
            guard let self else { return }
            self.reloadEntries()
            self.recoveryCode = code
            self.notice = L("Klucz główny wymieniony. Stare klucze, hasła i kopie nagłówka nie otwierają już tego sejfu.")
        }
    }

    // MARK: - Automatyczna blokada

    func touch() { lastActivity = Date() }

    private func startTick() {
        tickTimer?.invalidate()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.screen == .vault else { return }
                if self.busy != nil { self.touch() }
                let left = Self.autoLockSeconds - Int(Date().timeIntervalSince(self.lastActivity))
                self.autoLockRemaining = max(0, left)
                if left <= 0 {
                    self.lock()
                    self.notice = L("Sejf zablokowano automatycznie po %@ min bezczynności.", Self.autoLockSeconds / 60)
                }
            }
        }
    }

    private func installObservers() {
        let ws = NSWorkspace.shared.notificationCenter
        let lockNow: @Sendable (Notification) -> Void = { [weak self] _ in
            Task { @MainActor in self?.lock() }
        }
        observers.append(ws.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main, using: lockNow))
        observers.append(ws.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main, using: lockNow))
        observers.append(DistributedNotificationCenter.default().addObserver(
            forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main, using: lockNow))
        for name in [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification] {
            observers.append(ws.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let url = note.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL
                Task { @MainActor in
                    guard let self else { return }
                    if name == NSWorkspace.didUnmountNotification, let url,
                       url.standardizedFileURL == self.volume?.url.standardizedFileURL {
                        self.lock()
                        self.volume = nil
                        self.vault = nil
                        self.screen = .pickDrive
                        self.notice = L("Nośnik został odłączony — sejf zablokowany.")
                    }
                    self.refreshVolumes()
                    if self.screen == .pickDrive, self.volume == nil, name == NSWorkspace.didMountNotification,
                       let url, let v = self.volumes.first(where: { $0.url == url }), v.hasVault {
                        self.select(v)
                    }
                }
            })
        }
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .scrollWheel]) { [weak self] event in
            self?.touch()
            return event
        }
    }

    // MARK: - Wykonywanie w tle

    private func run<T>(_ message: String, _ work: @escaping @Sendable (Reporter) throws -> T,
                        then: @escaping (T) -> Void, failed: (() -> Void)? = nil,
                        pinRetry: ((String) -> Void)? = nil) {
        guard busy == nil else { return }
        guard selfTestFailure == nil else { errorMessage = selfTestFailure; return }
        busy = BusyState(message: message)
        let reporter = Reporter(self)
        Task {
            do {
                let value = try await Task.detached(priority: .userInitiated) { try work(reporter) }.value
                busy = nil
                then(value)
            } catch {
                busy = nil
                failed?()
                if let pinRetry, let ctap = error as? CTAPError, ctap.isPINRequired || ctap.isPINInvalid {
                    pinPrompt = PinPrompt(message: ctap.isPINInvalid ? ctap.localizedDescription : nil, retry: pinRetry)
                } else {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func run(_ message: String, _ work: @escaping @Sendable (Reporter) throws -> Void,
                     then: @escaping () -> Void, failed: (() -> Void)? = nil, pinRetry: ((String) -> Void)? = nil) {
        run(message, work, then: { (_: Void) in then() }, failed: failed, pinRetry: pinRetry)
    }
}
