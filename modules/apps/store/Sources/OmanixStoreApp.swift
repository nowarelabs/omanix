// modules/apps/store/Sources/OmanixStoreApp.swift
// Omanix — main app entry point
import SwiftUI

@main
struct OmanixStoreApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = StoreViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .environmentObject(store)
                .environment(\.omanixTheme, OmanixTheme.load())
                .preferredColorScheme(.dark)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1000, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set app icon from known path
        let possiblePaths = [
            NSHomeDirectory() + "/.omanix-store/icon.png",
            Bundle.main.bundlePath + "/Contents/Resources/AppIcon.icns",
            "/Applications/Omanix.app/Contents/Resources/AppIcon.icns"
        ]

        for path in possiblePaths {
            if let icon = NSImage(contentsOfFile: path) {
                NSApp.applicationIconImage = icon
                break
            }
        }
    }
}

// MARK: - Theme System

struct OmanixTheme {
    let background: Color
    let surface: Color
    let accent: Color
    let text: Color
    let secondaryText: Color

    static let tokyoNight = OmanixTheme(
        background: Color(red: 0.13, green: 0.13, blue: 0.17),
        surface: Color(red: 0.18, green: 0.18, blue: 0.23),
        accent: Color(red: 0.42, green: 0.44, blue: 0.95),
        text: Color(red: 0.87, green: 0.87, blue: 0.93),
        secondaryText: Color(red: 0.60, green: 0.60, blue: 0.67)
    )

    static let catppuccin = OmanixTheme(
        background: Color(red: 0.11, green: 0.11, blue: 0.15),
        surface: Color(red: 0.15, green: 0.15, blue: 0.20),
        accent: Color(red: 0.83, green: 0.53, blue: 0.76),
        text: Color(red: 0.90, green: 0.90, blue: 0.95),
        secondaryText: Color(red: 0.65, green: 0.65, blue: 0.70)
    )

    static func load() -> OmanixTheme {
        // Read theme from configuration.nix
        let configPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/omanix/configuration.nix").path

        if let config = try? String(contentsOfFile: configPath, encoding: .utf8) {
            if config.contains("catppuccin") {
                return .catppuccin
            }
        }
        return .tokyoNight
    }

    static func apply(_ theme: OmanixTheme) {
        // Handled by .preferredColorScheme(.dark) in the View
    }
}

// MARK: - Theme Environment Key

private struct OmanixThemeKey: EnvironmentKey {
    static let defaultValue = OmanixTheme.tokyoNight
}

extension EnvironmentValues {
    var omanixTheme: OmanixTheme {
        get { self[OmanixThemeKey.self] }
        set { self[OmanixThemeKey.self] = newValue }
    }
}
