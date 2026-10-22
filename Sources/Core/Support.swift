import Foundation
import CryptoKit
import CommonCrypto
import Security

public enum SejfError: LocalizedError {
    case locked
    case randomFailed
    case kdfFailed
    case badCredentials
    case corrupt(String)
    case io(String)
    case yubikey(String)
    case invalidInput(String)
    case lastKey
    case inICloud

    public var errorDescription: String? {
        switch self {
        case .locked: return L("Sejf jest zablokowany.")
        case .randomFailed: return L("Nie udało się wygenerować losowych danych.")
        case .kdfFailed: return L("Błąd wyprowadzania klucza.")
        case .badCredentials: return L("Nieprawidłowe hasło lub YubiKey.")
        case .corrupt(let m): return L("Uszkodzone dane: %@", m)
        case .io(let m): return m
        case .yubikey(let m): return L("YubiKey: %@", m)
        case .invalidInput(let m): return m
        case .lastKey: return L("Nie można usunąć ostatniego klucza YubiKey.")
        case .inICloud: return L("Ten folder jest synchronizowany z iCloud — jawne pliki trafiłyby na serwery Apple. Wybierz folder poza Pulpitem, Dokumentami i iCloud Drive (np. ~/Sejf).")
        }
    }
}

enum Rand {
    static func bytes(_ count: Int) throws -> Data {
        var data = Data(count: count)
        let status = data.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!) }
        guard status == errSecSuccess else { throw SejfError.randomFailed }
        return data
    }
}

enum KDF {
    /// PBKDF2-HMAC-SHA256 z hasła znormalizowanego do NFC (żeby "ą" wpisane różnie dawało ten sam klucz).
    static func pbkdf2(_ password: String, salt: Data, iterations: Int) throws -> Data {
        let normalized = password.precomposedStringWithCanonicalMapping
        let passwordLength = normalized.utf8.count
        var out = [UInt8](repeating: 0, count: 32)
        let status = salt.withUnsafeBytes { saltBytes in
            CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                normalized, passwordLength,
                saltBytes.bindMemory(to: UInt8.self).baseAddress, salt.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                UInt32(iterations),
                &out, out.count)
        }
        guard status == kCCSuccess else { throw SejfError.kdfFailed }
        defer { out.resetBytes(in: 0..<out.count) }
        return Data(out)
    }

    static func hkdf(_ ikm: Data, salt: Data, info: Data) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: ikm), salt: salt, info: info, outputByteCount: 32)
    }
}

extension SymmetricKey {
    var rawData: Data { withUnsafeBytes { Data($0) } }
}

extension Data {
    var hex: String { map { String(format: "%02x", $0) }.joined() }

    init?(hex: String) {
        let chars = Array(hex.trimmingCharacters(in: .whitespacesAndNewlines))
        guard chars.count % 2 == 0 else { return nil }
        var data = Data(capacity: chars.count / 2)
        var i = 0
        while i < chars.count {
            guard let byte = UInt8(String(chars[i...i + 1]), radix: 16) else { return nil }
            data.append(byte)
            i += 2
        }
        self = data
    }

    static func be64(_ value: UInt64) -> Data { Swift.withUnsafeBytes(of: value.bigEndian) { Data($0) } }
    static func be32(_ value: UInt32) -> Data { Swift.withUnsafeBytes(of: value.bigEndian) { Data($0) } }

    func readBE32(at offset: Int) -> UInt32 {
        self[startIndex + offset ..< startIndex + offset + 4].reduce(0) { ($0 << 8) | UInt32($1) }
    }
}

extension Array where Element == UInt8 {
    mutating func resetBytes(in range: Range<Int>) {
        for i in range { self[i] = 0 }
    }
}

/// Kod odzyskiwania: 160 losowych bitów w Base32 Crockforda (bez mylących znaków), grupy po 4.
public enum RecoveryCode {
    static let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")

    static func generate() throws -> (code: String, bytes: Data) {
        let bytes = try Rand.bytes(20)
        return (encode(bytes), bytes)
    }

    static func encode(_ data: Data) -> String {
        var chars: [Character] = []
        var buffer = 0, bits = 0
        for byte in data {
            buffer = (buffer << 8) | Int(byte)
            bits += 8
            while bits >= 5 {
                chars.append(alphabet[(buffer >> (bits - 5)) & 31])
                bits -= 5
            }
        }
        if bits > 0 { chars.append(alphabet[(buffer << (5 - bits)) & 31]) }
        return stride(from: 0, to: chars.count, by: 4)
            .map { String(chars[$0 ..< Swift.min($0 + 4, chars.count)]) }
            .joined(separator: "-")
    }

    static func decode(_ code: String) -> Data? {
        var buffer = 0, bits = 0
        var out = Data()
        for ch in code.uppercased() {
            if ch == "-" || ch == " " { continue }
            let c: Character = ch == "O" ? "0" : (ch == "I" || ch == "L") ? "1" : ch
            guard let value = alphabet.firstIndex(of: c) else { return nil }
            buffer = (buffer << 5) | value
            bits += 5
            if bits >= 8 {
                out.append(UInt8((buffer >> (bits - 8)) & 0xFF))
                bits -= 8
            }
        }
        return out.count == 20 ? out : nil
    }
}

/// Bezpieczne usuwanie. Na pamięci flash i dyskach SSD/APFS (migawki, kopiowanie przy zapisie)
/// nadpisanie nie daje 100% gwarancji — dlatego najważniejsze jest, by jawne pliki w ogóle nie leżały na dysku.
public enum Shredder {
    /// Nadpisuje i usuwa JEDEN plik. Nie podąża za dowiązaniami symbolicznymi (usuwa tylko samo dowiązanie)
    /// i nie nadpisuje plików z kilkoma dowiązaniami twardymi (zmieniłoby to zawartość „innego” pliku).
    public static func shred(_ url: URL) throws {
        let fm = FileManager.default
        let attrs = try fm.attributesOfItem(atPath: url.path)          // lstat — bez podążania za dowiązaniem
        let type = attrs[.type] as? FileAttributeType
        if type == .typeSymbolicLink {
            try fm.removeItem(at: url)
            return
        }
        guard type == .typeRegular else { throw SejfError.io(L("„%@” nie jest zwykłym plikiem.", url.lastPathComponent)) }
        let links = (attrs[.referenceCount] as? NSNumber)?.intValue ?? 1
        let size = (attrs[.size] as? NSNumber)?.intValue ?? 0
        if links == 1, size > 0 {
            let handle = try FileHandle(forWritingTo: url)
            var remaining = size
            let block = 1 << 20
            while remaining > 0 {
                let n = Swift.min(block, remaining)
                try handle.write(contentsOf: try Rand.bytes(n))
                remaining -= n
            }
            try handle.synchronize()
            try handle.close()
        }
        try fm.removeItem(at: url)
    }

    /// Niszczy katalog utworzony przez aplikację (np. podgląd). Dowiązań nie śledzi.
    public static func shredTree(_ dir: URL) throws {
        let fm = FileManager.default
        guard let attrs = try? fm.attributesOfItem(atPath: dir.path) else { return }
        guard attrs[.type] as? FileAttributeType == .typeDirectory else { return try shred(dir) }
        for child in try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            let type = (try? fm.attributesOfItem(atPath: child.path))?[.type] as? FileAttributeType
            if type == .typeDirectory { try shredTree(child) } else { try shred(child) }
        }
        try fm.removeItem(at: dir)
    }

    /// Usuwa od dołu katalogi, w których naprawdę nic nie zostało (poza śmieciem Findera `.DS_Store`).
    /// Katalogu z jakimkolwiek innym plikiem — także ukrytym — nie rusza. Zwraca true, jeśli `dir` usunięto.
    @discardableResult
    public static func removeEmptyDirectories(_ dir: URL) -> Bool {
        let fm = FileManager.default
        guard (try? fm.attributesOfItem(atPath: dir.path))?[.type] as? FileAttributeType == .typeDirectory,
              let children = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return false }
        for child in children where (try? fm.attributesOfItem(atPath: child.path))?[.type] as? FileAttributeType == .typeDirectory {
            removeEmptyDirectories(child)
        }
        guard let remaining = try? fm.contentsOfDirectory(atPath: dir.path),
              remaining.allSatisfy({ $0 == ".DS_Store" }) else { return false }
        for junk in remaining { try? fm.removeItem(at: dir.appendingPathComponent(junk)) }
        return (try? fm.removeItem(at: dir)) != nil
    }
}

/// Wykrywanie folderów synchronizowanych z iCloud Drive (w tym Pulpitu i Dokumentów).
public enum CloudCheck {
    public static func isInICloud(_ url: URL) -> Bool {
        var u = url.standardizedFileURL.resolvingSymlinksInPath()
        if u.path.contains("/Library/Mobile Documents/") { return true }
        while u.path != "/" && !u.path.isEmpty {
            if (try? u.resourceValues(forKeys: [.isUbiquitousItemKey]))?.isUbiquitousItem == true { return true }
            u.deleteLastPathComponent()
        }
        return false
    }
}
