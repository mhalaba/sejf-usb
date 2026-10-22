import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.bgTop, Theme.bgBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            RadialGradient(colors: [Theme.accent2.opacity(0.22), .clear], center: UnitPoint(x: 0.85, y: 0.05),
                           startRadius: 0, endRadius: 420)
                .ignoresSafeArea()
            RadialGradient(colors: [Theme.accent.opacity(0.16), .clear], center: UnitPoint(x: 0.1, y: 0.95),
                           startRadius: 0, endRadius: 420)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HeaderBar()
                Group {
                    switch model.screen {
                    case .pickDrive: HomeView()
                    case .setup: SetupView()
                    case .unlock: UnlockView()
                    case .vault: VaultView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
            .animation(.easeInOut(duration: 0.25), value: model.screen)

            if let busy = model.busy { BusyOverlay(state: busy) }
            if let failure = model.selfTestFailure { SelfTestFailureView(message: failure) }
            if let notice = model.notice { NoticeToast(text: notice) { model.notice = nil } }
        }
        .alert(L("Błąd"), isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(model.errorMessage ?? "") }
        .sheet(isPresented: Binding(get: { model.recoveryCode != nil }, set: { if !$0 { model.recoveryCode = nil } })) {
            RecoveryCodeSheet(code: model.recoveryCode ?? "") { model.recoveryCode = nil }
        }
        .sheet(isPresented: Binding(get: { model.showNewVault }, set: { model.showNewVault = $0 })) {
            NewVaultSheet().environmentObject(model)
        }
        .sheet(item: Binding(get: { model.pinPrompt }, set: { model.pinPrompt = $0 })) { prompt in
            PinSheet(prompt: prompt).environmentObject(model)
        }
    }
}

struct HeaderBar: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.gradient).frame(width: 30, height: 30)
                Image(systemName: "lock.shield.fill").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
            }
            Text("Sejf USB").font(.system(size: 17, weight: .bold, design: .rounded))
            Spacer()
            if let v = model.volume {
                Button { model.goHome() } label: {
                    StatusPill(icon: v.format == "folder" ? "lock.shield" : "externaldrive.fill", text: v.name, color: Theme.accent)
                }.buttonStyle(.plain).help(L("Twoje sejfy — przełącz na inny"))
            }
            if model.screen == .vault, let user = model.currentUser {
                StatusPill(icon: "person.fill", text: user, color: Theme.accent2)
            }
            yubiPill
            if model.screen == .vault {
                StatusPill(icon: "lock.open.fill", text: L("Odblokowany · %@:%@", model.autoLockRemaining / 60, String(format: "%02d", model.autoLockRemaining % 60)), color: Theme.good)
                    .help(L("Automatyczna blokada po bezczynności"))
            }
        }
        .padding(.leading, 84).padding(.trailing, 20).padding(.vertical, 12)
        .background(Color.black.opacity(0.18))
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.stroke).frame(height: 1) }
    }

    @ViewBuilder var yubiPill: some View {
        if let k = model.keys.first {
            StatusPill(icon: "key.fill", text: k.name + (model.keys.count > 1 ? L(" +%@", model.keys.count - 1) : ""), color: Theme.good)
        } else {
            StatusPill(icon: "key", text: L("Włóż YubiKey"), color: Theme.warn)
        }
    }
}

// MARK: - Twoje sejfy (ekran startowy)

struct HomeView: View {
    @EnvironmentObject var model: AppModel

    var isFirstRun: Bool { model.library.isEmpty && model.discoveredVaults.isEmpty }

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                if isFirstRun { welcome } else { list }
            }
            .padding(40)
            .frame(maxWidth: .infinity)
        }
    }

    // Nowa instalacja: trzy drogi startu.
    var welcome: some View {
        VStack(spacing: 26) {
            Hero(icon: "lock.shield.fill", title: L("Witaj w Sejf USB"),
                 subtitle: L("Szyfrowany sejf na pliki — otwierasz go hasłem i dotknięciem YubiKeya."))
            HStack(alignment: .top, spacing: 16) {
                StartCard(icon: "plus.circle.fill", title: L("Utwórz nowy sejf"),
                          text: L("Pierwszy sejf na tym Macu albo na pendrivie. Potrzebujesz YubiKeya.")) { model.showNewVault = true }
                StartCard(icon: "folder.fill.badge.person.crop", title: L("Otwórz mój sejf"),
                          text: L("Masz już sejf (np. na pendrivie) i swój YubiKey z hasłem.")) { model.addExistingVault(joining: false) }
                StartCard(icon: "person.badge.plus", title: L("Dołącz do sejfu"),
                          text: L("Ktoś udostępnia Ci swój sejf. Osoba z dostępem odblokuje go przy Tobie, a Ty dodasz swój klucz.")) {
                    model.addExistingVault(joining: true)
                }
            }
            .frame(maxWidth: 860)
        }
    }

    var list: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(L("Twoje sejfy")).font(.system(size: 26, weight: .bold, design: .rounded))
                Spacer()
                Button { model.addExistingVault(joining: true) } label: { Label(L("Dołącz do sejfu"), systemImage: "person.badge.plus") }
                    .buttonStyle(GhostButtonStyle())
                Button { model.addExistingVault(joining: false) } label: { Label(L("Otwórz istniejący"), systemImage: "folder") }
                    .buttonStyle(GhostButtonStyle())
                Button { model.showNewVault = true } label: { Label(L("Nowy sejf"), systemImage: "plus") }
                    .buttonStyle(PrimaryButtonStyle())
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16)], spacing: 16) {
                ForEach(model.library) { known in
                    Button { model.open(known) } label: {
                        VaultCard(icon: "lock.fill", title: known.name, subtitle: Self.location(known.url),
                                  available: known.isAvailable)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(L("Pokaż w Finderze")) { NSWorkspace.shared.activateFileViewerSelecting([known.url.appendingPathComponent(Vault.folderName)]) }
                            .disabled(!known.isAvailable)
                        Button(L("Usuń z listy (pliki zostają)")) { model.forget(known) }
                    }
                }
                ForEach(model.discoveredVaults) { v in
                    Button { model.select(v) } label: {
                        VaultCard(icon: "externaldrive.fill", title: L("Sejf na „%@”", v.name), subtitle: L("Znaleziono na podłączonym nośniku"),
                                  available: true)
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(L("Sejfy są na liście tylko na tym Macu. Usunięcie z listy nie kasuje plików."))
                .font(.system(size: 11)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: 860)
    }

    static func location(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if url.path.hasPrefix("/Volumes/") {
            return L("Pendrive „") + (url.pathComponents.dropFirst(2).first ?? "") + "”"
        }
        return url.path.hasPrefix(home) ? "~" + url.path.dropFirst(home.count) : url.path
    }
}

struct StartCard: View {
    let icon: String
    let title: String
    let text: String
    let action: () -> Void
    @Local private var hover = false

    var body: some View {
        Button(action: action) {
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: icon).font(.system(size: 30)).foregroundStyle(Theme.gradient)
                    Text(title).font(.system(size: 16, weight: .bold))
                    Text(text).font(.system(size: 12)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(hover ? 1.02 : 1)
        .animation(.easeOut(duration: 0.15), value: hover)
        .onHover { hover = $0 }
    }
}

struct VaultCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let available: Bool
    @Local private var hover = false
    var body: some View {
        Card {
            HStack(spacing: 14) {
                Image(systemName: available ? icon : "questionmark.folder")
                    .font(.system(size: 22)).foregroundStyle(Theme.gradient).frame(width: 34)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                    Text(available ? subtitle : subtitle + L(" · niedostępny")).font(.system(size: 12))
                        .foregroundStyle(available ? Theme.muted : Theme.warn).lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
            }
        }
        .opacity(available ? 1 : 0.6)
        .scaleEffect(hover ? 1.02 : 1)
        .animation(.easeOut(duration: 0.15), value: hover)
        .onHover { hover = $0 }
    }
}

// MARK: - Nowy sejf

struct NewVaultSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Local private var name = ""
    @Local private var location: AppModel.NewVaultLocation = .mac

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L("Nowy sejf")).font(.system(size: 22, weight: .bold, design: .rounded))
            Text(L("Nazwa sejfu jest widoczna bez odblokowania — nie wpisuj w niej nic tajnego."))
                .font(.system(size: 12)).foregroundStyle(Theme.muted)
            TextField(L("Nazwa, np. Dokumenty rodzinne"), text: $name).field()
            Text(L("Gdzie zapisać sejf?")).font(.system(size: 13, weight: .semibold))
            VStack(spacing: 8) {
                option(.mac, icon: "laptopcomputer", title: L("Na tym Macu"),
                       detail: L("~/Sejfy/%@ — poza iCloud, z kopią w Time Machine", folderName))
                ForEach(model.volumes) { v in
                    option(.volume(v.url), icon: "externaldrive.fill", title: L("Na pendrivie „%@”", v.name),
                           detail: v.hasVault ? L("w folderze „%@” (na nośniku jest już inny sejf)", folderName) : L("%@ wolne", formatBytes(v.available)))
                }
                option(.custom, icon: "folder", title: L("W wybranym folderze…"), detail: L("poza Pulpitem, Dokumentami i iCloud Drive"))
            }
            HStack {
                Spacer()
                Button(L("Anuluj")) { dismiss() }.buttonStyle(GhostButtonStyle())
                Button {
                    let (n, l) = (name, location)
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { model.prepareNewVault(name: n, location: l) }
                } label: { Label(L("Dalej"), systemImage: "arrow.right") }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(Vault.cleanName(name) == nil)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 560)
        .background(Theme.bgBottom)
        .onAppear { model.refreshVolumes() }
    }

    var folderName: String {
        (Vault.cleanName(name) ?? "Sejf").replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
    }

    func option(_ value: AppModel.NewVaultLocation, icon: String, title: String, detail: String) -> some View {
        Button { location = value } label: {
            HStack(spacing: 12) {
                Image(systemName: location == value ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(location == value ? Theme.accent : Theme.muted)
                Image(systemName: icon).frame(width: 22).foregroundStyle(Theme.gradient)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .medium))
                    Text(detail).font(.system(size: 11)).foregroundStyle(Theme.muted).lineLimit(1)
                }
                Spacer()
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(location == value ? Theme.accent.opacity(0.12) : Theme.card))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct Hero: View {
    let icon: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.gradient).frame(width: 78, height: 78).shadow(color: Theme.accent.opacity(0.5), radius: 24)
                Image(systemName: icon).font(.system(size: 32, weight: .semibold)).foregroundStyle(.white)
            }
            Text(title).font(.system(size: 26, weight: .bold, design: .rounded))
            Text(subtitle).font(.system(size: 14)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
        }
    }
}

// MARK: - Panel YubiKey (wspólny)

struct YubiKeyStatusCard: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "key.horizontal.fill").font(.system(size: 20)).foregroundStyle(color).frame(width: 28)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(color.opacity(0.25)))
    }

    var ready: Bool { model.keys.first?.supportsHMACSecret == true }
    var color: Color { ready ? Theme.good : Theme.warn }
    var title: String {
        guard let k = model.keys.first else { return L("Włóż YubiKey do portu USB") }
        if !k.supportsHMACSecret { return L("%@ — nieobsługiwany", k.name) }
        return L("%@ gotowy", k.name) + (k.serial.map { L(" · nr %@", $0) } ?? "")
    }
    var detail: String {
        guard let k = model.keys.first else {
            return L("Klucz FIDO2: YubiKey 5, Security Key NFC / C NFC lub inny z obsługą hmac-secret. Na Macu wkładasz go do USB.")
        }
        if !k.supportsHMACSecret {
            return L("Ten klucz nie obsługuje FIDO2 hmac-secret (np. starszy klucz tylko U2F). Użyj YubiKey 5 albo Security Key z FIDO2.")
        }
        return L("Nie dotykaj klucza teraz. Kliknij przycisk poniżej — gdy pojawi się „Dotknij przycisku na YubiKey…”, wtedy dotknij.")
    }
}

// MARK: - Tworzenie sejfu

struct SetupView: View {
    @EnvironmentObject var model: AppModel
    @Local private var owner = ""
    @Local private var password = ""
    @Local private var confirm = ""
    @Local private var step = 1

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Hero(icon: step == 1 ? "lock.shield.fill" : "key.horizontal.fill",
                     title: L("Nowy sejf na „%@”", model.volume?.name ?? ""),
                     subtitle: step == 1 ? L("Krok 1 z 2 · ustaw hasło") : L("Krok 2 z 2 · dodaj YubiKey"))
                StepDots(step: step)
                if step == 1 { passwordStep } else {
                    TouchStepView(
                        title: L("Dodaj YubiKey"),
                        start: { done in model.createVault(owner: owner, password: password, failed: done) },
                        back: { step = 1 })
                    .frame(maxWidth: 560)
                }
            }
            .padding(36)
        }
    }

    var passwordStep: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                Label(L("Twoje imię"), systemImage: "person.fill").font(.system(size: 13, weight: .semibold))
                TextField(L("Np. Anna — widoczne dla innych użytkowników tego sejfu"), text: $owner).field()
                Label(L("Twoje hasło"), systemImage: "character.cursor.ibeam").font(.system(size: 13, weight: .semibold))
                SecureField(L("Hasło (min. %@ znaków — najlepiej kilka słów)", Vault.minPasswordLength), text: $password).field()
                    .guardsYubiKeyTyping($password, model)
                SecureField(L("Powtórz hasło"), text: $confirm).field()
                    .guardsYubiKeyTyping($confirm, model)
                    .onSubmit { if canContinue { step = 2 } }
                StrengthBar(password: password)
                if !confirm.isEmpty && confirm != password {
                    Text(L("Hasła się różnią")).font(.system(size: 12)).foregroundStyle(Theme.bad)
                }
                info("hand.raised.fill", L("Na tym etapie nie dotykaj YubiKeya. Klucz dodasz w następnym kroku."), Theme.warn)
                info("doc.text.fill", L("Na koniec dostaniesz hasło odzyskiwania. Otwiera ono sejf, gdy zgubisz YubiKey."))
                HStack {
                    Spacer()
                    Button { step = 2 } label: { Label(L("Dalej: dodaj YubiKey"), systemImage: "arrow.right") }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!canContinue)
                }
            }
        }
        .frame(maxWidth: 560)
    }

    func info(_ icon: String, _ text: String, _ color: Color = Theme.accent) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 18)
            Text(text).font(.system(size: 12)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
        }
    }

    var canContinue: Bool {
        Vault.cleanName(owner) != nil && password.count >= Vault.minPasswordLength && password == confirm
    }
}

struct StepDots: View {
    let step: Int
    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...2, id: \.self) { i in
                Capsule().fill(i <= step ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(Color.white.opacity(0.12)))
                    .frame(width: i == step ? 34 : 18, height: 6)
            }
        }
        .animation(.easeOut(duration: 0.2), value: step)
    }
}

/// Krok "dotknij YubiKey": gdy klucz jest gotowy, aplikacja SAMA zaczyna czekać na dotknięcie,
/// więc dotknięcie trafia do sejfu, a nie jest „wpisywane” jako kod OTP.
struct TouchStepView: View {
    @EnvironmentObject var model: AppModel
    let title: String
    let start: (@escaping () -> Void) -> Void
    let back: () -> Void
    @Local private var attempted = false
    @Local private var pulse = false

    var ready: Bool { model.keys.first?.supportsHMACSecret == true }

    var body: some View {
        Card {
            VStack(spacing: 18) {
                ZStack {
                    Circle().stroke(Theme.warn.opacity(0.5), lineWidth: 2).frame(width: 120, height: 120)
                        .scaleEffect(pulse ? 1.2 : 0.9).opacity(ready ? (pulse ? 0 : 1) : 0)
                    Circle().fill((ready ? Theme.warn : Theme.muted).opacity(0.14)).frame(width: 96, height: 96)
                    Image(systemName: ready ? "hand.tap.fill" : "key.slash")
                        .font(.system(size: 40)).foregroundStyle(ready ? Theme.warn : Theme.muted)
                }
                .onAppear { withAnimation(.easeOut(duration: 1.3).repeatForever(autoreverses: false)) { pulse = true } }
                Text(headline).font(.system(size: 18, weight: .bold, design: .rounded)).multilineTextAlignment(.center)
                Text(detail).font(.system(size: 13)).foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                if !ready { YubiKeyStatusCard() }
                HStack {
                    Button { back() } label: { Label(L("Wstecz"), systemImage: "arrow.left") }.buttonStyle(GhostButtonStyle())
                    Spacer()
                    if attempted && model.busy == nil && ready {
                        Button { begin() } label: { Label(L("Spróbuj ponownie"), systemImage: "arrow.clockwise") }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear { autoStart() }
        .onChange(of: model.keys) { _, _ in autoStart() }
    }

    var headline: String {
        if !ready { return model.keys.isEmpty ? L("Włóż YubiKey") : L("Ten klucz nie obsługuje FIDO2") }
        if model.busy?.touch == true { return L("Teraz dotknij złotego przycisku") }
        if model.busy != nil { return model.busy?.message ?? "" }
        return attempted ? L("Nie udało się — spróbuj ponownie") : "\(title)…"
    }

    var detail: String {
        if !ready { return L("Gdy klucz będzie gotowy, aplikacja sama poprosi o dotknięcie.") }
        if attempted && model.busy == nil {
            return L("Kliknij „Spróbuj ponownie”, a gdy pojawi się prośba, dotknij klucza (masz 30 sekund).")
        }
        return L("Dotknij krótko złotego przycisku (masz 30 sekund). Aplikacja sama przejdzie dalej.")
    }

    func autoStart() {
        guard ready, !attempted, model.busy == nil else { return }
        begin()
    }

    func begin() {
        attempted = true
        model.touch()
        start { }
    }
}

struct StrengthBar: View {
    let password: String
    var body: some View {
        let (label, color, value) = PasswordStrength.describe(password)
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule().fill(color).frame(width: max(6, geo.size.width * value))
                        .animation(.easeOut(duration: 0.2), value: value)
                }
            }
            .frame(height: 6)
            if !password.isEmpty { Text(label).font(.system(size: 12)).foregroundStyle(color) }
        }
    }
}

// MARK: - Odblokowanie

struct UnlockView: View {
    enum Method { case touch, recovery }
    @EnvironmentObject var model: AppModel
    @Local private var password = ""
    @Local private var recovery = ""
    @Local private var method: Method = .touch
    @Local private var touchStep = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 26) {
            Hero(icon: "lock.fill", title: L("„%@” jest zablokowany", model.vault?.displayName ?? "Sejf"), subtitle: subtitle)
            if method == .touch && touchStep {
                TouchStepView(title: L("Odblokowywanie"),
                              start: { _ in
                                  model.unlock(password: password, failed: { touchStep = false; password = ""; focused = true })
                              },
                              back: { touchStep = false; password = ""; focused = true })
                    .frame(maxWidth: 520)
            } else {
                if model.joining {
                    Card(padding: 16) {
                        Label {
                            Text(L("Dołączasz do sejfu „%@”. Poproś osobę, która ma już dostęp (%@), aby odblokowała go tutaj swoim kluczem i hasłem. Potem włożysz swój YubiKey i ustawisz własne hasło.", model.vault?.displayName ?? "", model.vault?.users.joined(separator: ", ") ?? ""))
                                .font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                        } icon: { Image(systemName: "person.badge.plus").foregroundStyle(Theme.accent) }
                    }
                    .frame(maxWidth: 520)
                }
                Card {
                    VStack(alignment: .leading, spacing: 16) {
                        switch method {
                        case .recovery:
                            SecureField("XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX", text: $recovery)
                                .font(.system(size: 15, design: .monospaced)).field().focused($focused)
                                .onSubmit(submit)
                        case .touch:
                            SecureField(L("Hasło sejfu"), text: $password).field().focused($focused).onSubmit(submit)
                                .guardsYubiKeyTyping($password, model)
                            Label(L("Nie dotykaj jeszcze YubiKeya — poproszę o to w następnym kroku."), systemImage: "hand.raised.fill")
                                .font(.system(size: 12)).foregroundStyle(Theme.warn)
                        }
                        HStack(alignment: .bottom) {
                            if method == .touch, model.vault?.hasRecoverySlot ?? false {
                                Button(L("Zgubiłem YubiKey — użyj hasła odzyskiwania")) { method = .recovery }
                                    .buttonStyle(.link).font(.system(size: 12))
                            } else if method == .recovery {
                                Button(L("Użyj hasła i YubiKeya")) { method = .touch }
                                    .buttonStyle(.link).font(.system(size: 12))
                            }
                            Spacer()
                            Button(action: submit) {
                                Label(method == .touch ? L("Dalej: YubiKey") : L("Odblokuj"),
                                      systemImage: method == .touch ? "arrow.right" : "lock.open.fill")
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(!canSubmit)
                            .keyboardShortcut(.defaultAction)
                        }
                    }
                }
                .frame(maxWidth: 520)
            }
        }
        .padding(40)
        .onAppear { focused = true }
        .onChange(of: model.screen) { _, _ in password = ""; recovery = ""; touchStep = false }
    }

    var subtitle: String {
        switch method {
        case .touch: return touchStep ? L("Krok 2 z 2 · YubiKey") : L("Krok 1 z 2 · wpisz hasło")
        case .recovery: return L("Wpisz 32-znakowe hasło odzyskiwania.")
        }
    }

    var canSubmit: Bool {
        switch method {
        case .touch: return !password.isEmpty
        case .recovery: return !recovery.isEmpty
        }
    }

    func submit() {
        guard canSubmit, !model.justStrayTouched else { return }
        switch method {
        case .touch:
            touchStep = true    // hasło zostaje w pamięci do kroku 2
        case .recovery:
            model.unlock(recoveryCode: recovery)
            recovery = ""
        }
    }
}

// MARK: - Nakładki

struct BusyOverlay: View {
    let state: BusyState
    @Local private var pulse = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 18) {
                if state.touch {
                    ZStack {
                        Circle().stroke(Theme.warn.opacity(0.5), lineWidth: 2)
                            .frame(width: 110, height: 110).scaleEffect(pulse ? 1.25 : 0.9).opacity(pulse ? 0 : 1)
                        Circle().fill(Theme.warn.opacity(0.15)).frame(width: 92, height: 92)
                        Image(systemName: "hand.tap.fill").font(.system(size: 38)).foregroundStyle(Theme.warn)
                    }
                    .onAppear { withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) { pulse = true } }
                } else if let p = state.progress {
                    ProgressView(value: p).progressViewStyle(.linear).frame(width: 260).tint(Theme.accent)
                } else {
                    ProgressView().controlSize(.large)
                }
                Text(state.message).font(.system(size: 15, weight: .medium)).multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }
            .padding(34)
            .background(RoundedRectangle(cornerRadius: 22).fill(.ultraThinMaterial))
        }
        .transition(.opacity)
    }
}

struct NoticeToast: View {
    let text: String
    let dismiss: () -> Void
    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.good)
                Text(text).font(.system(size: 13))
                Button(action: dismiss) { Image(systemName: "xmark").font(.system(size: 11, weight: .bold)) }.buttonStyle(.plain)
            }
            .padding(.horizontal, 16).padding(.vertical, 11)
            .background(Capsule().fill(.ultraThinMaterial))
            .overlay(Capsule().strokeBorder(Theme.stroke))
            .padding(.bottom, 24)
        }
        .task(id: text) {
            try? await Task.sleep(for: .seconds(6))
            dismiss()
        }
    }
}

struct RecoveryCodeSheet: View {
    let code: String
    let done: () -> Void
    @Local private var confirmed = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "key.viewfinder").font(.system(size: 40)).foregroundStyle(Theme.gradient)
            Text(L("Twoje hasło odzyskiwania")).font(.system(size: 22, weight: .bold, design: .rounded))
            Text(code)
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.35)))
            VStack(alignment: .leading, spacing: 8) {
                bullet(L("Zapisz go ręcznie na papierze i schowaj w bezpiecznym miejscu."))
                bullet(L("NIE zapisuj go na tym pendrivie ani w zdjęciu/notatce na telefonie."))
                bullet(L("Otwiera sejf bez YubiKeya i hasła — chroń je jak klucz do sejfu."))
                bullet(L("Nie kopiuj go do schowka ani nie rób zrzutu ekranu."))
                bullet(L("Nie zostanie pokazane ponownie (możesz później wygenerować nowe)."))
            }
            Toggle(L("Zapisałem hasło odzyskiwania w bezpiecznym miejscu"), isOn: $confirmed).toggleStyle(.checkbox)
            Button(L("Gotowe"), action: done).buttonStyle(PrimaryButtonStyle()).disabled(!confirmed)
        }
        .padding(32)
        .frame(width: 560)
        .background(Theme.bgBottom)
    }

    func bullet(_ s: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.warn).font(.system(size: 12))
            Text(s).font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - PIN FIDO2

struct PinSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let prompt: PinPrompt
    @Local private var pin = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "number.square.fill").font(.system(size: 26)).foregroundStyle(Theme.gradient)
                Text(L("Kod PIN FIDO2 klucza")).font(.system(size: 20, weight: .bold, design: .rounded))
            }
            Text(L("Ten klucz wymaga swojego kodu PIN FIDO2 przy rejestracji (ustawionego np. w Yubico Authenticator). To nie jest hasło sejfu — PIN zostaje tylko w kluczu i nie jest nigdzie zapisywany."))
                .font(.system(size: 12)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
            if let message = prompt.message {
                Label(message, systemImage: "exclamationmark.triangle.fill").font(.system(size: 12)).foregroundStyle(Theme.bad)
            }
            SecureField(L("PIN FIDO2 (min. 4 znaki)"), text: $pin).field().focused($focused)
                .guardsYubiKeyTyping($pin, model)
                .onSubmit(submit)
            Label(L("Po 8 błędnych próbach funkcje FIDO2 klucza zostaną zablokowane do czasu resetu."), systemImage: "info.circle")
                .font(.system(size: 11)).foregroundStyle(Theme.muted)
            HStack {
                Spacer()
                Button(L("Anuluj")) { dismiss() }.buttonStyle(GhostButtonStyle())
                Button(action: submit) { Label(L("Dalej"), systemImage: "arrow.right") }
                    .buttonStyle(PrimaryButtonStyle()).disabled(pin.count < 4).keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 480)
        .background(Theme.bgBottom)
        .onAppear { focused = true }
    }

    func submit() {
        guard pin.count >= 4, !model.justStrayTouched else { return }
        let value = pin
        pin = ""
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { prompt.retry(value) }
    }
}

// MARK: - Nieudane samotesty

struct SelfTestFailureView: View {
    let message: String
    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "xmark.shield.fill").font(.system(size: 54)).foregroundStyle(Theme.bad)
                Text(L("Samotest kryptograficzny nie powiódł się")).font(.system(size: 22, weight: .bold, design: .rounded))
                Text(message).font(.system(size: 13)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
                Button(L("Zamknij aplikację")) { NSApp.terminate(nil) }.buttonStyle(PrimaryButtonStyle())
            }
        }
    }
}
