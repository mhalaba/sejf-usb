import Foundation

/// Język interfejsu: polski albo angielski. Domyślnie według języka systemu (polski → polski, inny → angielski),
/// z możliwością wyboru w menu (zapisywane w ustawieniach aplikacji).
public enum Lang {
    public static let defaultsKey = "appLanguage"

    /// "pl", "en" albo nil (język systemu).
    public static var override: String? = UserDefaults.standard.string(forKey: defaultsKey)

    public static func set(_ code: String?) {
        override = code
        if let code { UserDefaults.standard.set(code, forKey: defaultsKey) } else { UserDefaults.standard.removeObject(forKey: defaultsKey) }
    }

    /// Format dat i liczb zgodny z językiem interfejsu.
    public static var locale: Locale { Locale(identifier: isPolish ? "pl_PL" : "en_US") }

    public static var isPolish: Bool {
        if let override { return override == "pl" }
        return Locale.preferredLanguages.first?.lowercased().hasPrefix("pl") ?? false
    }
}

/// Tekst interfejsu. Kluczem jest tekst polski; `%@` (lub `%1$@`, `%2$@`…) to miejsca na wartości.
/// Podstawianie jest tekstowe — błędne tłumaczenie nie może spowodować awarii.
public func L(_ key: String, _ args: Any...) -> String {
    let template = Lang.isPolish ? key : (Translations.en[key] ?? key)
    return Translations.format(template, args)
}

public enum Translations {
    static func format(_ template: String, _ args: [Any]) -> String {
        guard template.contains("%") else { return template }
        var out = ""
        var next = 0
        var i = template.startIndex
        while i < template.endIndex {
            let c = template[i]
            guard c == "%" else { out.append(c); i = template.index(after: i); continue }
            let rest = template[template.index(after: i)...]
            if rest.hasPrefix("@") {
                out += next < args.count ? "\(args[next])" : ""
                next += 1
                i = template.index(i, offsetBy: 2)
            } else if rest.hasPrefix("%") {
                out.append("%")
                i = template.index(i, offsetBy: 2)
            } else if let dollar = rest.firstIndex(of: "$"), let n = Int(rest[rest.startIndex..<dollar]),
                      template.index(after: dollar) < template.endIndex, template[template.index(after: dollar)] == "@" {
                out += (1...args.count).contains(n) ? "\(args[n - 1])" : ""
                i = template.index(dollar, offsetBy: 2)
            } else {
                out.append(c)
                i = template.index(after: i)
            }
        }
        return out
    }

    /// Liczba miejsc na wartości w szablonie (do testu zgodności tłumaczeń).
    public static func placeholderCount(_ template: String) -> Int {
        var positional = Set<Int>()
        var sequential = 0
        var i = template.startIndex
        while i < template.endIndex {
            if template[i] == "%" {
                let rest = template[template.index(after: i)...]
                if rest.hasPrefix("@") { sequential += 1 }
                else if let dollar = rest.firstIndex(of: "$"), let n = Int(rest[rest.startIndex..<dollar]) { positional.insert(n) }
                else if rest.hasPrefix("%") { i = template.index(after: i) }
            }
            i = template.index(after: i)
        }
        return max(sequential, positional.max() ?? 0)
    }
}
