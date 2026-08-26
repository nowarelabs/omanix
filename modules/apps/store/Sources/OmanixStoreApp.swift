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
            NSHomeDirectory() + "/.omanix/icon.icns",
            NSHomeDirectory() + "/.omanix/icon.png",
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

    // Space-like minimal dark theme
    static let tokyoNight = OmanixTheme(
        background: Color(red: 0.055, green: 0.055, blue: 0.067),
        surface: Color(red: 0.102, green: 0.102, blue: 0.118),
        tertiarySurface: Color(red: 0.137, green: 0.137, blue: 0.157),
        accent: Color(red: 0.400, green: 0.520, blue: 0.940),
        accentHover: Color(red: 0.500, green: 0.620, blue: 1.0),
        text: Color(red: 0.930, green: 0.930, blue: 0.960),
        secondaryText: Color(red: 0.550, green: 0.550, blue: 0.600),
        tertiaryText: Color(red: 0.380, green: 0.380, blue: 0.420),
        border: Color(red: 0.160, green: 0.160, blue: 0.180),
        success: Color(red: 0.300, green: 0.800, blue: 0.500),
        warning: Color(red: 0.950, green: 0.770, blue: 0.390),
        error: Color(red: 0.940, green: 0.350, blue: 0.350)
    )

    // Catppuccin with Space-like refinement
    static let catppuccin = OmanixTheme(
        background: Color(red: 0.060, green: 0.060, blue: 0.085),
        surface: Color(red: 0.100, green: 0.100, blue: 0.130),
        tertiarySurface: Color(red: 0.140, green: 0.140, blue: 0.175),
        accent: Color(red: 0.830, green: 0.535, blue: 0.760),
        accentHover: Color(red: 0.910, green: 0.615, blue: 0.840),
        text: Color(red: 0.930, green: 0.930, blue: 0.960),
        secondaryText: Color(red: 0.580, green: 0.580, blue: 0.630),
        tertiaryText: Color(red: 0.420, green: 0.420, blue: 0.470),
        border: Color(red: 0.180, green: 0.180, blue: 0.210),
        success: Color(red: 0.650, green: 0.800, blue: 0.540),
        warning: Color(red: 0.950, green: 0.770, blue: 0.390),
        error: Color(red: 0.940, green: 0.350, blue: 0.350)
    )

    static func load() -> OmanixTheme {
        let configPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".omanix/configuration.nix").path
        if let config = try? String(contentsOfFile: configPath, encoding: .utf8) {
            let pattern = #"omanix\.theme\s*=\s*"(catppuccin)""#
            if let _ = config.range(of: pattern, options: .regularExpression) {
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
