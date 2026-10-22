import Foundation
import CryptoKit

// Schemat:
//   klucz główny (losowy, 256 bit) szyfruje pliki;
//   każdy "keyslot" przechowuje klucz główny zaszyfrowany AES-256-GCM kluczem KEK:
//     FIDO2:    KEK = HKDF-SHA256( PBKDF2(hasło, sól, 3M) || hmac-secret(sól) z YubiKeya ) — wymaga dotknięcia
//     odzysk.:  KEK = HKDF-SHA256( 160-bitowy kod odzyskiwania )
//   plik: klucz pliku = HKDF(klucz główny, losowe ID pliku), fragmenty po 1 MiB w AES-256-GCM,
//   numer fragmentu w nonce i AAD + flaga "ostatni" => wykrycie podmiany, przestawienia i obcięcia.
//   Wymiana klucza głównego szyfruje wszystkie pliki od nowa — unieważnia stare klucze, hasła i kopie nagłówka.

public struct Keyslot: Codable, Identifiable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable { case fido2, recovery }
    public var id: String
    public var kind: Kind
    public var label: String
    public var created: Double
    public var serial: Int?
    /// FIDO2: sól hmac-secret (wspólna dla wszystkich kluczy FIDO2 sejfu).
    public var challenge: Data?
    public var salt: Data
    public var iterations: Int?
    public var wrappedKey: Data
    /// FIDO2: identyfikator poświadczenia na kluczu.
    public var credentialID: Data?
    /// Imię użytkownika, do którego należy klucz (jawne — nie wpisuj tu sekretów).
    public var owner: String?

    public var displayName: String { owner.map { "\($0) — \(label)" } ?? label }
}

public struct VaultHeader: Codable, Sendable {
    public var format = "sejf-usb"
    public var version = 1
    public var vaultID: Data
    public var created: Double
    public var chunkSize: Int
    public var keyslots: [Keyslot]
    /// Nazwa sejfu (jawna — widoczna bez odblokowania).
    public var name: String?
}

public struct FileEntry: Identifiable, Hashable, Sendable {
    public let id: String
    public let path: String
    public let size: Int64
    public let modified: Date
    public let added: Date
    public var name: String { (path as NSString).lastPathComponent }
}

struct FileMeta: Codable {
    var path: String
    var size: Int64
    var modified: Double
    var added: Double
}

public final class Vault: @unchecked Sendable {
    public static let folderName = "Sejf.vault"
    static let headerName = "header.json"
    static let backupHeaderName = "header.bak.json"
    static let nextHeaderName = "header.next.json"
    static let dataFolderName = "data"
    static let newDataFolderName = "data.new"
    static let oldDataFolderName = "data.old"
    static let blobExtension = "sejf"
    public static let defaultIterations = 3_000_000
    public static let minPasswordLength = 12
    public static let fidoRP = "sejf-usb"
    static let magic = Data("SEJF".utf8)
    static let blobHeaderSize = 4 + 1 + 16 + 4
    static let maxMetaSize = 1 << 20

    public let root: URL
    public private(set) var header: VaultHeader
    /// Keyslot, którym ostatnio odblokowano sejf (np. do powitania użytkownika).
    public private(set) var unlockedSlotID: String?
    private var masterKey: SymmetricKey?
    private let lock = NSLock()

    private init(root: URL, header: VaultHeader) {
        self.root = root
        self.header = header
    }

    var dataDir: URL { root.appendingPathComponent(Self.dataFolderName, isDirectory: true) }
    public var isUnlocked: Bool { lock.withLock { masterKey != nil } }

    public static func folder(on volume: URL) -> URL {
        volume.appendingPathComponent(folderName, isDirectory: true)
    }

    public static func exists(on volume: URL) -> Bool {
        let dir = folder(on: volume)
        let fm = FileManager.default
        return fm.fileExists(atPath: dir.appendingPathComponent(headerName).path)
            || fm.fileExists(atPath: dir.appendingPathComponent(backupHeaderName).path)
    }

    // MARK: - Otwieranie / tworzenie

    public static func open(on volume: URL) throws -> Vault {
        let dir = folder(on: volume)
        try finishInterruptedRotation(in: dir)
        var lastError: Error = SejfError.corrupt("brak nagłówka sejfu")
        for name in [headerName, backupHeaderName] {
            do {
                let header = try decodeHeader(Data(contentsOf: dir.appendingPathComponent(name)))
                return Vault(root: dir, header: header)
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    private static func decodeHeader(_ data: Data) throws -> VaultHeader {
        let header = try JSONDecoder().decode(VaultHeader.self, from: data)
        guard header.format == "sejf-usb", header.version == 1,
              header.vaultID.count == 16, (4096...(64 << 20)).contains(header.chunkSize)
        else { throw SejfError.corrupt("nieznany format nagłówka") }
        return header
    }

    /// Sejf otwierany hasłem + dotknięciem klucza FIDO2 (hmac-secret). Zawsze tworzy kod odzyskiwania.
    public static func create(on volume: URL, password: String, fido: FIDOAuthenticator, serial: Int?, label: String,
                              name: String? = nil, owner: String? = nil,
                              chunkSize: Int = 1 << 20,
                              iterations: Int = defaultIterations) throws -> (Vault, String) {
        guard !exists(on: volume) else { throw SejfError.invalidInput("Na tym nośniku już jest sejf.") }
        try checkPassword(password)
        let dir = folder(on: volume)
        var header = VaultHeader(vaultID: try Rand.bytes(16), created: Date().timeIntervalSince1970,
                                 chunkSize: chunkSize, keyslots: [])
        header.name = Self.cleanName(name)
        let vault = Vault(root: dir, header: header)
        let master = SymmetricKey(size: .bits256)
        // Najpierw klucz (dotknięcia) — dopiero po sukcesie cokolwiek zapisujemy na nośniku.
        let credential = try fido.makeCredential(rpID: fidoRP)
        vault.header.keyslots.append(try vault.makeFIDOSlot(master: master, password: password, fido: fido,
                                                            credentialID: credential, hmacSalt: try Rand.bytes(32),
                                                            serial: serial, label: label, owner: Self.cleanName(owner),
                                                            iterations: iterations))
        let (recovery, code) = try vault.makeRecoverySlot(master: master)
        vault.header.keyslots.append(recovery)
        vault.unlockedSlotID = vault.header.keyslots.first?.id
        try FileManager.default.createDirectory(at: vault.dataDir, withIntermediateDirectories: true)
        try vault.saveHeader()
        vault.lock.withLock { vault.masterKey = master }
        return (vault, code)
    }

    /// Nazwy (sejfu, użytkownika): bez znaków sterujących, przycięte, maks. 60 znaków; pusta → nil.
    static func cleanName(_ name: String?) -> String? {
        guard let name else { return nil }
        let cleaned = String(name.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) })
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : String(cleaned.prefix(60))
    }

    public var displayName: String { header.name ?? root.deletingLastPathComponent().lastPathComponent }

    /// Użytkownicy sejfu (imiona z kluczy FIDO2).
    public var users: [String] {
        var seen: [String] = []
        for slot in fidoSlots { let n = slot.owner ?? "Bez nazwy"; if !seen.contains(n) { seen.append(n) } }
        return seen
    }

    public var unlockedSlot: Keyslot? { header.keyslots.first { $0.id == unlockedSlotID } }

    public func rename(to name: String) throws {
        _ = try requireMaster()
        header.name = Self.cleanName(name)
        try saveHeader()
    }

    static func checkPassword(_ password: String) throws {
        guard password.count >= minPasswordLength else {
            throw SejfError.invalidInput("Hasło musi mieć co najmniej \(minPasswordLength) znaków.")
        }
    }

    // MARK: - Odblokowanie

    public var fidoSlots: [Keyslot] { header.keyslots.filter { $0.kind == .fido2 } }
    public var hasRecoverySlot: Bool { header.keyslots.contains { $0.kind == .recovery } }

    /// Jedno dotknięcie: klucz sam wskazuje, które z zarejestrowanych poświadczeń jest jego.
    public func unlock(password: String, fido: FIDOAuthenticator) throws {
        let slots = fidoSlots.filter { $0.credentialID != nil && $0.challenge != nil }
        guard let salt = slots.first?.challenge else { throw SejfError.invalidInput("Ten sejf nie ma klucza FIDO2.") }
        let (credential, output) = try fido.hmacSecret(rpID: Self.fidoRP, credentialIDs: slots.compactMap(\.credentialID), salt: salt)
        guard let slot = slots.first(where: { $0.credentialID == credential }) else { throw SejfError.badCredentials }
        let kek = try fidoKEK(password: password, output: output, salt: slot.salt,
                              iterations: slot.iterations ?? Self.defaultIterations)
        guard let master = try? unwrap(slot, kek: kek) else { throw SejfError.badCredentials }
        lock.withLock { masterKey = master }
        unlockedSlotID = slot.id
    }

    public func unlock(recoveryCode: String) throws {
        guard let bytes = RecoveryCode.decode(recoveryCode) else {
            throw SejfError.invalidInput("Kod odzyskiwania ma nieprawidłowy format.")
        }
        for slot in header.keyslots where slot.kind == .recovery {
            if let master = try? unwrap(slot, kek: recoveryKEK(bytes, salt: slot.salt)) {
                lock.withLock { masterKey = master }
                unlockedSlotID = slot.id
                return
            }
        }
        throw SejfError.badCredentials
    }

    public func lockVault() {
        lock.withLock { masterKey = nil }
        unlockedSlotID = nil
    }

    private func requireMaster() throws -> SymmetricKey {
        guard let key = lock.withLock({ masterKey }) else { throw SejfError.locked }
        return key
    }

    // MARK: - Zarządzanie kluczami

    /// Kolejny klucz FIDO2: nowy użytkownik albo zapasowy klucz istniejącego — dwa dotknięcia.
    public func addFIDOKey(password: String, fido: FIDOAuthenticator, serial: Int?, label: String,
                           owner: String? = nil) throws {
        let master = try requireMaster()
        try Self.checkPassword(password)
        if let serial, fidoSlots.contains(where: { $0.serial == serial }) {
            throw SejfError.invalidInput("Ten YubiKey jest już w sejfie — użyj „Zmień hasło”.")
        }
        let credential = try fido.makeCredential(rpID: Self.fidoRP)
        let salt = try fidoSlots.first?.challenge ?? Rand.bytes(32)   // wspólna sól → odblokowanie jednym dotknięciem
        header.keyslots.append(try makeFIDOSlot(master: master, password: password, fido: fido, credentialID: credential,
                                                hmacSalt: salt, serial: serial, label: label, owner: Self.cleanName(owner),
                                                iterations: Self.defaultIterations))
        try saveHeader()
    }

    /// Zmiana hasła klucza FIDO2. Wymaga obecnego hasła i jednego dotknięcia klucza.
    public func changePassword(slotID: String, currentPassword: String, newPassword: String,
                               fido: FIDOAuthenticator) throws {
        let master = try requireMaster()
        try Self.checkPassword(newPassword)
        guard newPassword != currentPassword else {
            throw SejfError.invalidInput("Nowe hasło musi różnić się od obecnego.")
        }
        guard let index = header.keyslots.firstIndex(where: { $0.id == slotID && $0.kind == .fido2 }),
              let credential = header.keyslots[index].credentialID, let salt = header.keyslots[index].challenge else {
            throw SejfError.invalidInput("Nie znaleziono klucza.")
        }
        let old = header.keyslots[index]
        let (_, output) = try fido.hmacSecret(rpID: Self.fidoRP, credentialIDs: [credential], salt: salt)
        let currentKEK = try fidoKEK(password: currentPassword, output: output, salt: old.salt,
                                     iterations: old.iterations ?? Self.defaultIterations)
        guard let opened = try? unwrap(old, kek: currentKEK), opened.rawData == master.rawData else {
            throw SejfError.invalidInput("Obecne hasło jest nieprawidłowe.")
        }
        header.keyslots[index] = try makeFIDOSlot(master: master, password: newPassword, fido: fido, credentialID: credential,
                                                  hmacSalt: salt, serial: old.serial, label: old.label, owner: old.owner,
                                                  iterations: Self.defaultIterations, output: output)
        if unlockedSlotID == old.id { unlockedSlotID = header.keyslots[index].id }
        try saveHeader()
    }

    public func regenerateRecoveryCode() throws -> String {
        let master = try requireMaster()
        let (slot, code) = try makeRecoverySlot(master: master)
        header.keyslots.removeAll { $0.kind == .recovery }
        header.keyslots.append(slot)
        try saveHeader()
        return code
    }

    public func removeSlot(id: String) throws {
        _ = try requireMaster()
        guard let slot = header.keyslots.first(where: { $0.id == id }) else { return }
        if slot.kind == .fido2 && fidoSlots.count <= 1 { throw SejfError.lastKey }
        header.keyslots.removeAll { $0.id == id }
        try saveHeader()
    }

    // MARK: - Wymiana klucza głównego

    /// Szyfruje wszystkie pliki nowym kluczem głównym. Zostaje tylko wskazany klucz FIDO2 (z podanym hasłem)
    /// i NOWE hasło odzyskiwania — stare klucze, hasła i kopie nagłówka przestają otwierać sejf.
    /// Operacja jest odporna na przerwanie (patrz `finishInterruptedRotation`). Zwraca nowe hasło odzyskiwania.
    public func rotateMasterKey(keepSlotID: String, password: String, fido: FIDOAuthenticator,
                                progress: ((Int, Int) -> Void)? = nil) throws -> String {
        let oldMaster = try requireMaster()
        try Self.checkPassword(password)
        guard let keep = fidoSlots.first(where: { $0.id == keepSlotID }), let credential = keep.credentialID else {
            throw SejfError.invalidInput("Nie znaleziono klucza.")
        }
        let fm = FileManager.default
        let newMaster = SymmetricKey(size: .bits256)
        var next = header
        next.keyslots = [
            try makeFIDOSlot(master: newMaster, password: password, fido: fido, credentialID: credential,
                             hmacSalt: try Rand.bytes(32), serial: keep.serial, label: keep.label, owner: keep.owner,
                             iterations: Self.defaultIterations),
        ]
        let (recovery, code) = try makeRecoverySlot(master: newMaster)
        next.keyslots.append(recovery)

        // 1. Wszystkie pliki od nowa do data.new (stary stan pozostaje kompletny).
        let newDir = root.appendingPathComponent(Self.newDataFolderName, isDirectory: true)
        try? fm.removeItem(at: newDir)
        try fm.createDirectory(at: newDir, withIntermediateDirectories: true)
        let blobs = try blobURLs()
        for (i, url) in blobs.enumerated() {
            progress?(i, blobs.count)
            let writer = try BlobWriter(dir: newDir, master: newMaster, vaultID: header.vaultID, chunkSize: header.chunkSize)
            do {
                try decryptBlob(url, master: oldMaster, metaOnly: false, onMeta: { meta in
                    try writer.seal(try JSONEncoder().encode(meta), last: false)
                }) { chunk, last in
                    try writer.seal(chunk, last: last)
                }
                _ = try writer.finish()
            } catch {
                writer.abort()
                try? fm.removeItem(at: newDir)
                throw error
            }
        }
        progress?(blobs.count, blobs.count)

        // 2. Przełączenie: zapis planu, zamiana katalogów, nowy nagłówek, sprzątanie.
        try Self.writeHeaderFile(next, to: root.appendingPathComponent(Self.nextHeaderName))
        let oldDir = root.appendingPathComponent(Self.oldDataFolderName, isDirectory: true)
        try fm.moveItem(at: dataDir, to: oldDir)
        try fm.moveItem(at: newDir, to: dataDir)
        header = next
        try saveHeader()
        try? fm.removeItem(at: oldDir)
        try? fm.removeItem(at: root.appendingPathComponent(Self.nextHeaderName))
        lock.withLock { masterKey = newMaster }
        unlockedSlotID = next.keyslots.first?.id
        return code
    }

    /// Dokończenie lub wycofanie wymiany klucza przerwanej np. odłączeniem pendrive'a.
    static func finishInterruptedRotation(in dir: URL) throws {
        let fm = FileManager.default
        let next = dir.appendingPathComponent(nextHeaderName)
        let data = dir.appendingPathComponent(dataFolderName)
        let new = dir.appendingPathComponent(newDataFolderName)
        let old = dir.appendingPathComponent(oldDataFolderName)
        let has = { (u: URL) in fm.fileExists(atPath: u.path) }

        if has(new) && !has(old) {
            // Przerwano przed przełączeniem — stary sejf jest kompletny, nowe dane są zbędne.
            try? fm.removeItem(at: new)
            try? fm.removeItem(at: next)
            return
        }
        if has(old) {
            guard has(next), let nextData = try? Data(contentsOf: next), let nextHeader = try? decodeHeader(nextData) else {
                if has(data) { try? fm.removeItem(at: old) } else { try fm.moveItem(at: old, to: data) }
                return
            }
            if !has(data) && has(new) { try fm.moveItem(at: new, to: data) }
            for name in [headerName, backupHeaderName] {
                try writeHeaderFile(nextHeader, to: dir.appendingPathComponent(name))
            }
            try? fm.removeItem(at: old)
            try? fm.removeItem(at: next)
            return
        }
        if has(next) { try? fm.removeItem(at: next) }   // przełączenie zakończone, został tylko plan
    }

    // MARK: - Keysloty

    private func makeFIDOSlot(master: SymmetricKey, password: String, fido: FIDOAuthenticator, credentialID: Data,
                              hmacSalt: Data, serial: Int?, label: String, owner: String? = nil, iterations: Int,
                              output known: Data? = nil) throws -> Keyslot {
        let output = try known ?? fido.hmacSecret(rpID: Self.fidoRP, credentialIDs: [credentialID], salt: hmacSalt).output
        guard output.count == 32 else { throw SejfError.yubikey("Nieoczekiwana długość odpowiedzi.") }
        var slot = Keyslot(id: UUID().uuidString, kind: .fido2, label: label,
                           created: Date().timeIntervalSince1970, serial: serial,
                           challenge: hmacSalt, salt: try Rand.bytes(32), iterations: iterations, wrappedKey: Data())
        slot.credentialID = credentialID
        slot.owner = owner
        slot.wrappedKey = try wrap(master, slot: slot,
                                   kek: fidoKEK(password: password, output: output, salt: slot.salt, iterations: iterations))
        return slot
    }

    private func fidoKEK(password: String, output: Data, salt: Data, iterations: Int) throws -> SymmetricKey {
        var ikm = try KDF.pbkdf2(password, salt: salt, iterations: iterations)
        ikm.append(output)
        defer { ikm.resetBytes(in: 0..<ikm.count) }
        return KDF.hkdf(ikm, salt: salt, info: Data("sejf-usb/v1/fido2-kek".utf8) + header.vaultID)
    }

    private func makeRecoverySlot(master: SymmetricKey) throws -> (Keyslot, String) {
        let (code, bytes) = try RecoveryCode.generate()
        let salt = try Rand.bytes(32)
        var slot = Keyslot(id: UUID().uuidString, kind: .recovery, label: "Hasło odzyskiwania",
                           created: Date().timeIntervalSince1970, serial: nil,
                           challenge: nil, salt: salt, iterations: nil, wrappedKey: Data())
        slot.wrappedKey = try wrap(master, slot: slot, kek: recoveryKEK(bytes, salt: salt))
        return (slot, code)
    }

    private func recoveryKEK(_ bytes: Data, salt: Data) -> SymmetricKey {
        KDF.hkdf(bytes, salt: salt, info: Data("sejf-usb/v1/recovery-kek".utf8) + header.vaultID)
    }

    /// AAD wiąże zaszyfrowany klucz z konkretnym sejfem i parametrami keyslota.
    private func slotAAD(_ slot: Keyslot) -> Data {
        var aad = Data("sejf-usb/v1/keyslot".utf8)
        aad += header.vaultID
        aad += Data(slot.id.utf8)
        aad += Data(slot.kind.rawValue.utf8)
        aad += slot.challenge ?? Data()
        aad += slot.salt
        aad += Data.be64(UInt64(slot.iterations ?? 0))
        aad += slot.credentialID ?? Data()
        return aad
    }

    private func wrap(_ master: SymmetricKey, slot: Keyslot, kek: SymmetricKey) throws -> Data {
        guard let combined = try AES.GCM.seal(master.rawData, using: kek, authenticating: slotAAD(slot)).combined
        else { throw SejfError.kdfFailed }
        return combined
    }

    private func unwrap(_ slot: Keyslot, kek: SymmetricKey) throws -> SymmetricKey {
        let box = try AES.GCM.SealedBox(combined: slot.wrappedKey)
        let raw = try AES.GCM.open(box, using: kek, authenticating: slotAAD(slot))
        guard raw.count == 32 else { throw SejfError.corrupt("klucz") }
        return SymmetricKey(data: raw)
    }

    private static func writeHeaderFile(_ header: VaultHeader, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(header).write(to: url, options: .atomic)
        if let handle = try? FileHandle(forUpdating: url) {
            try? handle.synchronize()
            try? handle.close()
        }
    }

    /// Dwie kopie nagłówka — uszkodzenie jednej nie odcina dostępu do danych.
    private func saveHeader() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for name in [Self.headerName, Self.backupHeaderName] {
            try Self.writeHeaderFile(header, to: root.appendingPathComponent(name))
        }
    }

    // MARK: - Format pliku

    /// Zapis jednego zaszyfrowanego pliku: nagłówek + fragmenty AES-GCM, numerowane od 0 (0 = metadane).
    private final class BlobWriter {
        let blobName: String
        private let key: SymmetricKey
        private let blobHeader: Data
        private let out: FileHandle
        private let tmpURL: URL
        private let finalURL: URL
        private var index: UInt64 = 0

        init(dir: URL, master: SymmetricKey, vaultID: Data, chunkSize: Int) throws {
            let fileID = try Rand.bytes(16)
            key = Vault.fileKey(master, fileID: fileID, vaultID: vaultID)
            blobHeader = Vault.magic + Data([1]) + fileID + Data.be32(UInt32(chunkSize))
            blobName = fileID.hex + "." + Vault.blobExtension
            finalURL = dir.appendingPathComponent(blobName)
            tmpURL = dir.appendingPathComponent(".tmp-" + blobName)
            guard FileManager.default.createFile(atPath: tmpURL.path, contents: nil, attributes: [.posixPermissions: 0o600]) else {
                throw SejfError.io("Nie można zapisać na nośniku (brak miejsca lub tylko do odczytu?).")
            }
            out = try FileHandle(forWritingTo: tmpURL)
            try out.write(contentsOf: blobHeader)
        }

        func seal(_ plain: Data, last: Bool) throws {
            let box = try AES.GCM.seal(plain, using: key, nonce: Vault.nonce(index),
                                       authenticating: Vault.chunkAAD(blobHeader, index: index, last: last))
            let sealed = box.ciphertext + box.tag
            try out.write(contentsOf: Data.be32(UInt32(sealed.count)) + sealed)
            index += 1
        }

        func finish() throws -> String {
            try out.synchronize()
            try out.close()
            try FileManager.default.moveItem(at: tmpURL, to: finalURL)
            return blobName
        }

        func abort() {
            try? out.close()
            try? FileManager.default.removeItem(at: tmpURL)
        }
    }

    fileprivate static func fileKey(_ master: SymmetricKey, fileID: Data, vaultID: Data) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(inputKeyMaterial: master, salt: fileID,
                               info: Data("sejf-usb/v1/file".utf8) + vaultID, outputByteCount: 32)
    }

    fileprivate static func nonce(_ index: UInt64) throws -> AES.GCM.Nonce {
        try AES.GCM.Nonce(data: Data(count: 4) + Data.be64(index))
    }

    fileprivate static func chunkAAD(_ blobHeader: Data, index: UInt64, last: Bool) -> Data {
        blobHeader + Data.be64(index) + Data([last ? 1 : 0])
    }

    // MARK: - Pliki

    /// Szyfruje plik do sejfu. Zwraca wpis i SHA-256 oryginału (do weryfikacji przed usunięciem źródła).
    @discardableResult
    public func encryptFile(at source: URL, relativePath: String,
                            progress: ((Int64) -> Void)? = nil) throws -> (FileEntry, Data) {
        let master = try requireMaster()
        let fm = FileManager.default
        let attrs = try fm.attributesOfItem(atPath: source.path)
        guard attrs[.type] as? FileAttributeType == .typeRegular else {
            throw SejfError.io("„\(source.lastPathComponent)” nie jest zwykłym plikiem.")
        }
        let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        let modified = (attrs[.modificationDate] as? Date) ?? Date()
        let added = Date()
        let chunkSize = header.chunkSize

        try fm.createDirectory(at: dataDir, withIntermediateDirectories: true)
        let writer = try BlobWriter(dir: dataDir, master: master, vaultID: header.vaultID, chunkSize: chunkSize)
        var finished = false
        defer { if !finished { writer.abort() } }

        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }

        let meta = FileMeta(path: relativePath, size: size, modified: modified.timeIntervalSince1970,
                            added: added.timeIntervalSince1970)
        try writer.seal(try JSONEncoder().encode(meta), last: false)

        var hasher = SHA256()
        var done: Int64 = 0
        var current = try input.read(upToCount: chunkSize) ?? Data()
        while true {
            let next = current.count == chunkSize ? (try input.read(upToCount: chunkSize) ?? Data()) : Data()
            let last = next.isEmpty
            hasher.update(data: current)
            try writer.seal(current, last: last)
            done += Int64(current.count)
            progress?(done)
            if last { break }
            current = next
        }
        let blobName = try writer.finish()
        finished = true
        let entry = FileEntry(id: blobName, path: relativePath, size: done, modified: modified, added: added)
        return (entry, Data(hasher.finalize()))
    }

    /// Strumieniowo deszyfruje blob; `sink` dostaje kolejne fragmenty (dopiero po ich uwierzytelnieniu).
    @discardableResult
    private func decryptBlob(_ url: URL, master: SymmetricKey, metaOnly: Bool,
                             onMeta: ((FileMeta) throws -> Void)? = nil,
                             sink: ((Data, Bool) throws -> Void)?) throws -> FileMeta {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let total = try handle.seekToEnd()
        try handle.seek(toOffset: 0)

        guard let blobHeader = try handle.read(upToCount: Self.blobHeaderSize),
              blobHeader.count == Self.blobHeaderSize,
              blobHeader.prefix(4) == Self.magic, blobHeader[blobHeader.startIndex + 4] == 1
        else { throw SejfError.corrupt(url.lastPathComponent) }
        let fileID = blobHeader.subdata(in: blobHeader.startIndex + 5 ..< blobHeader.startIndex + 21)
        let chunkSize = Int(blobHeader.readBE32(at: 21))
        guard chunkSize == header.chunkSize else { throw SejfError.corrupt("nieprawidłowy rozmiar fragmentu") }
        guard fileID.hex + "." + Self.blobExtension == url.lastPathComponent else {
            throw SejfError.corrupt("nazwa pliku nie zgadza się z zawartością")
        }
        let key = Self.fileKey(master, fileID: fileID, vaultID: header.vaultID)
        var offset = UInt64(Self.blobHeaderSize)

        func nextChunk(_ index: UInt64) throws -> (Data, Bool) {
            guard let lenData = try handle.read(upToCount: 4), lenData.count == 4 else {
                throw SejfError.corrupt("plik obcięty")
            }
            let length = Int(lenData.readBE32(at: 0))
            guard length >= 16, length <= (index == 0 ? Self.maxMetaSize : chunkSize + 16) else {
                throw SejfError.corrupt("długość fragmentu")
            }
            guard let sealed = try handle.read(upToCount: length), sealed.count == length else {
                throw SejfError.corrupt("plik obcięty")
            }
            offset += UInt64(4 + length)
            let last = offset == total
            let box = try AES.GCM.SealedBox(nonce: Self.nonce(index), ciphertext: sealed.dropLast(16), tag: sealed.suffix(16))
            do {
                let plain = try AES.GCM.open(box, using: key,
                                             authenticating: Self.chunkAAD(blobHeader, index: index, last: last))
                return (plain, last)
            } catch {
                throw SejfError.corrupt("dane zostały zmodyfikowane lub uszkodzone (\(url.lastPathComponent))")
            }
        }

        let (metaData, metaLast) = try nextChunk(0)
        guard !metaLast else { throw SejfError.corrupt("brak treści") }
        let meta = try JSONDecoder().decode(FileMeta.self, from: metaData)
        if metaOnly { return meta }
        try onMeta?(meta)

        var index: UInt64 = 1
        while true {
            let (plain, last) = try nextChunk(index)
            try sink?(plain, last)
            if last { break }
            index += 1
        }
        return meta
    }

    private func blobURLs() throws -> [URL] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: dataDir.path) else { return [] }
        return try fm.contentsOfDirectory(at: dataDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == Self.blobExtension && !$0.lastPathComponent.hasPrefix(".") }
    }

    public func listEntries() throws -> (entries: [FileEntry], unreadable: Int) {
        let master = try requireMaster()
        var entries: [FileEntry] = []
        var unreadable = 0
        for url in try blobURLs() {
            if let meta = try? decryptBlob(url, master: master, metaOnly: true, sink: nil) {
                entries.append(FileEntry(id: url.lastPathComponent, path: meta.path, size: meta.size,
                                         modified: Date(timeIntervalSince1970: meta.modified),
                                         added: Date(timeIntervalSince1970: meta.added)))
            } else {
                unreadable += 1
            }
        }
        entries.sort { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        return (entries, unreadable)
    }

    /// Odszyfrowuje wpis do folderu (uprawnienia 0600). Plik docelowy pojawia się dopiero po pełnej weryfikacji.
    @discardableResult
    public func decrypt(_ entry: FileEntry, into directory: URL, keepFolders: Bool = true,
                        progress: ((Int64) -> Void)? = nil) throws -> URL {
        let master = try requireMaster()
        let fm = FileManager.default
        let components = Self.safeComponents(entry.path)
        let relative = keepFolders ? components : [components.last ?? "plik"]
        var dest = directory
        for c in relative { dest.appendPathComponent(c) }
        try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true,
                               attributes: [.posixPermissions: 0o700])
        dest = Self.uniqueURL(dest)

        let tmp = dest.deletingLastPathComponent().appendingPathComponent(".sejf-tmp-" + UUID().uuidString)
        guard fm.createFile(atPath: tmp.path, contents: nil, attributes: [.posixPermissions: 0o600]) else {
            throw SejfError.io("Nie można zapisać w \(directory.path).")
        }
        var success = false
        defer { if !success { try? Shredder.shred(tmp) } }
        let out = try FileHandle(forWritingTo: tmp)
        var done: Int64 = 0
        do {
            try decryptBlob(dataDir.appendingPathComponent(entry.id), master: master, metaOnly: false) { chunk, _ in
                try out.write(contentsOf: chunk)
                done += Int64(chunk.count)
                progress?(done)
            }
            try out.synchronize()
            try out.close()
        } catch {
            try? out.close()
            throw error
        }
        try fm.moveItem(at: tmp, to: dest)
        try? fm.setAttributes([.modificationDate: entry.modified, .posixPermissions: 0o600], ofItemAtPath: dest.path)
        success = true
        return dest
    }

    /// Pełne odszyfrowanie "na sucho" i porównanie SHA-256 z oryginałem.
    public func verify(_ entry: FileEntry, sha256 expected: Data) throws -> Bool {
        let master = try requireMaster()
        var hasher = SHA256()
        try decryptBlob(dataDir.appendingPathComponent(entry.id), master: master, metaOnly: false) { chunk, _ in
            hasher.update(data: chunk)
        }
        return Data(hasher.finalize()) == expected
    }

    public func delete(_ entry: FileEntry) throws {
        _ = try requireMaster()
        try FileManager.default.removeItem(at: dataDir.appendingPathComponent(entry.id))
    }

    static func safeComponents(_ path: String) -> [String] {
        let parts = path.split(separator: "/").map(String.init)
            .filter { !$0.isEmpty && $0 != "." && $0 != ".." }
            .map { $0.replacingOccurrences(of: ":", with: "_") }
        return parts.isEmpty ? ["plik"] : parts
    }

    static func uniqueURL(_ url: URL) -> URL {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return url }
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let dir = url.deletingLastPathComponent()
        var n = 1
        while true {
            let name = ext.isEmpty ? "\(base) (\(n))" : "\(base) (\(n)).\(ext)"
            let candidate = dir.appendingPathComponent(name)
            if !fm.fileExists(atPath: candidate.path) { return candidate }
            n += 1
        }
    }

    // MARK: - Wybór plików

    /// Śmieci systemowe, których nie szyfrujemy (i które nie blokują usuwania pustych folderów).
    static let junkFiles: Set<String> = [".DS_Store", ".localized", "Icon\r"]
    static let junkDirectories: Set<String> = [".Spotlight-V100", ".fseventsd", ".Trashes", ".TemporaryItems",
                                               ".DocumentRevisions-V100", Vault.folderName]

    static func isJunk(_ name: String) -> Bool {
        junkFiles.contains(name) || name.hasPrefix("._") || junkDirectories.contains(name)
    }

    /// Rozwija wybrane elementy do listy plików ze ścieżkami względnymi do `base`.
    /// Obejmuje też pliki ukryte (np. `.env`) — pomija tylko śmieci systemowe. Dowiązań nie śledzi.
    public static func collectFiles(_ items: [URL], base: URL?) -> (files: [(url: URL, relative: String)], skipped: [String]) {
        let fm = FileManager.default
        var out: [(URL, String)] = []
        var skipped: [String] = []
        func relative(_ url: URL, _ base: URL) -> String {
            let b = base.standardizedFileURL.path
            let p = url.standardizedFileURL.path
            if p.hasPrefix(b + "/") { return String(p.dropFirst(b.count + 1)) }
            return url.lastPathComponent
        }
        func type(_ url: URL) -> FileAttributeType? {
            (try? fm.attributesOfItem(atPath: url.path))?[.type] as? FileAttributeType
        }
        for item in items where !isJunk(item.lastPathComponent) {
            let itemBase = base ?? item.deletingLastPathComponent()
            switch type(item) {
            case .typeRegular?:
                out.append((item, relative(item, itemBase)))
            case .typeDirectory?:
                guard let en = fm.enumerator(at: item, includingPropertiesForKeys: nil, options: []) else { continue }
                for case let url as URL in en {
                    if isJunk(url.lastPathComponent) {
                        if type(url) == .typeDirectory { en.skipDescendants() }
                        continue
                    }
                    switch type(url) {
                    case .typeRegular?: out.append((url, relative(url, itemBase)))
                    case .typeDirectory?: continue
                    default: skipped.append(relative(url, itemBase))   // dowiązania, urządzenia itp.
                    }
                }
            default:
                skipped.append(item.lastPathComponent)
            }
        }
        return (out, skipped)
    }
}
