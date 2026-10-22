import Foundation
import CryptoKit

/// Samotesty przy uruchomieniu — wzorowane na wymaganiach FIPS 140-3 (power-up self-tests):
/// testy znanych odpowiedzi (KAT) dla każdego algorytmu, test spójności par kluczy ECDH
/// i podstawowy test generatora liczb losowych. Gdy którykolwiek zawiedzie, aplikacja odmawia pracy.
///
/// Wektory pochodzą z norm (FIPS 180-4, RFC 4231, RFC 5869, RFC 7914, FIPS 197, test GCM McGrew–Viega #14)
/// i zostały niezależnie sprawdzone narzędziem OpenSSL.
public enum SelfTest {
    public struct Failure: LocalizedError {
        public let test: String
        public var errorDescription: String? {
            "Samotest kryptograficzny „\(test)” nie powiódł się. Aplikacja nie będzie przetwarzać danych — zgłoś problem."
        }
    }

    /// Wynik wszystkich testów: lista nazw zaliczonych testów albo błąd pierwszego niezaliczonego.
    @discardableResult
    public static func run() throws -> [String] {
        var passed: [String] = []
        func expect(_ name: String, _ ok: Bool) throws {
            guard ok else { throw Failure(test: name) }
            passed.append(name)
        }
        func hex(_ s: String) -> Data { Data(hex: s)! }

        // SHA-256 (FIPS 180-4)
        try expect("SHA-256", Data(SHA256.hash(data: Data("abc".utf8)))
                    == hex("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"))

        // HMAC-SHA-256 (FIPS 198-1, RFC 4231 przypadek 1)
        try expect("HMAC-SHA-256", Data(HMAC<SHA256>.authenticationCode(for: Data("Hi There".utf8),
                                                                        using: SymmetricKey(data: Data(repeating: 0x0B, count: 20))))
                    == hex("b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7"))

        // HKDF-SHA-256 (SP 800-56C, RFC 5869 przypadek 1)
        let okm = HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: Data(repeating: 0x0B, count: 22)),
                                         salt: hex("000102030405060708090a0b0c"), info: hex("f0f1f2f3f4f5f6f7f8f9"),
                                         outputByteCount: 42)
        try expect("HKDF-SHA-256", okm.rawData
                    == hex("3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865"))

        // PBKDF2-HMAC-SHA-256 (SP 800-132, RFC 7914)
        try expect("PBKDF2-HMAC-SHA-256", try KDF.pbkdf2("passwd", salt: Data("salt".utf8), iterations: 1)
                    == hex("55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc"))

        // AES-256 (FIPS 197, dodatek C.3) — przez tryb CBC z zerowym IV (jak w protokole PIN CTAP)
        try expect("AES-256", try YubiKeyFIDO.aesCBC(encrypt: true, key: hex("000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"),
                                                      data: hex("00112233445566778899aabbccddeeff"))
                    == hex("8ea2b7ca516745bfeafc49904b496089"))

        // AES-256-GCM (SP 800-38D) — szyfrowanie i odszyfrowanie znanej odpowiedzi
        let gcmKey = SymmetricKey(data: Data(count: 32))
        let gcmNonce = try AES.GCM.Nonce(data: Data(count: 12))
        let box = try AES.GCM.seal(Data(count: 16), using: gcmKey, nonce: gcmNonce)
        try expect("AES-256-GCM (szyfrowanie)", box.ciphertext == hex("cea7403d4d606b6e074ec5d3baf39d18")
                    && box.tag == hex("d0d1c8a799996bf0265b98b5d48ab919"))
        try expect("AES-256-GCM (odszyfrowanie)", try AES.GCM.open(box, using: gcmKey) == Data(count: 16))
        var tampered = box.ciphertext; tampered[tampered.startIndex] ^= 1
        try expect("AES-256-GCM (wykrycie zmiany)",
                   (try? AES.GCM.open(AES.GCM.SealedBox(nonce: gcmNonce, ciphertext: tampered, tag: box.tag), using: gcmKey)) == nil)

        // ECDH P-256 (SP 800-56A) — test spójności par kluczy
        let a = P256.KeyAgreement.PrivateKey(), b = P256.KeyAgreement.PrivateKey()
        let ab = try a.sharedSecretFromKeyAgreement(with: b.publicKey).withUnsafeBytes { Data($0) }
        let ba = try b.sharedSecretFromKeyAgreement(with: a.publicKey).withUnsafeBytes { Data($0) }
        try expect("ECDH P-256", ab == ba && ab.count == 32)

        // Generator liczb losowych (SP 800-90A w corecrypto) — kolejne bloki różne i niezerowe
        let r1 = try Rand.bytes(32), r2 = try Rand.bytes(32)
        try expect("Generator losowy", r1 != r2 && r1 != Data(count: 32) && r2 != Data(count: 32))

        return passed
    }
}
