import SwiftUI

enum Theme {
    static let bgTop = Color(red: 0.06, green: 0.07, blue: 0.13)
    static let bgBottom = Color(red: 0.09, green: 0.07, blue: 0.20)
    static let accent = Color(red: 0.45, green: 0.55, blue: 1.0)
    static let accent2 = Color(red: 0.62, green: 0.40, blue: 1.0)
    static let good = Color(red: 0.30, green: 0.85, blue: 0.55)
    static let warn = Color(red: 1.0, green: 0.72, blue: 0.30)
    static let bad = Color(red: 1.0, green: 0.42, blue: 0.42)
    static let card = Color.white.opacity(0.05)
    static let stroke = Color.white.opacity(0.09)
    static let muted = Color.white.opacity(0.55)
    static let gradient = LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing)
}

struct Card<Content: View>: View {
    var padding: CGFloat = 22
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.stroke))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .lineLimit(1).fixedSize()
            .foregroundStyle(.white)
            .padding(.horizontal, 22).padding(.vertical, 11)
            .background(Capsule().fill(Theme.gradient).opacity(enabled ? 1 : 0.35))
            .shadow(color: Theme.accent.opacity(enabled ? 0.35 : 0), radius: 12, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    var tint: Color = .white
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .lineLimit(1).fixedSize()
            .foregroundStyle(tint.opacity(enabled ? 0.92 : 0.35))
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Capsule().fill(Color.white.opacity(configuration.isPressed ? 0.14 : 0.07)))
            .overlay(Capsule().strokeBorder(Theme.stroke))
    }
}

struct StatusPill: View {
    let icon: String
    let text: String
    let color: Color
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7).shadow(color: color, radius: 4)
            Image(systemName: icon).font(.system(size: 11, weight: .semibold))
            Text(text).font(.system(size: 12, weight: .medium)).lineLimit(1)
        }
        .foregroundStyle(.white.opacity(0.85))
        .padding(.horizontal, 11).padding(.vertical, 6)
        .background(Capsule().fill(Color.white.opacity(0.06)))
        .overlay(Capsule().strokeBorder(Theme.stroke))
    }
}

struct FieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.25)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.stroke))
    }
}

extension View {
    func field() -> some View { modifier(FieldStyle()) }
}

/// Ocena siły hasła (przybliżona entropia).
enum PasswordStrength {
    static func bits(_ p: String) -> Double {
        var pool = 0
        if p.contains(where: \.isLowercase) { pool += 26 }
        if p.contains(where: \.isUppercase) { pool += 26 }
        if p.contains(where: \.isNumber) { pool += 10 }
        if p.contains(where: { !$0.isLetter && !$0.isNumber && $0 != " " }) { pool += 32 }
        if p.contains(" ") { pool += 1 }
        if p.contains(where: { !$0.isASCII }) { pool += 30 }
        let unique = Double(Set(p).count) / Double(max(1, p.count))
        return Double(p.count) * log2(Double(max(pool, 1))) * min(1, 0.5 + unique)
    }

    static func describe(_ p: String) -> (String, Color, Double) {
        let b = bits(p)
        if p.count < Vault.minPasswordLength { return ("Za krótkie (min. \(Vault.minPasswordLength) znaków)", Theme.bad, min(0.25, b / 120)) }
        if b < 55 { return ("Słabe", Theme.bad, b / 120) }
        if b < 75 { return ("Średnie", Theme.warn, b / 120) }
        return ("Silne", Theme.good, min(1, b / 110))
    }
}

let byteFormatter: ByteCountFormatter = {
    let f = ByteCountFormatter()
    f.countStyle = .file
    return f
}()

func formatBytes(_ n: Int64) -> String { byteFormatter.string(fromByteCount: n) }

/// Zamiennik @State (w tym środowisku bez Xcode brak wtyczki makr SwiftUI) — lokalny stan widoku.
@propertyWrapper
struct Local<Value>: DynamicProperty {
    final class Box: ObservableObject {
        @Published var value: Value
        init(_ value: Value) { self.value = value }
    }
    @StateObject private var box: Box

    init(wrappedValue: Value) { _box = StateObject(wrappedValue: Box(wrappedValue)) }

    var wrappedValue: Value {
        get { box.value }
        nonmutating set { box.value = newValue }
    }
    var projectedValue: Binding<Value> { Binding(get: { box.value }, set: { box.value = $0 }) }
}

/// Wykrywa kod Yubico OTP "wpisany" przez YubiKey (dotknięcie przycisku, gdy aplikacja nie czeka na klucz).
/// Kod OTP to 44 znaki w alfabecie modhex — zwykłe hasło praktycznie nigdy tak się nie kończy.
enum StrayOTP {
    static let modhex = Set("cbdefghijklnrtuv")

    static func strip(_ text: String) -> String? {
        let tail = text.reversed().prefix { modhex.contains($0) }
        guard tail.count >= 32 else { return nil }
        return String(text.dropLast(tail.count))
    }
}

struct GuardYubiKeyTyping: ViewModifier {
    @Binding var text: String
    let model: AppModel
    func body(content: Content) -> some View {
        content.onChange(of: text) { _, value in
            if let cleaned = StrayOTP.strip(value) {
                text = cleaned
                model.warnStrayTouch()
            }
        }
    }
}

extension View {
    func guardsYubiKeyTyping(_ text: Binding<String>, _ model: AppModel) -> some View {
        modifier(GuardYubiKeyTyping(text: text, model: model))
    }
}
