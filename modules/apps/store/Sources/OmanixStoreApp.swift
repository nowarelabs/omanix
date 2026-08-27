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
    // Depth layers (z-order: back to front) — mapped from shadcn dark vars
    let background: Color       // --background: #0A0A0A
    let surface: Color          // --card: #171717
    let hover: Color            // --secondary: #27272a
    let floating: Color         // --popover: #171717
    let tertiarySurface: Color  // --input: #27272a

    // Accent
    let accent: Color           // --primary: #ffffff
    let accentHover: Color

    // Text hierarchy
    let text: Color             // --foreground: #fafafa
    let secondaryText: Color    // --muted-foreground: #a1a1aa
    let tertiaryText: Color     // dimmed muted-foreground

    // Borders & dividers
    let border: Color           // --border: #27272a
    let divider: Color          // slightly dimmer border

    // Semantic
    let success: Color          // --chart-3: #34d399
    let warning: Color          // --chart-4: #fbbf24
    let error: Color            // --destructive: #ef4444

    // Source brand colors (from shadcn chart palette)
    let nixpkgs: Color          // chart-2: #85AEFA
    let nix: Color              // chart-5: #22d3ee
    let homebrewBrew: Color     // warm orange
    let homebrewCask: Color     // amber
    let custom: Color           // soft purple

    // shadcn/ui dark theme (matching --dark CSS vars)
    static let tokyoNight = OmanixTheme(
        background:       Color(red: 0.039, green: 0.039, blue: 0.039),  // #0A0A0A
        surface:          Color(red: 0.090, green: 0.090, blue: 0.090),  // #171717
        hover:            Color(red: 0.153, green: 0.153, blue: 0.165),  // #27272A
        floating:         Color(red: 0.090, green: 0.090, blue: 0.090),  // #171717
        tertiarySurface:  Color(red: 0.153, green: 0.153, blue: 0.165),  // #27272A
        accent:           Color(red: 1.000, green: 1.000, blue: 1.000),  // #FFFFFF
        accentHover:      Color(red: 0.980, green: 0.980, blue: 0.980),
        text:             Color(red: 0.980, green: 0.980, blue: 0.980),  // #FAFAFA
        secondaryText:    Color(red: 0.631, green: 0.631, blue: 0.667),  // #A1A1AA
        tertiaryText:     Color(red: 0.420, green: 0.420, blue: 0.447),
        border:           Color(red: 0.153, green: 0.153, blue: 0.165),  // #27272A
        divider:          Color(red: 0.118, green: 0.118, blue: 0.129),  // #1E1E22
        success:          Color(red: 0.204, green: 0.827, blue: 0.596),  // #34D399
        warning:          Color(red: 0.984, green: 0.749, blue: 0.141),  // #FBBF24
        error:            Color(red: 0.937, green: 0.267, blue: 0.267),  // #EF4444
        nixpkgs:          Color(red: 0.522, green: 0.686, blue: 0.980),  // #85AEFA
        nix:              Color(red: 0.133, green: 0.827, blue: 0.933),  // #22D3EE
        homebrewBrew:     Color(red: 0.957, green: 0.620, blue: 0.204),  // #F49D34
        homebrewCask:     Color(red: 0.906, green: 0.698, blue: 0.180),  // #E7B22E
        custom:           Color(red: 0.620, green: 0.525, blue: 0.910)   // #9E86E8
    )

    // Catppuccin variant — same depth as shadcn, Mocha accent palette
    static let catppuccin = OmanixTheme(
        background:       Color(red: 0.047, green: 0.047, blue: 0.071),  // #0C0C12
        surface:          Color(red: 0.090, green: 0.090, blue: 0.090),  // #171717
        hover:            Color(red: 0.153, green: 0.153, blue: 0.165),  // #27272A
        floating:         Color(red: 0.090, green: 0.090, blue: 0.090),  // #171717
        tertiarySurface:  Color(red: 0.153, green: 0.153, blue: 0.165),  // #27272A
        accent:           Color(red: 0.827, green: 0.533, blue: 0.757),  // Mocha mauve
        accentHover:      Color(red: 0.907, green: 0.613, blue: 0.837),
        text:             Color(red: 0.980, green: 0.980, blue: 0.980),  // #FAFAFA
        secondaryText:    Color(red: 0.631, green: 0.631, blue: 0.667),  // #A1A1AA
        tertiaryText:     Color(red: 0.420, green: 0.420, blue: 0.447),
        border:           Color(red: 0.153, green: 0.153, blue: 0.165),  // #27272A
        divider:          Color(red: 0.118, green: 0.118, blue: 0.129),  // #1E1E22
        success:          Color(red: 0.647, green: 0.792, blue: 0.537),  // Mocha green
        warning:          Color(red: 0.949, green: 0.769, blue: 0.388),  // Mocha yellow
        error:            Color(red: 0.937, green: 0.267, blue: 0.267),  // #EF4444
        nixpkgs:          Color(red: 0.522, green: 0.686, blue: 0.980),  // #85AEFA
        nix:              Color(red: 0.133, green: 0.827, blue: 0.933),  // #22D3EE
        homebrewBrew:     Color(red: 0.957, green: 0.620, blue: 0.204),  // #F49D34
        homebrewCask:     Color(red: 0.906, green: 0.698, blue: 0.180),  // #E7B22E
        custom:           Color(red: 0.620, green: 0.525, blue: 0.910)   // #9E86E8
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
