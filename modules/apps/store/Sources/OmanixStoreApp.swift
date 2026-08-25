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
        .defaultSize(width: 1080, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
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
    let tertiarySurface: Color
    let accent: Color
    let accentHover: Color
    let text: Color
    let secondaryText: Color
    let tertiaryText: Color
    let border: Color
    let success: Color
    let warning: Color
    let error: Color

    static let tokyoNight = OmanixTheme(
        background: Color(red: 0.098, green: 0.098, blue: 0.129),
        surface: Color(red: 0.149, green: 0.149, blue: 0.196),
        tertiarySurface: Color(red: 0.188, green: 0.188, blue: 0.243),
        accent: Color(red: 0.420, green: 0.443, blue: 0.953),
        accentHover: Color(red: 0.520, green: 0.543, blue: 1.0),
        text: Color(red: 0.878, green: 0.878, blue: 0.933),
        secondaryText: Color(red: 0.549, green: 0.561, blue: 0.647),
        tertiaryText: Color(red: 0.400, green: 0.412, blue: 0.490),
        border: Color(red: 0.220, green: 0.224, blue: 0.278),
        success: Color(red: 0.439, green: 0.792, blue: 0.537),
        warning: Color(red: 0.949, green: 0.769, blue: 0.388),
        error: Color(red: 0.922, green: 0.380, blue: 0.380)
    )

    static let catppuccin = OmanixTheme(
        background: Color(red: 0.086, green: 0.086, blue: 0.118),
        surface: Color(red: 0.125, green: 0.125, blue: 0.168),
        tertiarySurface: Color(red: 0.165, green: 0.165, blue: 0.212),
        accent: Color(red: 0.827, green: 0.533, blue: 0.757),
        accentHover: Color(red: 0.907, green: 0.613, blue: 0.837),
        text: Color(red: 0.902, green: 0.902, blue: 0.949),
        secondaryText: Color(red: 0.608, green: 0.608, blue: 0.671),
        tertiaryText: Color(red: 0.451, green: 0.451, blue: 0.510),
        border: Color(red: 0.200, green: 0.200, blue: 0.247),
        success: Color(red: 0.647, green: 0.792, blue: 0.537),
        warning: Color(red: 0.949, green: 0.769, blue: 0.388),
        error: Color(red: 0.922, green: 0.380, blue: 0.380)
    )

    static func load() -> OmanixTheme {
        let configPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/omanix/configuration.nix").path
        if let config = try? String(contentsOfFile: configPath, encoding: .utf8) {
            if config.contains("catppuccin") {
                return .catppuccin
            }
        }
        return .tokyoNight
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
