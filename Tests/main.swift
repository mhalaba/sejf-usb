import Foundation
import CryptoKit

// Testy rdzenia z programowym odpowiednikiem klucza FIDO2 (hmac-secret). Uruchom: ./build.sh test

final class SoftFIDO: FIDOAuthenticator {
    var creds: [Data: Data] = [:]
    func makeCredential(rpID: String) throws -> Data {
        let id = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
        creds[id] = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        return id
    }
    func hmacSecret(rpID: String, credentialIDs: [Data], salt: Data) throws -> (credentialID: Data, output: Data) {
        guard let id = credentialIDs.first(where: { creds[$0] != nil }) else { throw CTAPError(code: 0x2E) }
        return (id, Data(HMAC<SHA256>.authenticationCode(for: salt, using: SymmetricKey(data: creds[id]!))))
    }
}

var failures = 0
func check(_ cond: Bool, _ name: String) {
    print((cond ? "  ok   " : "  FAIL ") + name)
    if !cond { failures += 1 }
}
func throwsError(_ body: () throws -> Void) -> Bool {
    do { try body(); return false } catch { return true }
}

let fm = FileManager.default
let work = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : NSTemporaryDirectory())
    .appendingPathComponent("sejf-test-\(UUID().uuidString)")
let volume = work.appendingPathComponent("volume")
let src = work.appendingPathComponent("src")
let out = work.appendingPathComponent("out")
try fm.createDirectory(at: volume, withIntermediateDirectories: true)
try fm.createDirectory(at: src.appendingPathComponent("folder/pod"), withIntermediateDirectories: true)
defer { try? fm.removeItem(at: work) }

let key1 = SoftFIDO(), key2 = SoftFIDO()
let password = "poprawne hasło żółć 123"
let chunk = 4096
let iters = 10_000

print("Tworzenie sejfu")
let (vault, code) = try Vault.create(on: volume, password: password, fido: key1, serial: 111, label: "Test",
                                     chunkSize: chunk, iterations: iters)
check(vault.isUnlocked && vault.fidoSlots.count == 1 && vault.hasRecoverySlot, "sejf odblokowany, klucz FIDO2 + hasło odzyskiwania")
check(RecoveryCode.decode(code) != nil, "hasło odzyskiwania poprawne")
check(throwsError { _ = try Vault.create(on: volume, password: password, fido: key1, serial: 111, label: "x") },
      "drugi sejf na tym samym nośniku odrzucony")
check(throwsError { _ = try Vault.create(on: work.appendingPathComponent("v2"), password: "krotkie", fido: key1, serial: 1, label: "x") },
      "za krótkie hasło odrzucone")

print("Szyfrowanie plików różnych rozmiarów")
let sizes = [0, 1, chunk - 1, chunk, chunk + 1, chunk * 3 + 123]
var hashes: [String: Data] = [:]
for (i, size) in sizes.enumerated() {
    let rel = i % 2 == 0 ? "plik\(i).bin" : "folder/pod/ąę \(i).bin"
    let data = Data((0..<size).map { _ in UInt8.random(in: 0...255) })
    let url = src.appendingPathComponent(rel)
    try data.write(to: url)
    let (entry, sha) = try vault.encryptFile(at: url, relativePath: rel)
    hashes[entry.path] = Data(SHA256.hash(data: data))
    check(sha == hashes[entry.path] && entry.size == Int64(size), "zaszyfrowano \(size) B")
    check(try vault.verify(entry, sha256: sha), "weryfikacja \(size) B")
}
let dataDir = vault.root.appendingPathComponent("data")
let allBlobBytes = try fm.contentsOfDirectory(atPath: dataDir.path).map { try Data(contentsOf: dataDir.appendingPathComponent($0)) }
check(!allBlobBytes.contains { $0.range(of: Data("ąę".utf8)) != nil || $0.range(of: Data("plik".utf8)) != nil },
      "nazwy plików nie są widoczne w zaszyfrowanych danych")

print("Ponowne otwarcie i odblokowanie")
vault.lockVault()
check(throwsError { _ = try vault.listEntries() }, "zablokowany sejf nie listuje plików")
let reopened = try Vault.open(on: volume)
check(throwsError { try reopened.unlock(password: "złe hasło 1234567", fido: key1) }, "złe hasło odrzucone")
check(throwsError { try reopened.unlock(password: password, fido: key2) }, "inny klucz odrzucony")
try reopened.unlock(password: password, fido: key1)
let (entries, unreadable) = try reopened.listEntries()
check(entries.count == sizes.count && unreadable == 0, "hasło + klucz otwierają, lista kompletna")
try fm.createDirectory(at: out, withIntermediateDirectories: true)
var allMatch = true
var perms600 = true
for e in entries {
    let dest = try reopened.decrypt(e, into: out)
    if Data(SHA256.hash(data: try Data(contentsOf: dest))) != hashes[e.path] || !dest.path.hasSuffix(e.path) { allMatch = false }
    let p = (try fm.attributesOfItem(atPath: dest.path)[.posixPermissions] as? NSNumber)?.intValue
    if p != 0o600 { perms600 = false }
}
check(allMatch, "odszyfrowane pliki identyczne z oryginałami, ze ścieżkami")
check(perms600, "odszyfrowane pliki mają uprawnienia 0600")

print("Wykrywanie manipulacji")
let big = entries.first { $0.size == Int64(chunk * 3 + 123) }!
let bigURL = dataDir.appendingPathComponent(big.id)
let original = try Data(contentsOf: bigURL)
var flipped = original; flipped[flipped.count / 2] ^= 0x01
try flipped.write(to: bigURL)
check(throwsError { try reopened.decrypt(big, into: out) }, "zmieniony bajt wykryty")
try original.prefix(original.count - chunk / 2).write(to: bigURL)
check(throwsError { try reopened.decrypt(big, into: out) }, "obcięty plik wykryty")
try original.prefix(original.count - (4 + 123 + 16)).write(to: bigURL)
check(throwsError { try reopened.decrypt(big, into: out) }, "usunięty ostatni fragment wykryty")
do {
    var d = original
    var off = 25
    let metaLen = Int(d.readBE32(at: off)); off += 4 + metaLen
    let c1 = d.subdata(in: off ..< off + 4 + chunk + 16)
    let c2 = d.subdata(in: off + 4 + chunk + 16 ..< off + 2 * (4 + chunk + 16))
    d.replaceSubrange(off ..< off + 2 * (4 + chunk + 16), with: c2 + c1)
    try d.write(to: bigURL)
    check(throwsError { try reopened.decrypt(big, into: out) }, "zamiana kolejności fragmentów wykryta")
}
do {   // spreparowany rozmiar fragmentu (4 GB) nie może wymusić ogromnej alokacji
    var d = original
    d.replaceSubrange(21..<25, with: Data([0xFF, 0xFF, 0xFF, 0xF0]))
    try d.write(to: bigURL)
    check(throwsError { try reopened.decrypt(big, into: out) }, "spreparowany rozmiar fragmentu odrzucony")
}
check((fm.subpaths(atPath: out.path) ?? []).allSatisfy { !$0.contains(".sejf-tmp") && !$0.contains("(") },
      "nieudane odszyfrowanie nie zostawia częściowych plików")
try original.write(to: bigURL)
check(try reopened.verify(big, sha256: hashes[big.path]!), "przywrócony plik znowu poprawny")

print("Hasło odzyskiwania i zarządzanie kluczami")
reopened.lockVault()
check(throwsError { try reopened.unlock(recoveryCode: "0000-0000-0000-0000-0000-0000-0000-0000") }, "złe hasło odzyskiwania odrzucone")
try reopened.unlock(recoveryCode: code.lowercased().replacingOccurrences(of: "-", with: " "))
check(reopened.isUnlocked, "hasło odzyskiwania otwiera (bez względu na wielkość liter)")
try reopened.addFIDOKey(password: "hasło do zapasowego", fido: key2, serial: 222, label: "Zapasowy")
check(throwsError { try reopened.addFIDOKey(password: "hasło do zapasowego", fido: key2, serial: 222, label: "x") },
      "duplikat klucza odrzucony")
check(reopened.fidoSlots[0].challenge == reopened.fidoSlots[1].challenge, "klucze dzielą sól (jedno dotknięcie)")
let newCode = try reopened.regenerateRecoveryCode()
let r2 = try Vault.open(on: volume)
try r2.unlock(password: "hasło do zapasowego", fido: key2)
check(r2.isUnlocked, "zapasowy klucz otwiera")
r2.lockVault()
check(throwsError { try r2.unlock(recoveryCode: code) }, "stare hasło odzyskiwania unieważnione")
try r2.unlock(recoveryCode: newCode)
let slot111 = r2.fidoSlots.first { $0.serial == 111 }!.id
let headerBefore = try Data(contentsOf: r2.root.appendingPathComponent("header.json"))
check(throwsError { try r2.changePassword(slotID: slot111, currentPassword: "nie to hasło 12345",
                                          newPassword: "nowe hasło po zmianie", fido: key1) },
      "zmiana hasła: błędne obecne hasło odrzucone")
check(throwsError { try r2.changePassword(slotID: slot111, currentPassword: password, newPassword: password, fido: key1) },
      "zmiana hasła: identyczne nowe hasło odrzucone")
check(throwsError { try r2.changePassword(slotID: slot111, currentPassword: password, newPassword: "krótkie", fido: key1) },
      "zmiana hasła: za krótkie nowe hasło odrzucone")
check(throwsError { try r2.changePassword(slotID: slot111, currentPassword: password,
                                          newPassword: "nowe hasło po zmianie", fido: key2) },
      "zmiana hasła: inny klucz odrzucony")
check((try Data(contentsOf: r2.root.appendingPathComponent("header.json"))) == headerBefore,
      "zmiana hasła: po nieudanej próbie nagłówek bez zmian")
try r2.changePassword(slotID: slot111, currentPassword: password, newPassword: "nowe hasło po zmianie", fido: key1)
check(throwsError { try Vault.open(on: volume).unlock(password: password, fido: key1) }, "stare hasło nie działa po zmianie")
try r2.removeSlot(id: r2.fidoSlots.first { $0.serial == 222 }!.id)
check(throwsError { try r2.removeSlot(id: r2.fidoSlots[0].id) }, "nie można usunąć ostatniego YubiKeya")
check(throwsError { try Vault.open(on: volume).unlock(password: "hasło do zapasowego", fido: key2) }, "usunięty klucz nie działa")
try Vault.open(on: volume).unlock(password: "nowe hasło po zmianie", fido: key1)
check(true, "nowe hasło działa")

print("Wymiana klucza głównego (punkt 4)")
let rv = try Vault.open(on: volume)
try rv.unlock(password: "nowe hasło po zmianie", fido: key1)
try rv.addFIDOKey(password: "zapasowy przed wymianą", fido: key2, serial: 222, label: "Zapasowy")
let oldHeader = try Data(contentsOf: rv.root.appendingPathComponent("header.json"))
let oldRecovery = try rv.regenerateRecoveryCode()
let beforeRotation = try rv.listEntries().entries
let rotatedCode = try rv.rotateMasterKey(keepSlotID: rv.fidoSlots.first { $0.serial == 111 }!.id,
                                         password: "hasło po wymianie klucza", fido: key1)
let afterRotation = try rv.listEntries().entries
check(afterRotation.count == beforeRotation.count && Set(afterRotation.map(\.path)) == Set(beforeRotation.map(\.path)),
      "po wymianie są wszystkie pliki")
check(Set(afterRotation.map(\.id)).isDisjoint(with: beforeRotation.map(\.id)), "pliki zaszyfrowane od nowa (nowe identyfikatory)")
var rotatedOK = true
for e in afterRotation where try !rv.verify(e, sha256: hashes[e.path]!) { rotatedOK = false }
check(rotatedOK, "treść plików nienaruszona po wymianie")
check(rv.fidoSlots.count == 1 && rv.hasRecoverySlot, "zostaje jeden klucz + nowe hasło odzyskiwania")
let rv2 = try Vault.open(on: volume)
check(throwsError { try rv2.unlock(password: "zapasowy przed wymianą", fido: key2) }, "inny klucz po wymianie nie działa")
check(throwsError { try rv2.unlock(recoveryCode: oldRecovery) }, "stare hasło odzyskiwania po wymianie nie działa")
check(throwsError { try rv2.unlock(password: "nowe hasło po zmianie", fido: key1) }, "stare hasło po wymianie nie działa")
try rv2.unlock(password: "hasło po wymianie klucza", fido: key1)
check(rv2.isUnlocked, "nowe hasło + klucz działają")
do {   // atak starą kopią nagłówka: stary klucz główny nie odszyfruje nowych plików
    try oldHeader.write(to: rv.root.appendingPathComponent("header.json"))
    try oldHeader.write(to: rv.root.appendingPathComponent("header.bak.json"))
    let stale = try Vault.open(on: volume)
    try stale.unlock(password: "zapasowy przed wymianą", fido: key2)
    let (staleEntries, staleBad) = try stale.listEntries()
    check(staleEntries.isEmpty && staleBad == afterRotation.count, "stara kopia nagłówka nie odczyta plików po wymianie")
    try rv2.changePassword(slotID: rv2.fidoSlots[0].id, currentPassword: "hasło po wymianie klucza",
                           newPassword: "chwilowe hasło 123456", fido: key1)   // przywraca bieżący nagłówek
    try rv2.changePassword(slotID: rv2.fidoSlots[0].id, currentPassword: "chwilowe hasło 123456",
                           newPassword: "hasło po wymianie klucza", fido: key1)
}
let rv3 = try Vault.open(on: volume)
try rv3.unlock(recoveryCode: rotatedCode)
check(rv3.isUnlocked, "nowe hasło odzyskiwania działa")

print("Przerwana wymiana klucza")
do {
    let dir = rv3.root
    // a) przerwanie przed przełączeniem: data.new istnieje — ma zostać wycofane, sejf działa
    try fm.createDirectory(at: dir.appendingPathComponent("data.new"), withIntermediateDirectories: true)
    try Data("x".utf8).write(to: dir.appendingPathComponent("data.new/smiec.sejf"))
    let a = try Vault.open(on: volume)
    try a.unlock(recoveryCode: rotatedCode)
    let aCount = try a.listEntries().entries.count
    check(!fm.fileExists(atPath: dir.appendingPathComponent("data.new").path) && aCount == afterRotation.count,
          "przerwanie przed przełączeniem — wycofane, dane całe")
    // b) przerwanie między zamianą katalogów — ma zostać dokończone
    let before = try a.listEntries().entries.count
    let code2 = try a.regenerateRecoveryCode()
    let header = try Data(contentsOf: dir.appendingPathComponent("header.json"))
    try header.write(to: dir.appendingPathComponent("header.next.json"))
    try fm.moveItem(at: dir.appendingPathComponent("data"), to: dir.appendingPathComponent("data.new"))
    try fm.createDirectory(at: dir.appendingPathComponent("data.old"), withIntermediateDirectories: true)
    try Data("{}".utf8).write(to: dir.appendingPathComponent("header.json"))   // zepsuty główny nagłówek
    let b = try Vault.open(on: volume)
    try b.unlock(recoveryCode: code2)
    let bCount = try b.listEntries().entries.count
    check(bCount == before
          && !fm.fileExists(atPath: dir.appendingPathComponent("data.old").path)
          && !fm.fileExists(atPath: dir.appendingPathComponent("header.next.json").path),
          "przerwanie w trakcie przełączania — dokończone, dane całe")
}

print("Nagłówek zapasowy")
try Data("zepsute".utf8).write(to: rv3.root.appendingPathComponent("header.json"))
let r4 = try Vault.open(on: volume)
try r4.unlock(password: "hasło po wymianie klucza", fido: key1)
check(r4.isUnlocked, "uszkodzony header.json — sejf otwiera się z kopii")

print("Użytkownicy i nazwy sejfów")
do {
    let uv = work.appendingPathComponent("users")
    try fm.createDirectory(at: uv, withIntermediateDirectories: true)
    let anna = SoftFIDO(), piotr = SoftFIDO(), annaZapas = SoftFIDO()
    let (v, _) = try Vault.create(on: uv, password: "hasło Anny 123456", fido: anna, serial: 1, label: "YubiKey A",
                                  name: "  Rodzinny\u{0007} ", owner: "Anna", chunkSize: chunk, iterations: iters)
    check(v.displayName == "Rodzinny" && v.fidoSlots[0].owner == "Anna", "nazwa sejfu i właściciel zapisane (oczyszczone)")
    check(v.unlockedSlot?.owner == "Anna", "po utworzeniu wiadomo, kto jest zalogowany")
    try v.addFIDOKey(password: "hasło Piotra 123456", fido: piotr, serial: 2, label: "YubiKey P", owner: "Piotr")
    try v.addFIDOKey(password: "zapasowe Anny 12345", fido: annaZapas, serial: 3, label: "YubiKey A2", owner: "Anna")
    check(v.users == ["Anna", "Piotr"], "lista użytkowników bez powtórzeń")
    let (f, _) = try v.encryptFile(at: src.appendingPathComponent("plik0.bin"), relativePath: "wspolny.bin")
    let v2 = try Vault.open(on: uv)
    check(v2.displayName == "Rodzinny", "nazwa sejfu widoczna bez odblokowania")
    try v2.unlock(password: "hasło Piotra 123456", fido: piotr)
    let piotrSees = try v2.listEntries().entries.map(\.id)
    check(v2.unlockedSlot?.owner == "Piotr" && piotrSees == [f.id],
          "drugi użytkownik otwiera ten sam sejf i widzi te same pliki")
    check(throwsError { try Vault.open(on: uv).unlock(password: "hasło Anny 123456", fido: piotr) },
          "hasło jednego użytkownika nie działa z kluczem drugiego")
    try v2.changePassword(slotID: v2.unlockedSlotID!, currentPassword: "hasło Piotra 123456",
                          newPassword: "nowe hasło Piotra 1", fido: piotr)
    check(v2.unlockedSlot?.owner == "Piotr", "zmiana hasła zachowuje użytkownika")
    v2.lockVault()
    check(v2.unlockedSlotID == nil, "blokada czyści zalogowanego użytkownika")

    // Zgodność: nagłówek z wersji 1.1 (bez "name" i "owner") nadal się otwiera.
    let headerURL = uv.appendingPathComponent("Sejf.vault/header.json")
    var json = try JSONSerialization.jsonObject(with: Data(contentsOf: headerURL)) as! [String: Any]
    json.removeValue(forKey: "name")
    json["keyslots"] = (json["keyslots"] as! [[String: Any]]).map { var k = $0; k.removeValue(forKey: "owner"); return k }
    try JSONSerialization.data(withJSONObject: json).write(to: headerURL)
    let old = try Vault.open(on: uv)
    try old.unlock(password: "hasło Anny 123456", fido: anna)
    check(old.isUnlocked && old.header.name == nil && old.users == ["Bez nazwy"], "stary format nagłówka (1.1) działa")
    check(Vault.cleanName("   ") == nil && Vault.cleanName(String(repeating: "x", count: 99))?.count == 60, "puste i za długie nazwy obsłużone")
}

print("Wybór plików i bezpieczne usuwanie (punkt 2)")
do {
    let area = work.appendingPathComponent("area")
    let precious = area.appendingPathComponent("NIE_RUSZAC")
    let chosen = area.appendingPathComponent("zaznaczony")
    try fm.createDirectory(at: precious, withIntermediateDirectories: true)
    try fm.createDirectory(at: chosen.appendingPathComponent("pusty/glebiej"), withIntermediateDirectories: true)
    try "cenne".write(to: precious.appendingPathComponent("cenny.txt"), atomically: true, encoding: .utf8)
    try "sekret".write(to: chosen.appendingPathComponent(".env"), atomically: true, encoding: .utf8)
    try "zwykły".write(to: chosen.appendingPathComponent("plik.txt"), atomically: true, encoding: .utf8)
    try "finder".write(to: chosen.appendingPathComponent(".DS_Store"), atomically: true, encoding: .utf8)
    try "apple".write(to: chosen.appendingPathComponent("._plik.txt"), atomically: true, encoding: .utf8)
    try fm.createSymbolicLink(at: chosen.appendingPathComponent("skrot"), withDestinationURL: precious)

    let (files, skipped) = Vault.collectFiles([chosen], base: area)
    let names = Set(files.map(\.relative))
    check(names == ["zaznaczony/.env", "zaznaczony/plik.txt"], "ukryte pliki są szyfrowane, śmieci systemowe pominięte")
    check(skipped == ["zaznaczony/skrot"], "dowiązanie pominięte i zgłoszone")
    for f in files { try Shredder.shred(f.url) }
    check(!Shredder.removeEmptyDirectories(chosen), "folder z dowiązaniem nie jest usuwany")
    check(!fm.fileExists(atPath: chosen.appendingPathComponent("pusty").path), "puste podfoldery usunięte")
    check((try? String(contentsOf: precious.appendingPathComponent("cenny.txt"), encoding: .utf8)) == "cenne",
          "plik poza zaznaczeniem nienaruszony")
    try fm.removeItem(at: chosen.appendingPathComponent("skrot"))
    check(Shredder.removeEmptyDirectories(chosen), "folder z samym .DS_Store usunięty")

    let hidden = area.appendingPathComponent("tylko-ukryte")
    try fm.createDirectory(at: hidden, withIntermediateDirectories: true)
    try "x".write(to: hidden.appendingPathComponent(".ssh-klucz"), atomically: true, encoding: .utf8)
    check(!Shredder.removeEmptyDirectories(hidden) && fm.fileExists(atPath: hidden.appendingPathComponent(".ssh-klucz").path),
          "folder z ukrytym plikiem nie jest kasowany")

    let target = area.appendingPathComponent("cel.txt")
    try "nie nadpisuj".write(to: target, atomically: true, encoding: .utf8)
    let hard = area.appendingPathComponent("twarde.txt")
    try fm.linkItem(at: target, to: hard)
    try Shredder.shred(hard)
    check((try? String(contentsOf: target, encoding: .utf8)) == "nie nadpisuj", "dowiązanie twarde: drugi plik nienaruszony")
    let link = area.appendingPathComponent("link.txt")
    try fm.createSymbolicLink(at: link, withDestinationURL: target)
    try Shredder.shred(link)
    check((try? String(contentsOf: target, encoding: .utf8)) == "nie nadpisuj", "dowiązanie symboliczne: cel nienaruszony")
    check(Vault.safeComponents("../../etc/passwd") == ["etc", "passwd"], "ścieżki z ../ są neutralizowane")
}

print("Wykrywanie iCloud (punkt 1)")
let home = fm.homeDirectoryForCurrentUser
check(CloudCheck.isInICloud(home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/x")), "iCloud Drive wykryty")
check(!CloudCheck.isInICloud(work), "folder tymczasowy nie jest w iCloud")
let desktopSynced = (try? home.appendingPathComponent("Desktop").resourceValues(forKeys: [.isUbiquitousItemKey]))?.isUbiquitousItem == true
check(CloudCheck.isInICloud(home.appendingPathComponent("Desktop/nowy-folder")) == desktopSynced,
      "Pulpit: wykrycie zgodne z ustawieniem iCloud (\(desktopSynced ? "synchronizowany" : "lokalny"))")

print("Odporność parserów (punkt 8)")
check(throwsError { _ = try CBOR.decode(Data([0x5B, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF])) },
      "CBOR: gigantyczna długość odrzucona bez awarii")
check(throwsError { _ = try CBOR.decode(Data([0x9A, 0x7F, 0xFF, 0xFF, 0xFF])) }, "CBOR: za długa tablica odrzucona")
check(throwsError { _ = try CBOR.decode(Data(repeating: 0x81, count: 100)) }, "CBOR: zbyt głębokie zagnieżdżenie odrzucone")
let sample: CBOR = .map([1: .bytes(Data([1, 2])), "id": "x", -25: true, 3: .array([.int(-7), .int(500000)])])
check((try CBOR.decode(sample.encoded()).0) == sample, "CBOR: kodowanie i dekodowanie zgodne")

print("Czas PBKDF2 (3 000 000 iteracji)")
let t0 = Date()
_ = try Vault.create(on: work.appendingPathComponent("timing"), password: password, fido: key1, serial: 1, label: "t")
print(String(format: "  %.2f s", Date().timeIntervalSince(t0)))

print(failures == 0 ? "\nWSZYSTKIE TESTY ZALICZONE" : "\nBŁĘDY: \(failures)")
exit(failures == 0 ? 0 : 1)
