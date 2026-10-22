import Foundation

/// Minimalny CBOR (RFC 8949) potrzebny do CTAP2: liczby, bajty, tekst, tablice, mapy, bool.
/// Kodowanie kanoniczne CTAP2: klucze map posortowane po (długość zakodowania, bajty).
public indirect enum CBOR: Hashable {
    case unsigned(UInt64)
    case negative(Int64)          // przechowuje wartość ujemną, np. -7
    case bytes(Data)
    case text(String)
    case array([CBOR])
    case map([CBOR: CBOR])
    case bool(Bool)
    case null

    public static func int(_ v: Int) -> CBOR { v >= 0 ? .unsigned(UInt64(v)) : .negative(Int64(v)) }

    // MARK: - Dostęp

    public subscript(_ key: CBOR) -> CBOR? {
        if case .map(let m) = self { return m[key] }
        return nil
    }
    public subscript(_ key: Int) -> CBOR? { self[.int(key)] }
    public subscript(_ key: String) -> CBOR? { self[.text(key)] }

    public var data: Data? { if case .bytes(let d) = self { return d }; return nil }
    public var string: String? { if case .text(let s) = self { return s }; return nil }
    public var intValue: Int? {
        switch self {
        case .unsigned(let u): return Int(exactly: u)
        case .negative(let n): return Int(n)
        default: return nil
        }
    }

    // MARK: - Kodowanie

    public func encoded() -> Data {
        var out = Data()
        encode(into: &out)
        return out
    }

    private static func head(_ major: UInt8, _ value: UInt64, into out: inout Data) {
        let m = major << 5
        switch value {
        case 0..<24: out.append(m | UInt8(value))
        case 24...0xFF: out.append(m | 24); out.append(UInt8(value))
        case 0x100...0xFFFF: out.append(m | 25); out.append(contentsOf: withUnsafeBytes(of: UInt16(value).bigEndian, Array.init))
        case 0x10000...0xFFFF_FFFF: out.append(m | 26); out.append(contentsOf: withUnsafeBytes(of: UInt32(value).bigEndian, Array.init))
        default: out.append(m | 27); out.append(contentsOf: withUnsafeBytes(of: value.bigEndian, Array.init))
        }
    }

    private func encode(into out: inout Data) {
        switch self {
        case .unsigned(let u): Self.head(0, u, into: &out)
        case .negative(let n): Self.head(1, UInt64(-1 - n), into: &out)
        case .bytes(let d): Self.head(2, UInt64(d.count), into: &out); out.append(d)
        case .text(let s): let d = Data(s.utf8); Self.head(3, UInt64(d.count), into: &out); out.append(d)
        case .array(let a): Self.head(4, UInt64(a.count), into: &out); for e in a { e.encode(into: &out) }
        case .map(let m):
            Self.head(5, UInt64(m.count), into: &out)
            let entries = m.map { (key: $0.key.encoded(), value: $0.value) }
                .sorted { a, b in a.key.count != b.key.count ? a.key.count < b.key.count : a.key.lexicographicallyPrecedes(b.key) }
            for e in entries { out.append(e.key); e.value.encode(into: &out) }
        case .bool(let b): out.append(b ? 0xF5 : 0xF4)
        case .null: out.append(0xF6)
        }
    }

    // MARK: - Dekodowanie

    public struct DecodeError: Error {}

    /// Dekoduje jeden element od `offset`; zwraca element i liczbę zużytych bajtów.
    public static func decode(_ data: Data, at offset: Int = 0) throws -> (CBOR, Int) {
        let bytes = [UInt8](data)
        var i = offset
        let value = try decodeItem(bytes, &i, depth: 0)
        return (value, i - offset)
    }

    private static func decodeItem(_ b: [UInt8], _ i: inout Int, depth: Int) throws -> CBOR {
        guard depth < 16, i < b.count else { throw DecodeError() }
        let initial = b[i]; i += 1
        let major = initial >> 5
        let info = initial & 0x1F

        func readArg() throws -> UInt64 {
            switch info {
            case 0..<24: return UInt64(info)
            case 24...27:
                let n = 1 << Int(info - 24)
                guard i + n <= b.count else { throw DecodeError() }
                let v = b[i..<i + n].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
                i += n
                return v
            default: throw DecodeError()
            }
        }

        switch major {
        case 0: return .unsigned(try readArg())
        case 1:
            let a = try readArg()
            guard a < UInt64(Int64.max) else { throw DecodeError() }
            return .negative(-1 - Int64(a))
        case 2, 3:
            guard let n = Int(exactly: try readArg()), n <= b.count - i else { throw DecodeError() }
            let d = Data(b[i..<i + n]); i += n
            if major == 2 { return .bytes(d) }
            guard let s = String(data: d, encoding: .utf8) else { throw DecodeError() }
            return .text(s)
        case 4:
            guard let n = Int(exactly: try readArg()), n <= b.count - i else { throw DecodeError() }
            var arr: [CBOR] = []
            for _ in 0..<n { arr.append(try decodeItem(b, &i, depth: depth + 1)) }
            return .array(arr)
        case 5:
            guard let n = Int(exactly: try readArg()), n <= (b.count - i) / 2 else { throw DecodeError() }
            var m: [CBOR: CBOR] = [:]
            for _ in 0..<n {
                let k = try decodeItem(b, &i, depth: depth + 1)
                m[k] = try decodeItem(b, &i, depth: depth + 1)
            }
            return .map(m)
        case 7:
            switch info {
            case 20: return .bool(false)
            case 21: return .bool(true)
            case 22, 23: return .null
            default: throw DecodeError()
            }
        default:
            throw DecodeError()
        }
    }
}

extension CBOR: ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByBooleanLiteral {
    public init(stringLiteral value: String) { self = .text(value) }
    public init(integerLiteral value: Int) { self = .int(value) }
    public init(booleanLiteral value: Bool) { self = .bool(value) }
}
