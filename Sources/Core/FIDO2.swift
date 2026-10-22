import Foundation
import CryptoKit
import CommonCrypto
import IOKit.hid

/// Klucz sprzętowy FIDO2 z rozszerzeniem hmac-secret: tworzy poświadczenie i liczy
/// deterministyczny sekret HMAC dla podanej soli (wymaga dotknięcia klucza).
public protocol FIDOAuthenticator {
    func makeCredential(rpID: String) throws -> Data
    func hmacSecret(rpID: String, credentialIDs: [Data], salt: Data) throws -> (credentialID: Data, output: Data)
}

/// Wspólna blokada — klucz obsługuje naraz jedną operację (FIDO i wykrywanie przez CCID).
enum YubiKeyIO {
    static let lock = NSLock()
}

public struct CTAPError: LocalizedError {
    public let code: UInt8
    public var errorDescription: String? {
        switch code {
        case 0x2E: return "YubiKey: ten klucz nie jest zarejestrowany w tym sejfie."
        case 0x27: return "YubiKey: operacja odrzucona."
        case 0x2F, 0x3A: return "YubiKey: nie dotknięto klucza na czas — spróbuj ponownie."
        case 0x36, 0x35: return "YubiKey wymaga kodu PIN FIDO2 do tej operacji (nieobsługiwane)."
        case 0x31, 0x32, 0x34: return "YubiKey: kod PIN FIDO2 jest zablokowany lub nieprawidłowy."
        case 0x2D: return "YubiKey: anulowano."
        default: return "YubiKey: błąd FIDO2 (kod 0x\(String(code, radix: 16)))."
        }
    }
}

// MARK: - CTAPHID (USB HID, strona użycia 0xF1D0 — macOS nie wymaga tu żadnych zgód)

final class CTAPHIDDevice {
    private let device: IOHIDDevice
    private var cid: UInt32 = 0xFFFF_FFFF
    private var packets: [[UInt8]] = []
    private let inputBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
    private static let reportSize = 64

    private init(device: IOHIDDevice) { self.device = device }

    deinit {
        IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        inputBuffer.deallocate()
    }

    static func connectedCount() -> Int { matchingDevices().count }

    private static func matchingDevices() -> [IOHIDDevice] {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, [kIOHIDDeviceUsagePageKey: 0xF1D0, kIOHIDDeviceUsageKey: 0x01] as CFDictionary)
        let set = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> ?? []
        return set.filter { (IOHIDDeviceGetProperty($0, kIOHIDVendorIDKey as CFString) as? Int) == 0x1050 }   // Yubico
    }

    /// Otwiera pierwszy klucz FIDO; urządzenie jest obsługiwane na pętli bieżącego wątku.
    static func open() throws -> CTAPHIDDevice {
        let devices = matchingDevices()
        guard let raw = devices.first else { throw SejfError.yubikey("Włóż YubiKey.") }
        guard devices.count == 1 else { throw SejfError.yubikey("Podłączonych jest kilka kluczy — zostaw tylko jeden.") }
        guard IOHIDDeviceOpen(raw, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else {
            throw SejfError.yubikey("Nie można połączyć się z kluczem — wyjmij go i włóż ponownie.")
        }
        let dev = CTAPHIDDevice(device: raw)
        let context = Unmanaged.passUnretained(dev).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(raw, dev.inputBuffer, reportSize, { ctx, _, _, _, _, report, length in
            guard let ctx else { return }
            let me = Unmanaged<CTAPHIDDevice>.fromOpaque(ctx).takeUnretainedValue()
            me.packets.append(Array(UnsafeBufferPointer(start: report, count: min(length, 64))))
        }, context)
        IOHIDDeviceScheduleWithRunLoop(raw, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        try dev.initChannel()
        return dev
    }

    private func initChannel() throws {
        let nonce = [UInt8](try Rand.bytes(8))
        let response = try transact(cmd: 0x06, payload: Data(nonce), timeout: 3, onKeepalive: nil)
        guard response.count >= 12, [UInt8](response.prefix(8)) == nonce else {
            throw SejfError.yubikey("Nieprawidłowa odpowiedź klucza FIDO.")
        }
        cid = response[response.startIndex + 8 ..< response.startIndex + 12].reduce(0) { ($0 << 8) | UInt32($1) }
    }

    private func send(_ packet: [UInt8]) throws {
        var report = packet
        report += [UInt8](repeating: 0, count: Self.reportSize - report.count)
        let r = IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, 0, report, report.count)
        guard r == kIOReturnSuccess else { throw SejfError.yubikey("Nie można wysłać danych do klucza.") }
    }

    private func nextPacket(until deadline: Date) throws -> [UInt8] {
        while packets.isEmpty {
            guard Date() < deadline else { throw SejfError.yubikey("Klucz nie odpowiada — spróbuj ponownie.") }
            CFRunLoopRunInMode(.defaultMode, 0.05, true)
        }
        return packets.removeFirst()
    }

    /// Wysyła komendę CTAPHID (z podziałem na pakiety) i zwraca odpowiedź. KEEPALIVE (np. „czekam na dotyk”) przekazuje dalej.
    func transact(cmd: UInt8, payload: Data, timeout: TimeInterval, onKeepalive: ((UInt8) -> Void)?) throws -> Data {
        let cidBytes = withUnsafeBytes(of: cid.bigEndian, Array.init)
        let data = [UInt8](payload)
        var first = cidBytes + [cmd | 0x80, UInt8(data.count >> 8), UInt8(data.count & 0xFF)]
        first += data.prefix(57)
        packets.removeAll()
        try send(first)
        var offset = min(57, data.count)
        var seq: UInt8 = 0
        while offset < data.count {
            try send(cidBytes + [seq] + data[offset..<min(offset + 59, data.count)])
            offset += 59
            seq += 1
        }

        let deadline = Date().addingTimeInterval(timeout)
        while true {
            let p = try nextPacket(until: deadline)
            guard p.count >= 8, Array(p[0..<4]) == cidBytes else { continue }
            let rcmd = p[4] & 0x7F
            if rcmd == 0x3B {   // KEEPALIVE
                onKeepalive?(p[7])
                continue
            }
            if rcmd == 0x3F { throw CTAPError(code: p[7]) }   // ERROR
            guard rcmd == cmd & 0x7F else { continue }
            let total = Int(p[5]) << 8 | Int(p[6])
            guard total <= 7609 else { throw SejfError.yubikey("Nieprawidłowa odpowiedź klucza.") }   // limit CTAPHID
            var body = Array(p[7..<min(7 + total, p.count)])
            var expectSeq: UInt8 = 0
            while body.count < total {
                let c = try nextPacket(until: deadline)
                guard c.count >= 5, Array(c[0..<4]) == cidBytes, c[4] == expectSeq else { continue }
                body += c[5..<min(5 + total - body.count, c.count)]
                expectSeq += 1
            }
            return Data(body)
        }
    }

    /// Komenda CTAP2 przez CTAPHID_CBOR.
    func cbor(_ command: UInt8, _ params: CBOR?, timeout: TimeInterval = 40,
              onKeepalive: ((UInt8) -> Void)? = nil) throws -> CBOR? {
        var payload = Data([command])
        if let params { payload.append(params.encoded()) }
        let response = try transact(cmd: 0x10, payload: payload, timeout: timeout, onKeepalive: onKeepalive)
        guard let status = response.first else { throw SejfError.yubikey("Pusta odpowiedź klucza.") }
        guard status == 0 else { throw CTAPError(code: status) }
        guard response.count > 1 else { return nil }
        return try CBOR.decode(response, at: 1).0
    }
}

// MARK: - CTAP2: makeCredential + getAssertion z hmac-secret (PIN/UV protocol 1)

public struct YubiKeyFIDO: FIDOAuthenticator, Sendable {
    /// Wywoływane, gdy klucz czeka na dotknięcie (miga).
    public var onTouchNeeded: (@Sendable () -> Void)?

    public init(onTouchNeeded: (@Sendable () -> Void)? = nil) { self.onTouchNeeded = onTouchNeeded }

    public static var isConnected: Bool { CTAPHIDDevice.connectedCount() > 0 }

    private func withDevice<T>(_ body: (CTAPHIDDevice) throws -> T) throws -> T {
        try YubiKeyIO.lock.withLock {
            let device = try CTAPHIDDevice.open()
            return try body(device)
        }
    }

    private var keepalive: (UInt8) -> Void {
        { status in if status == 2 { onTouchNeeded?() } }   // 2 = UPNEEDED
    }

    public func makeCredential(rpID: String) throws -> Data {
        try withDevice { dev in
            let params: CBOR = .map([
                1: .bytes(try Rand.bytes(32)),                                         // clientDataHash
                2: .map(["id": .text(rpID), "name": "Sejf USB"]),
                3: .map(["id": .bytes(try Rand.bytes(16)), "name": "sejf", "displayName": "Sejf USB"]),
                4: .array([.map(["alg": -7, "type": "public-key"])]),
                6: .map(["hmac-secret": true]),
                7: .map(["rk": false]),
            ])
            guard let response = try dev.cbor(0x01, params, onKeepalive: keepalive),
                  let authData = response[2]?.data, authData.count > 55 else {
                throw SejfError.yubikey("Nieprawidłowa odpowiedź przy tworzeniu poświadczenia.")
            }
            // authData: rpIdHash(32) flags(1) signCount(4) aaguid(16) credIdLen(2) credId(L) ...
            let b = [UInt8](authData)
            guard b[32] & 0x40 != 0 else { throw SejfError.yubikey("Brak danych poświadczenia.") }
            let length = Int(b[53]) << 8 | Int(b[54])
            guard length > 0, 55 + length <= b.count else { throw SejfError.yubikey("Nieprawidłowe poświadczenie.") }
            return Data(b[55..<55 + length])
        }
    }

    public func hmacSecret(rpID: String, credentialIDs: [Data], salt: Data) throws -> (credentialID: Data, output: Data) {
        guard salt.count == 32, !credentialIDs.isEmpty else { throw SejfError.invalidInput("Nieprawidłowe parametry hmac-secret.") }
        return try withDevice { dev in
            // 1. Uzgodnienie klucza (ECDH P-256) z kluczem sprzętowym.
            guard let ka = try dev.cbor(0x06, .map([1: 1, 2: 2]), timeout: 5),
                  let cose = ka[1], let x = cose[-2]?.data, let y = cose[-3]?.data, x.count == 32, y.count == 32 else {
                throw SejfError.yubikey("Nie udało się uzgodnić klucza z YubiKey.")
            }
            let peer = try P256.KeyAgreement.PublicKey(x963Representation: Data([0x04]) + x + y)
            let mine = P256.KeyAgreement.PrivateKey()
            let z = try mine.sharedSecretFromKeyAgreement(with: peer).withUnsafeBytes { Data($0) }
            let shared = Data(SHA256.hash(data: z))
            let myPoint = mine.publicKey.x963Representation.dropFirst()

            // 2. Sól zaszyfrowana wspólnym sekretem + jej uwierzytelnienie.
            let saltEnc = try Self.aesCBC(encrypt: true, key: shared, data: salt)
            let saltAuth = Data(HMAC<SHA256>.authenticationCode(for: saltEnc, using: SymmetricKey(data: shared))).prefix(16)
            let myCOSE: CBOR = .map([1: 2, 3: -25, -1: 1,
                                     -2: .bytes(Data(myPoint.prefix(32))), -3: .bytes(Data(myPoint.suffix(32)))])
            let params: CBOR = .map([
                1: .text(rpID),
                2: .bytes(try Rand.bytes(32)),
                3: .array(credentialIDs.map { .map(["id": .bytes($0), "type": "public-key"]) }),
                4: .map(["hmac-secret": .map([1: myCOSE, 2: .bytes(saltEnc), 3: .bytes(Data(saltAuth))])]),
                5: .map(["up": true]),
            ])

            // 3. getAssertion — tu klucz czeka na dotknięcie.
            guard let response = try dev.cbor(0x02, params, onKeepalive: keepalive),
                  let authData = response[2]?.data, authData.count > 37 else {
                throw SejfError.yubikey("Nieprawidłowa odpowiedź klucza.")
            }
            let credential = response[1]?["id"]?.data ?? (credentialIDs.count == 1 ? credentialIDs[0] : nil)
            guard let credential else { throw SejfError.yubikey("Klucz nie wskazał poświadczenia.") }
            guard authData[authData.startIndex + 32] & 0x80 != 0 else { throw SejfError.yubikey("Klucz nie zwrócił hmac-secret.") }
            let (ext, _) = try CBOR.decode(authData, at: 37)
            guard let enc = ext["hmac-secret"]?.data, enc.count == 32 else {
                throw SejfError.yubikey("Klucz nie zwrócił hmac-secret.")
            }
            return (credential, try Self.aesCBC(encrypt: false, key: shared, data: enc))
        }
    }

    /// AES-256-CBC z zerowym IV, bez dopełnienia (PIN/UV protocol 1).
    static func aesCBC(encrypt: Bool, key: Data, data: Data) throws -> Data {
        var out = Data(count: data.count + kCCBlockSizeAES128)
        var moved = 0
        let iv = Data(count: kCCBlockSizeAES128)
        let outCapacity = out.count
        let status = out.withUnsafeMutableBytes { o in
            data.withUnsafeBytes { d in
                key.withUnsafeBytes { k in
                    iv.withUnsafeBytes { v in
                        CCCrypt(CCOperation(encrypt ? kCCEncrypt : kCCDecrypt), CCAlgorithm(kCCAlgorithmAES), 0,
                                k.baseAddress, key.count, v.baseAddress, d.baseAddress, data.count,
                                o.baseAddress, outCapacity, &moved)
                    }
                }
            }
        }
        guard status == kCCSuccess else { throw SejfError.kdfFailed }
        return out.prefix(moved)
    }
}
