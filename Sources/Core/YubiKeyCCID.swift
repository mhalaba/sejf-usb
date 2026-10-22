import Foundation
import CryptoTokenKit

public struct YubiKeyDevice: Hashable, Sendable {
    public let name: String
    public let serial: Int?
}

/// Wykrywanie podłączonych YubiKeyów (model, numer seryjny) przez interfejs karty inteligentnej (CCID).
/// Nie wymaga żadnych zgód systemowych ani ykman. Sama kryptografia sejfu idzie przez FIDO2 (FIDO2.swift).
public enum YubiKeyCCID {
    static let otpAID = Data([0xA0, 0x00, 0x00, 0x05, 0x27, 0x20, 0x01])

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
