import SwiftUI

enum Palette {
    static let accent = Color(light: NSColor(red: 0.72, green: 0.46, blue: 0.09, alpha: 1),
                              dark: NSColor(red: 0.89, green: 0.68, blue: 0.34, alpha: 1))
}

private extension Color {
    init(light: NSColor, dark: NSColor) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }
}

@main
struct OffMarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            WorkspaceView(model: model)
                .tint(Palette.accent)
                .frame(minWidth: 850, minHeight: 560)
                .task { model.checkCLI() }
        }
        .defaultSize(width: 1100, height: 740)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About OffMar") {
                    var options: [NSApplication.AboutPanelOptionKey: Any] = [:]
                    if let icon = AppDelegate.bundledIcon {
                        options[.applicationIcon] = icon
                    }
                    NSApplication.shared.orderFrontStandardAboutPanel(options: options)
                }
            }
            CommandGroup(replacing: .newItem) {
                Button("Add Files…") { NotificationCenter.default.post(name: .addOffMarFiles, object: nil) }
                    .keyboardShortcut("o")
            }
            CommandMenu("Conversion") {
                Button("Convert Queue") { model.start() }
                    .keyboardShortcut("r")
                    .disabled(model.isRunning || !model.cliAvailable || model.queuedCount == 0)
                Button("Cancel Conversion") { model.cancel() }
                    .disabled(!model.isRunning)
            }
        }
        Settings {
            SettingsView(model: model)
                .tint(Palette.accent)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var bundledIcon: NSImage? {
        guard let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") else { return nil }
        return NSImage(contentsOf: url)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let icon = Self.bundledIcon {
            NSApplication.shared.applicationIconImage = icon
        }
    }
}

extension Notification.Name {
    static let addOffMarFiles = Notification.Name("addOffMarFiles")
}
