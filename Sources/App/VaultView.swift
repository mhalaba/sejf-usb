import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct VaultView: View {
    @EnvironmentObject var model: AppModel
    @Local private var selection = Set<FileEntry.ID>()
    @Local private var search = ""
    @Local private var showScan = false
    @Local private var showKeys = false
    @Local private var confirmDelete = false
    @Local private var dropTargeted = false
    @Local private var pending: [URL] = []

    var filtered: [FileEntry] {
        search.isEmpty ? model.entries : model.entries.filter { $0.path.localizedCaseInsensitiveContains(search) }
    }
    var selected: [FileEntry] { model.entries.filter { selection.contains($0.id) } }

    var body: some View {
        VStack(spacing: 16) {
            toolbar
            if model.entries.isEmpty {
                emptyState
            } else {
                table
            }
            footer
        }
        .padding(20)
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.accent, style: StrokeStyle(lineWidth: 3, dash: [10]))
                    .background(RoundedRectangle(cornerRadius: 20).fill(Theme.accent.opacity(0.08)))
                    .overlay(Label("Upuść, aby zaszyfrować", systemImage: "lock.doc.fill").font(.title2.bold()))
                    .padding(12)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            pending = urls
            return true
        } isTargeted: { dropTargeted = $0 }
        .confirmationDialog("Zaszyfrować \(pending.count) element(ów)?",
                            isPresented: Binding(get: { !pending.isEmpty }, set: { if !$0 { pending = [] } })) {
            Button("Zaszyfruj i usuń oryginały", role: .destructive) {
                model.encrypt(pending, base: nil, shredOriginals: true); pending = []
            }
            Button("Tylko zaszyfruj (oryginały zostają)") { model.encrypt(pending, base: nil, shredOriginals: false); pending = [] }
            Button("Anuluj", role: .cancel) { pending = [] }
        } message: {
            Text("Oryginał jest usuwany dopiero po sprawdzeniu, że zaszyfrowana kopia jest identyczna. Pliki z Pulpitu/Dokumentów (iCloud) Apple przechowuje jeszcze 30 dni w „Ostatnio usuniętych” na iCloud.com — usuń je tam ręcznie.")
        }
        .sheet(isPresented: $showScan) { ScanSheet() }
        .sheet(isPresented: $showKeys) { KeysSheet() }
        .sheet(isPresented: Binding(get: { model.showAddUser }, set: { model.showAddUser = $0 })) {
            AddUserSheet().environmentObject(model)
        }
        .sheet(item: Binding(get: { model.changePasswordSlot }, set: { model.changePasswordSlot = $0 })) { slot in
            ChangePasswordSheet(slot: slot).environmentObject(model)
        }
        .confirmationDialog("Usunąć \(selected.count) plik(ów) z sejfu?", isPresented: $confirmDelete) {
            Button("Usuń na zawsze", role: .destructive) { model.delete(selected); selection = [] }
        } message: { Text("Zaszyfrowane kopie zostaną usunięte. Tej operacji nie można cofnąć.") }
    }

    var toolbar: some View {
        HStack(spacing: 10) {
            Button { pending = model.pickFiles() } label: { Label("Dodaj pliki", systemImage: "plus") }
                .buttonStyle(PrimaryButtonStyle())
            Button { showScan = true } label: {
                Label(model.isFolder ? "Zaszyfruj folder" : "Zaszyfruj pendrive",
                      systemImage: model.isFolder ? "folder.badge.gearshape" : "externaldrive.badge.checkmark")
            }
                .buttonStyle(GhostButtonStyle())
                .help("Zaszyfruj niezaszyfrowane pliki leżące obok sejfu")
            Button { model.decrypt(selected) } label: { Label("Odszyfruj…", systemImage: "arrow.down.doc") }
                .buttonStyle(GhostButtonStyle()).disabled(selected.isEmpty)
            Button { confirmDelete = true } label: { Label("Usuń", systemImage: "trash") }
                .buttonStyle(GhostButtonStyle(tint: Theme.bad)).disabled(selected.isEmpty)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
                TextField("Szukaj", text: $search).textFieldStyle(.plain).frame(minWidth: 60, maxWidth: 160)
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Capsule().fill(Color.black.opacity(0.25)))
            .overlay(Capsule().strokeBorder(Theme.stroke))
            Button { model.beginChangePassword() } label: { Label("Zmień hasło", systemImage: "lock.rotation") }
                .buttonStyle(GhostButtonStyle()).help("Zmień hasło sejfu (⇧⌘P)")
            Button { showKeys = true } label: { Image(systemName: "key.2.on.ring.fill") }
                .buttonStyle(GhostButtonStyle()).help("Klucze, hasło odzyskiwania, wymiana klucza głównego")
            Button { model.lock() } label: { Label("Zablokuj", systemImage: "lock.fill") }
                .buttonStyle(GhostButtonStyle(tint: Theme.warn))
            if !model.isFolder {
                Button { model.eject() } label: { Image(systemName: "eject.fill") }
                    .buttonStyle(GhostButtonStyle()).help("Zablokuj i wysuń pendrive")
            }
        }
    }

    var table: some View {
        Table(filtered, selection: $selection) {
            TableColumn("Nazwa") { e in
                HStack(spacing: 8) {
                    Image(nsImage: icon(for: e)).resizable().frame(width: 18, height: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(e.name).lineLimit(1)
                        let dir = (e.path as NSString).deletingLastPathComponent
                        if !dir.isEmpty { Text(dir).font(.system(size: 10)).foregroundStyle(Theme.muted).lineLimit(1) }
                    }
                }
            }
            TableColumn("Rozmiar") { e in Text(formatBytes(e.size)).foregroundStyle(Theme.muted) }.width(90)
            TableColumn("Zmodyfikowano") { e in
                Text(e.modified.formatted(date: .abbreviated, time: .shortened)).foregroundStyle(Theme.muted)
            }.width(150)
        }
        .contextMenu(forSelectionType: FileEntry.ID.self) { ids in
            let items = model.entries.filter { ids.contains($0.id) }
            if items.count == 1 { Button("Otwórz podgląd") { model.preview(items[0]) } }
            Button("Odszyfruj do…") { model.decrypt(items) }
            Divider()
            Button("Usuń z sejfu", role: .destructive) { selection = ids; confirmDelete = true }
        } primaryAction: { ids in
            if let e = model.entries.first(where: { ids.contains($0.id) }) { model.preview(e) }
        }
        .alternatingRowBackgrounds(.disabled)
        .scrollContentBackground(.hidden)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.stroke))
    }

    var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "tray.and.arrow.down.fill").font(.system(size: 46)).foregroundStyle(Theme.gradient)
            Text("Sejf jest pusty").font(.system(size: 20, weight: .bold, design: .rounded))
            Text(model.isFolder ? "Przeciągnij tu pliki lub użyj „Zaszyfruj pliki z folderu”, żeby zabezpieczyć to, co leży w „\(model.volume?.name ?? "")”."
                             : "Przeciągnij tu pliki lub użyj „Zaszyfruj pendrive”, żeby zabezpieczyć to, co już na nim leży.")
                .foregroundStyle(Theme.muted).multilineTextAlignment(.center).frame(maxWidth: 420)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.stroke))
    }

    var footer: some View {
        HStack(spacing: 14) {
            Label("\(model.entries.count) plików · \(formatBytes(model.entries.reduce(0) { $0 + $1.size }))", systemImage: "doc.on.doc")
            if model.unreadable > 0 {
                Label("\(model.unreadable) uszkodzonych", systemImage: "exclamationmark.triangle.fill").foregroundStyle(Theme.bad)
            }
            let leftovers = model.unencryptedItems().count
            if leftovers > 0 {
                Button { showScan = true } label: {
                    Label((model.isFolder ? "W folderze" : "Na pendrivie") + " są niezaszyfrowane pliki: \(leftovers)", systemImage: "exclamationmark.shield.fill")
                }
                .buttonStyle(.plain).foregroundStyle(Theme.warn)
            }
            Spacer()
            Label("AES-256-GCM · YubiKey", systemImage: "checkmark.shield.fill").foregroundStyle(Theme.good.opacity(0.8))
        }
        .font(.system(size: 12))
        .foregroundStyle(Theme.muted)
    }

    func icon(for e: FileEntry) -> NSImage {
        let ext = (e.name as NSString).pathExtension
        return NSWorkspace.shared.icon(for: UTType(filenameExtension: ext) ?? .data)
    }
}

// MARK: - Szyfrowanie zawartości pendrive'a

struct ScanSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Local private var items: [URL] = []
    @Local private var chosen = Set<URL>()
    @Local private var shred = true
    @Local private var confirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(model.isFolder ? "Zaszyfruj pliki z folderu" : "Zaszyfruj pliki z pendrive'a").font(.system(size: 20, weight: .bold, design: .rounded))
            Text("Te pliki leżą na „\(model.volume?.name ?? "")” bez szyfrowania. Zaznacz, które przenieść do sejfu.")
                .font(.system(size: 13)).foregroundStyle(Theme.muted)
            if items.isEmpty {
                Card { Label("Wszystko jest zaszyfrowane.", systemImage: "checkmark.seal.fill").foregroundStyle(Theme.good) }
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(items, id: \.self) { url in
                            Toggle(isOn: Binding(get: { chosen.contains(url) },
                                                 set: { if $0 { chosen.insert(url) } else { chosen.remove(url) } })) {
                                HStack {
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 18, height: 18)
                                    Text(url.lastPathComponent)
                                    Spacer()
                                }
                            }
                            .toggleStyle(.checkbox)
                            .padding(.vertical, 4).padding(.horizontal, 8)
                        }
                    }
                }
                .frame(minHeight: 160, maxHeight: 280)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.2)))
                Toggle(isOn: $shred) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Usuń oryginały po zaszyfrowaniu i weryfikacji").font(.system(size: 13, weight: .medium))
                        Text("Każdy plik jest najpierw odszyfrowywany kontrolnie i porównywany (SHA-256), dopiero potem oryginał jest nadpisywany i usuwany.")
                            .font(.system(size: 11)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .toggleStyle(.switch)
                if shred && !model.isFolder {
                    Label("Pamięć flash może zachować kopie starych bloków. Dla pewności: po zaszyfrowaniu skopiuj folder Sejf.vault na Maca, sformatuj pendrive i skopiuj go z powrotem.",
                          systemImage: "info.circle")
                        .font(.system(size: 11)).foregroundStyle(Theme.warn).fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack {
                Spacer()
                Button("Anuluj") { dismiss() }.buttonStyle(GhostButtonStyle())
                Button { if shred { confirm = true } else { go() } } label: {
                    Label("Zaszyfruj (\(chosen.count))", systemImage: "lock.fill")
                }
                .buttonStyle(PrimaryButtonStyle()).disabled(chosen.isEmpty)
            }
        }
        .padding(28)
        .frame(width: 600)
        .background(Theme.bgBottom)
        .onAppear {
            items = model.unencryptedItems()
            chosen = Set(items)
        }
        .confirmationDialog("Zaszyfrować \(chosen.count) element(ów) i usunąć oryginały?", isPresented: $confirm) {
            Button("Zaszyfruj i usuń oryginały", role: .destructive) { go() }
        } message: {
            Text("Oryginał zostanie usunięty tylko wtedy, gdy kontrolne odszyfrowanie da identyczny plik. Upewnij się, że znasz hasło i masz kod odzyskiwania.")
        }
    }

    func go() {
        model.encrypt(items.filter { chosen.contains($0) }, base: model.volume?.url, shredOriginals: shred)
        dismiss()
    }
}

// MARK: - Zarządzanie kluczami

struct KeysSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Local private var mode: Mode?
    @Local private var password = ""
    @Local private var confirm = ""
    @Local private var removing: Keyslot?

    enum Mode: Equatable { case rotate(Keyslot) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Użytkownicy i klucze").font(.system(size: 20, weight: .bold, design: .rounded))
                Spacer()
                Button("Zamknij") { dismiss() }.buttonStyle(GhostButtonStyle())
            }
            Text("Każdy użytkownik otwiera ten sejf swoim YubiKeyem i własnym hasłem — wszyscy widzą te same pliki. Hasło odzyskiwania otwiera sejf bez klucza.")
                .font(.system(size: 12)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                ForEach(model.keyslots) { slot in
                    HStack(spacing: 12) {
                        Image(systemName: slot.kind == .fido2 ? "person.crop.circle.fill" : "doc.text.fill")
                            .font(.system(size: 18)).foregroundStyle(Theme.gradient).frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(slot.kind == .fido2 ? (slot.owner ?? "Bez nazwy") : "Hasło odzyskiwania")
                                    .font(.system(size: 13, weight: .semibold))
                                if slot.id == model.vault?.unlockedSlotID {
                                    Text("to Ty").font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Capsule().fill(Theme.accent.opacity(0.3)))
                                }
                            }
                            Text((slot.kind == .fido2 ? slot.label : "otwiera sejf bez klucza") + " · dodano " +
                                 Date(timeIntervalSince1970: slot.created).formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 11)).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        if slot.kind == .recovery {
                            Button("Nowe hasło") { after { model.regenerateRecovery() } }.buttonStyle(GhostButtonStyle())
                        } else {
                            Button("Zmień hasło") { after { model.beginChangePassword(slot) } }.buttonStyle(GhostButtonStyle())
                        }
                        Button { removing = slot } label: { Image(systemName: "trash") }
                            .buttonStyle(GhostButtonStyle(tint: Theme.bad))
                            .disabled(slot.kind == .fido2 && model.keyslots.filter { $0.kind == .fido2 }.count <= 1)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                }
            }

            HStack {
                Button { after { model.showAddUser = true } } label: { Label("Dodaj użytkownika lub klucz", systemImage: "person.badge.plus") }
                    .buttonStyle(GhostButtonStyle())
                if !(model.keyslots.contains { $0.kind == .recovery }) {
                    Button { after { model.regenerateRecovery() } } label: { Label("Utwórz hasło odzyskiwania", systemImage: "doc.badge.plus") }
                        .buttonStyle(GhostButtonStyle())
                }
                Spacer()
                Button {
                    password = ""; confirm = ""
                    if let slot = model.connectedFIDOSlot { mode = .rotate(slot) }
                } label: { Label("Wymień klucz główny…", systemImage: "arrow.triangle.2.circlepath") }
                    .buttonStyle(GhostButtonStyle(tint: Theme.warn))
                    .disabled(model.connectedFIDOSlot == nil)
                    .help("Szyfruje wszystko od nowa — unieważnia usunięte klucze, stare hasła i stare kopie sejfu")
            }

            if let mode {
                Card(padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(title(mode)).font(.system(size: 14, weight: .semibold))
                        if case .rotate(let slot) = mode {
                            let others = model.keyslots.filter { $0.kind == .fido2 && $0.id != slot.id }.map { $0.owner ?? $0.label }
                            Text("Wszystkie pliki zostaną zaszyfrowane od nowa nowym kluczem głównym. Zostanie tylko klucz „\(slot.displayName)” (z hasłem wpisanym poniżej) i NOWE hasło odzyskiwania." +
                                 (others.isEmpty ? "" : " Stracą dostęp i trzeba będzie ich dodać ponownie: \(Set(others).sorted().joined(separator: ", ")).") +
                                 " Stare hasła, stare hasło odzyskiwania i stare kopie sejfu przestaną działać.")
                                .font(.system(size: 12)).foregroundStyle(Theme.warn).fixedSize(horizontal: false, vertical: true)
                        }
                        SecureField("Hasło (min. \(Vault.minPasswordLength) znaków)", text: $password).field()
                            .guardsYubiKeyTyping($password, model)
                        SecureField("Powtórz hasło", text: $confirm).field()
                            .guardsYubiKeyTyping($confirm, model)
                        StrengthBar(password: password)
                        HStack {
                            Spacer()
                            Button("Anuluj") { self.mode = nil }.buttonStyle(GhostButtonStyle())
                            Button(isRotate(mode) ? "Wymień klucz" : "Zapisz") { save(mode) }
                                .buttonStyle(PrimaryButtonStyle()).disabled(!canSave(mode))
                        }
                    }
                }
            }
        }
        .padding(28)
        .frame(width: 680)
        .background(Theme.bgBottom)
        .onAppear { model.wantsKeyPolling = true }
        .onDisappear { model.wantsKeyPolling = false }
        .confirmationDialog("Usunąć „\(removing?.displayName ?? "")” z sejfu?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } })) {
            Button("Usuń", role: .destructive) { if let r = removing { let r2 = r; after { model.removeSlot(r2) } }; removing = nil }
        } message: { Text("Ten klucz przestanie otwierać ten sejf. Stare kopie sejfu (np. z kopii zapasowej) unieważnisz dopiero „Wymianą klucza głównego”.") }
    }

    func title(_ mode: Mode) -> String { "Wymiana klucza głównego" }

    func isRotate(_ mode: Mode) -> Bool { if case .rotate = mode { return true }; return false }

    /// Zamyka ten arkusz przed operacją — prośba „dotknij klucza” i postęp są widoczne w głównym oknie.
    func after(_ action: @escaping () -> Void) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: action)
    }

    func canSave(_ mode: Mode) -> Bool {
        password.count >= Vault.minPasswordLength && password == confirm
    }

    func save(_ mode: Mode) {
        let pw = password
        password = ""
        confirm = ""
        self.mode = nil
        if case .rotate(let slot) = mode { after { model.rotateMasterKey(slot: slot, password: pw) } }
    }
}

// MARK: - Zmiana hasła

struct ChangePasswordSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let slot: Keyslot
    @Local private var current = ""
    @Local private var new = ""
    @Local private var confirm = ""
    @FocusState private var focused: Bool

    var keyConnected: Bool {
        guard let serial = slot.serial else { return !model.keys.isEmpty }
        return model.keys.contains { $0.serial == serial }
    }

    var problem: String? {
        if !new.isEmpty && new.count < Vault.minPasswordLength { return "Nowe hasło musi mieć co najmniej \(Vault.minPasswordLength) znaków." }
        if !new.isEmpty && new == current { return "Nowe hasło musi różnić się od obecnego." }
        if !confirm.isEmpty && confirm != new { return "Nowe hasła się różnią." }
        return nil
    }

    var canSave: Bool {
        !current.isEmpty && new.count >= Vault.minPasswordLength && new == confirm && new != current && keyConnected
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "lock.rotation").font(.system(size: 26)).foregroundStyle(Theme.gradient)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Zmień hasło").font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("Dla klucza: \(slot.label)").font(.system(size: 12)).foregroundStyle(Theme.muted)
                }
            }
            SecureField("Obecne hasło", text: $current).field().focused($focused)
                .guardsYubiKeyTyping($current, model)
            Divider().overlay(Theme.stroke)
            SecureField("Nowe hasło (min. \(Vault.minPasswordLength) znaków — najlepiej kilka słów)", text: $new).field()
                .guardsYubiKeyTyping($new, model)
            SecureField("Powtórz nowe hasło", text: $confirm).field()
                .guardsYubiKeyTyping($confirm, model)
                .onSubmit { if canSave { save() } }
            StrengthBar(password: new)
            if let problem {
                Text(problem).font(.system(size: 12)).foregroundStyle(Theme.bad)
            }
            if keyConnected {
                Label("Po kliknięciu „Zmień hasło” dotknij YubiKey, gdy aplikacja o to poprosi (jeden raz).", systemImage: "hand.tap.fill")
                    .font(.system(size: 12)).foregroundStyle(Theme.muted)
            } else {
                Label("Włóż YubiKey" + (slot.serial.map { " nr \($0)" } ?? "") + ", aby zmienić jego hasło.", systemImage: "key")
                    .font(.system(size: 12)).foregroundStyle(Theme.warn)
            }
            Label("Zmiana dotyczy tego sejfu. Stare kopie sejfu (np. z kopii zapasowej) nadal otwiera stare hasło — aby to wykluczyć, użyj potem 🔑 → Wymień klucz główny.",
                  systemImage: "info.circle")
                .font(.system(size: 11)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Anuluj") { dismiss() }.buttonStyle(GhostButtonStyle())
                Button(action: save) { Label("Zmień hasło", systemImage: "checkmark") }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canSave)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 520)
        .background(Theme.bgBottom)
        .onAppear { focused = true; model.wantsKeyPolling = true }
        .onDisappear { model.wantsKeyPolling = false }
    }

    func save() {
        guard canSave, !model.justStrayTouched else { return }
        let (cur, pw) = (current, new)
        current = ""; new = ""; confirm = ""
        dismiss()
        // Arkusz zamknięty, żeby prośba „dotknij klucza” była widoczna w głównym oknie.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            model.changePassword(slot: slot, currentPassword: cur, newPassword: pw)
        }
    }
}

// MARK: - Dodawanie użytkownika

struct AddUserSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Local private var newPerson = true
    @Local private var name = ""
    @Local private var existing = ""
    @Local private var password = ""
    @Local private var confirm = ""

    var owner: String { newPerson ? (Vault.cleanName(name) ?? "") : existing }

    var newKey: YubiKeyDevice? {
        let registered = Set(model.keyslots.compactMap(\.serial))
        guard model.keys.count == 1, let key = model.keys.first else { return nil }
        return key.serial.map { registered.contains($0) } == true ? nil : key
    }

    var nameTaken: Bool { newPerson && model.vault?.users.contains(owner) == true }

    var canSave: Bool {
        !owner.isEmpty && !nameTaken && newKey != nil &&
            password.count >= Vault.minPasswordLength && password == confirm
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "person.badge.plus").font(.system(size: 26)).foregroundStyle(Theme.gradient)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dodaj użytkownika lub klucz").font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("Sejf „\(model.vault?.displayName ?? "")”").font(.system(size: 12)).foregroundStyle(Theme.muted)
                }
            }
            Picker("", selection: $newPerson) {
                Text("Nowa osoba").tag(true)
                Text("Zapasowy klucz istniejącej osoby").tag(false)
            }
            .pickerStyle(.segmented).labelsHidden()
            .disabled(model.vault?.users.isEmpty ?? true)

            if newPerson {
                TextField("Imię nowej osoby", text: $name).field()
                if nameTaken {
                    Text("Taki użytkownik już jest — wybierz „Zapasowy klucz istniejącej osoby”.").font(.system(size: 12)).foregroundStyle(Theme.warn)
                }
            } else {
                Picker("Dla kogo", selection: $existing) {
                    ForEach(model.vault?.users ?? [], id: \.self) { Text($0).tag($0) }
                }
            }

            keyStatus

            Text(newPerson ? "Hasło wpisuje NOWA OSOBA — sama, tak by nikt go nie widział:" : "Hasło dla tego klucza (może być inne niż dotychczasowe):")
                .font(.system(size: 12, weight: .semibold))
            SecureField("Hasło (min. \(Vault.minPasswordLength) znaków — najlepiej kilka słów)", text: $password).field()
                .guardsYubiKeyTyping($password, model)
            SecureField("Powtórz hasło", text: $confirm).field()
                .guardsYubiKeyTyping($confirm, model)
            StrengthBar(password: password)
            Label("Każdy użytkownik widzi wszystkie pliki tego sejfu i może zarządzać kluczami. Dodawaj tylko zaufane osoby.",
                  systemImage: "info.circle")
                .font(.system(size: 11)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Anuluj") { dismiss() }.buttonStyle(GhostButtonStyle())
                Button(action: save) { Label("Dodaj", systemImage: "checkmark") }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canSave)
            }
        }
        .padding(28)
        .frame(width: 560)
        .background(Theme.bgBottom)
        .onAppear {
            model.wantsKeyPolling = true
            existing = model.currentUser ?? model.vault?.users.first ?? ""
        }
        .onDisappear { model.wantsKeyPolling = false }
    }

    @ViewBuilder var keyStatus: some View {
        if let key = newKey {
            Label("Gotowy: \(key.name)" + (key.serial.map { " · nr \($0)" } ?? "") + " — po „Dodaj” dotkniesz go dwa razy.",
                  systemImage: "key.fill")
                .font(.system(size: 12)).foregroundStyle(Theme.good)
        } else if model.keys.count > 1 {
            Label("Podłączonych jest kilka kluczy — zostaw tylko klucz, który dodajesz.", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12)).foregroundStyle(Theme.warn)
        } else if model.keys.isEmpty {
            Label("Włóż YubiKey, który chcesz dodać.", systemImage: "key")
                .font(.system(size: 12)).foregroundStyle(Theme.warn)
        } else {
            Label("Ten klucz jest już w sejfie. Wyjmij go i włóż klucz nowej osoby.", systemImage: "arrow.triangle.swap")
                .font(.system(size: 12)).foregroundStyle(Theme.warn)
        }
    }

    func save() {
        guard canSave, let key = newKey, !model.justStrayTouched else { return }
        let (who, pw) = (owner, password)
        password = ""; confirm = ""
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            model.addUser(owner: who, serial: key.serial, keyName: key.name, password: pw)
        }
    }
}
