// modules/apps/store/Sources/OmanixStoreApp.swift
// Omanix — main app entry point
import SwiftUI

@main
struct OmanixStoreApp: App {
    @StateObject private var store = StoreViewModel()

    init() {
        // Set app icon programmatically
        if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let icon = NSImage(contentsOfFile: iconPath) {
            NSApp.applicationIconImage = icon
        } else if let iconPath = Bundle.main.path(forResource: "icon", ofType: "png"),
                  let icon = NSImage(contentsOfFile: iconPath) {
            NSApp.applicationIconImage = icon
        }

        // Load theme colors
        let theme = OmanixTheme.load()
        OmanixTheme.apply(theme)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .environmentObject(store)
                .environment(\.omanixTheme, OmanixTheme.load())
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1000, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) { }
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
        // Force dark appearance for the app
        NSApp.appearance = NSAppearance(named: .darkAqua)
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
