import Foundation
import CryptoTokenKit

/// Podłączony klucz sprzętowy widziany przez aplikację.
public struct YubiKeyDevice: Hashable, Sendable {
    public let name: String
    /// Numer seryjny — tylko YubiKey z interfejsem CCID (np. seria 5); Security Key go nie udostępnia.
    public let serial: Int?
    public var supportsHMACSecret: Bool = true
    public var requiresPINForRegistration: Bool = false

    public init(name: String, serial: Int?, supportsHMACSecret: Bool = true, requiresPINForRegistration: Bool = false) {
        self.name = name
        self.serial = serial
        self.supportsHMACSecret = supportsHMACSecret
        self.requiresPINForRegistration = requiresPINForRegistration
    }
}

/// Wykrywanie kluczy: przez FIDO2 (każdy klucz FIDO2, także Security Key NFC bez interfejsu CCID),
/// uzupełnione o model i numer seryjny z CCID, gdy klucz go udostępnia (YubiKey 5).
public enum KeyScanner {
    private static var infoCache: [UInt64: FIDOInfo] = [:]

    public static func scan() -> [YubiKeyDevice] {
        YubiKeyIO.lock.withLock {
            let fido = CTAPHIDDevice.matchingDevices()
            let ccid = YubiKeyCCID.scanUnlocked()
            let yubicoFIDO = fido.filter { CTAPHIDDevice.vendorID($0) == 0x1050 }
            var alive = Set<UInt64>()
            let devices = fido.map { raw -> YubiKeyDevice in
                let id = CTAPHIDDevice.registryID(raw)
                alive.insert(id)
                if infoCache[id] == nil, let dev = try? CTAPHIDDevice.open(raw), let info = try? dev.getInfo() {
                    infoCache[id] = info
                }
                let info = infoCache[id]
                // Model i numer seryjny z CCID tylko wtedy, gdy przypisanie jest jednoznaczne.
                let enriched = (yubicoFIDO.count == 1 && ccid.count == 1 && CTAPHIDDevice.vendorID(raw) == 0x1050) ? ccid.first : nil
                let product = CTAPHIDDevice.product(raw)
                let name = enriched?.name ?? (product == "YubiKey FIDO" ? "YubiKey / Security Key (FIDO2)" : product)
                return YubiKeyDevice(name: name, serial: enriched?.serial,
                                     supportsHMACSecret: info?.supportsHMACSecret ?? false,
                                     requiresPINForRegistration: info?.requiresPINForRegistration ?? false)
            }
            infoCache = infoCache.filter { alive.contains($0.key) }
            return devices
        }
    }
}

/// Model i numer seryjny YubiKeya przez interfejs karty inteligentnej (CCID) — tylko klucze, które go mają.
public enum YubiKeyCCID {
    static let otpAID = Data([0xA0, 0x00, 0x00, 0x05, 0x27, 0x20, 0x01])

    static func scanUnlocked() -> [YubiKeyDevice] {
        readerNames().compactMap { try? device(reader: $0) }
    }

    public static func scan() -> [YubiKeyDevice] {
        YubiKeyIO.lock.withLock {
            readerNames().compactMap { try? device(reader: $0) }
        }
    }

    private static func readerNames() -> [String] {
        (TKSmartCardSlotManager.default?.slotNames ?? []).filter { $0.localizedCaseInsensitiveContains("yubikey") }
    }

    private static func device(reader: String) throws -> YubiKeyDevice {
        guard let slot = TKSmartCardSlotManager.default?.slotNamed(reader), slot.state == .validCard,
              let card = slot.makeSmartCard() else {
            throw SejfError.yubikey("Czytnik klucza jest niedostępny.")
        }
        guard try card.beginSessionSync() else { throw SejfError.yubikey("Klucz jest zajęty.") }
        defer { card.endSession() }
        let (sw, status) = try card.send(ins: 0xA4, p1: 0x04, p2: 0x00, data: otpAID, le: 0)
        guard sw == 0x9000, status.count >= 3 else { throw SejfError.yubikey("Brak aplikacji OTP.") }
        let v = [UInt8](status.prefix(3))
        var serial: Int?
        if let (ssw, s) = try? card.send(ins: 0x01, p1: 0x10, p2: 0, data: nil, le: 0), ssw == 0x9000, s.count == 4 {
            serial = s.reduce(0) { ($0 << 8) | Int($1) }
        }
        let model = v[0] >= 5 ? "YubiKey 5" : "YubiKey"
        return YubiKeyDevice(name: "\(model) (\(v[0]).\(v[1]).\(v[2]))", serial: serial)
    }
}

extension TKSmartCard {
    /// Synchroniczne otwarcie sesji (wywoływane poza głównym wątkiem).
    func beginSessionSync(timeout: TimeInterval = 5) throws -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var ok = false
        var failure: Error?
        beginSession { success, error in
            ok = success
            failure = error
            semaphore.signal()
        }
        guard semaphore.wait(timeout: .now() + timeout) == .success else { return false }
        if let failure { throw failure }
        return ok
    }
}
