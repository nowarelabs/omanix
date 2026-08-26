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
    // Depth layers (z-order: back to front)
    let background: Color       // #0D0E14 — page
    let surface: Color          // #1A1B23 — cards, sidebar, panels
    let hover: Color            // #22232D — row hover, elevated surface
    let floating: Color         // #2A2A2A — inspector, popovers (lightest)
    let tertiarySurface: Color  // #15161E — search bar, inputs

    // Accent
    let accent: Color           // #3B82F6 — selection, active states only
    let accentHover: Color

    // Text hierarchy
    let text: Color             // #F0F0F5 — primary (package names, headings)
    let secondaryText: Color    // #8A8A94 — descriptions, secondary
    let tertiaryText: Color     // #55555E — hints, badges, placeholders

    // Borders & dividers
    let border: Color           // rgba(255,255,255,0.06) — card borders
    let divider: Color          // rgba(255,255,255,0.04) — row separators

    // Semantic
    let success: Color          // green — installed
    let warning: Color          // amber — rebuild needed
    let error: Color            // red — destructive

    // Source brand colors
    let nixpkgs: Color          // blue
    let nix: Color              // cyan
    let homebrewBrew: Color     // orange
    let homebrewCask: Color     // amber-orange
    let custom: Color           // purple

    // Space-like minimal dark theme
    static let tokyoNight = OmanixTheme(
        background:       Color(red: 0.051, green: 0.055, blue: 0.078),
        surface:          Color(red: 0.102, green: 0.106, blue: 0.137),
        hover:            Color(red: 0.133, green: 0.137, blue: 0.176),
        floating:         Color(red: 0.165, green: 0.165, blue: 0.188),
        tertiarySurface:  Color(red: 0.082, green: 0.086, blue: 0.118),
        accent:           Color(red: 0.231, green: 0.510, blue: 0.965),
        accentHover:      Color(red: 0.331, green: 0.610, blue: 1.0),
        text:             Color(red: 0.941, green: 0.941, blue: 0.961),
        secondaryText:    Color(red: 0.541, green: 0.541, blue: 0.580),
        tertiaryText:     Color(red: 0.333, green: 0.333, blue: 0.369),
        border:           Color.white.opacity(0.06),
        divider:          Color.white.opacity(0.04),
        success:          Color(red: 0.220, green: 0.780, blue: 0.420),
        warning:          Color(red: 0.950, green: 0.770, blue: 0.390),
        error:            Color(red: 0.940, green: 0.350, blue: 0.350),
        nixpkgs:          Color(red: 0.231, green: 0.510, blue: 0.965),
        nix:              Color(red: 0.160, green: 0.720, blue: 0.800),
        homebrewBrew:     Color(red: 0.933, green: 0.655, blue: 0.271),
        homebrewCask:     Color(red: 0.851, green: 0.545, blue: 0.235),
        custom:           Color(red: 0.678, green: 0.502, blue: 0.890)
    )

    // Catppuccin with Space-like refinement
    static let catppuccin = OmanixTheme(
        background:       Color(red: 0.047, green: 0.047, blue: 0.071),
        surface:          Color(red: 0.098, green: 0.098, blue: 0.129),
        hover:            Color(red: 0.125, green: 0.125, blue: 0.161),
        floating:         Color(red: 0.157, green: 0.157, blue: 0.188),
        tertiarySurface:  Color(red: 0.078, green: 0.078, blue: 0.106),
        accent:           Color(red: 0.827, green: 0.533, blue: 0.757),
        accentHover:      Color(red: 0.907, green: 0.613, blue: 0.837),
        text:             Color(red: 0.941, green: 0.941, blue: 0.961),
        secondaryText:    Color(red: 0.580, green: 0.580, blue: 0.631),
        tertiaryText:     Color(red: 0.353, green: 0.353, blue: 0.400),
        border:           Color.white.opacity(0.06),
        divider:          Color.white.opacity(0.04),
        success:          Color(red: 0.647, green: 0.792, blue: 0.537),
        warning:          Color(red: 0.949, green: 0.769, blue: 0.388),
        error:            Color(red: 0.922, green: 0.380, blue: 0.380),
        nixpkgs:          Color(red: 0.827, green: 0.533, blue: 0.757),
        nix:              Color(red: 0.160, green: 0.720, blue: 0.800),
        homebrewBrew:     Color(red: 0.933, green: 0.655, blue: 0.271),
        homebrewCask:     Color(red: 0.851, green: 0.545, blue: 0.235),
        custom:           Color(red: 0.678, green: 0.502, blue: 0.890)
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

// MARK: - UI Constants

enum UIConstants {
    static let cornerCard: CGFloat = 12
    static let cornerRow: CGFloat = 6
    static let cornerPill: CGFloat = 999
    static let cornerInput: CGFloat = 8
    static let iconChipSmall: CGFloat = 22
    static let iconChipMedium: CGFloat = 24
    static let iconChipLarge: CGFloat = 28
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
