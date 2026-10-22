import SwiftUI
import AppKit

@main
struct SejfApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("Sejf USB", id: "main") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 1040, minHeight: 620)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1120, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Sejf") {
                Button("Zablokuj") { model.lock() }
                    .keyboardShortcut("l", modifiers: [.command])
                    .disabled(model.screen != .vault)
                Button("Zmień hasło…") { model.beginChangePassword() }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                    .disabled(model.screen != .vault)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private var observer: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Żadne okno aplikacji — także arkusze z hasłem odzyskiwania — nie trafia do zrzutów ekranu ani nagrań.
        observer = NotificationCenter.default.addObserver(forName: NSApplication.didUpdateNotification, object: nil,
                                                          queue: .main) { _ in
            MainActor.assumeIsolated {
                for window in NSApp.windows where window.sharingType != .none { window.sharingType = .none }
            }
        }
    }
}
