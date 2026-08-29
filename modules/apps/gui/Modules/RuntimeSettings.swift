// Modules/RuntimeSettings.swift
// Runtime reads of the declarative `omanix.omabar.*` / `omanix.omatiles.*` options
// from ~/.omanix/configuration.nix, plus the rendered theme palette at
// ~/.config/omanix/theme.json. The GUI Settings pages write these same options
// through OmanixStore; this module is what lets the Omabar/Omatiles runtimes obey
// them without a rebuild (and what launchd module-mode uses directly).
//
// Foundation ONLY — no SwiftUI/AppKit. Views map the palette via Theme.swift.

import Foundation

enum RuntimeSettings {

    private static let configPath = NSHomeDirectory() + "/.omanix/configuration.nix"
    private static let themeJSONPath = NSHomeDirectory() + "/.config/omanix/theme.json"

    // MARK: - Configuration reading

    /// Raw text of configuration.nix (nil when unreadable).
    private static func configText() -> String? {
        try? String(contentsOfFile: configPath, encoding: .utf8)
    }

    /// Reads a literal `option = value;` from configuration.nix, stripping quotes.
    static func option(_ path: String) -> String? {
        guard let text = configText() else { return nil }
        let escaped = NSRegularExpression.escapedPattern(for: path)
        guard let range = text.range(
            of: #"\#(escaped)\s*=\s*([^;]+);"#,
            options: .regularExpression
        ) else { return nil }
        let line = String(text[range])
        guard let eq = line.firstIndex(of: "=") else { return nil }
        let value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespacesAndNewlines)
        return value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }

    static func bool(_ path: String, default defaultVal: Bool) -> Bool {
        option(path).map { $0 == "true" } ?? defaultVal
    }

    static func int(_ path: String, default defaultVal: Int) -> Int {
        option(path).flatMap(Int.init) ?? defaultVal
    }

    /// Reads a Nix string list literal `[ "a" "b" ]` (whitespace-separated).
    static func stringList(_ path: String, default defaultVal: [String] = []) -> [String] {
        guard let raw = option(path) else { return defaultVal }
        let inner = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard inner.hasPrefix("["), inner.hasSuffix("]") else { return defaultVal }
        let content = inner.dropFirst().dropLast()
        let tokens = content.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" })
        return tokens.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
    }

    // MARK: - Omabar

    struct Omabar {
        var enable = true
        var position = "top"          // top | bottom
        var height = 40               // points
        var transparent = false
        var blur = true
        var style = "default"         // default | glass | modern | minimal
        var colorScheme = "auto"      // auto | dark | light
        var showClock = true
        var showBattery = true
        var showVolume = true
        var showWifi = true

        static func load() -> Omabar {
            Omabar(
                enable: bool("omanix.omabar.enable", default: true),
                position: option("omanix.omabar.position") ?? "top",
                height: int("omanix.omabar.height", default: 40),
                transparent: bool("omanix.omabar.transparent", default: false),
                blur: bool("omanix.omabar.blur", default: true),
                style: option("omanix.omabar.style") ?? "default",
                colorScheme: option("omanix.omabar.colorScheme") ?? "auto",
                showClock: bool("omanix.omabar.showClock", default: true),
                showBattery: bool("omanix.omabar.showBattery", default: true),
                showVolume: bool("omanix.omabar.showVolume", default: true),
                showWifi: bool("omanix.omabar.showWifi", default: true)
            )
        }
    }

    // MARK: - Omatiles

    struct Omatiles {
        var enable = true
        var layout = "tiles"          // tiles | columns | rows | accordion
        var gapInner = 8
        var gapOuter = 10
        var bindings = true
        var watch = false
        var floatingApps: [String] = [
            "com.apple.finder",
            "com.apple.systempreferences",
            "com.apple.ActivityMonitor"
        ]

        static func load() -> Omatiles {
            Omatiles(
                enable: bool("omanix.omatiles.enable", default: true),
                layout: option("omanix.omatiles.layout") ?? "tiles",
                gapInner: int("omanix.omatiles.gapInner", default: 8),
                gapOuter: int("omanix.omatiles.gapOuter", default: 10),
                bindings: bool("omanix.omatiles.bindings", default: true),
                watch: bool("omanix.omatiles.watch", default: false),
                floatingApps: stringList(
                    "omanix.omatiles.floatingApps",
                    default: ["com.apple.finder", "com.apple.systempreferences", "com.apple.ActivityMonitor"]
                )
            )
        }
    }

    // MARK: - Theme palette

    /// The active Omanix palette (from theme.json's `colors` object plus its
    /// `mode`). Kept as plain RGBA so runtime modules never need SwiftUI to stay
    /// color-aware.
    struct Palette: Equatable {
        var name = ""
        var mode = "dark" // "light" | "dark" — themes/<name>/colors.toml `mode`
        var accent: (r: Double, g: Double, b: Double)
        var background: (r: Double, g: Double, b: Double)
        var foreground: (r: Double, g: Double, b: Double)
        var muted: (r: Double, g: Double, b: Double)
        var selection: (r: Double, g: Double, b: Double)
        var red: (r: Double, g: Double, b: Double)

        static func == (lhs: Palette, rhs: Palette) -> Bool {
            lhs.name == rhs.name
                && lhs.mode == rhs.mode
                && lhs.accent.r == rhs.accent.r
                && lhs.accent.g == rhs.accent.g
                && lhs.accent.b == rhs.accent.b
                && lhs.background.r == rhs.background.r
                && lhs.background.g == rhs.background.g
                && lhs.background.b == rhs.background.b
                && lhs.foreground.r == rhs.foreground.r
                && lhs.foreground.g == rhs.foreground.g
                && lhs.foreground.b == rhs.foreground.b
                && lhs.muted.r == rhs.muted.r
                && lhs.muted.g == rhs.muted.g
                && lhs.muted.b == rhs.muted.b
                && lhs.selection.r == rhs.selection.r
                && lhs.selection.g == rhs.selection.g
                && lhs.selection.b == rhs.selection.b
                && lhs.red.r == rhs.red.r
                && lhs.red.g == rhs.red.g
                && lhs.red.b == rhs.red.b
        }

        static func fallback() -> Palette {
            Palette(
                name: "omanix",
                mode: "light",
                accent: (0.04, 0.49, 1.0),
                background: (0.98, 0.98, 0.99),
                foreground: (0.11, 0.11, 0.12),
                muted: (0.68, 0.68, 0.71),
                selection: (0.90, 0.90, 0.92),
                red: (1.0, 0.23, 0.19)
            )
        }

        /// Estimated perceived luminance of `background` (0…1). Used to pick a
        /// safe text color when `mode` is missing from theme.json.
        var backgroundLuminance: Double {
            let r = background.r, g = background.g, b = background.b
            return 0.2126 * r + 0.7152 * g + 0.0722 * b
        }

        var isDark: Bool { mode == "dark" || backgroundLuminance < 0.5 }

        static func load() -> Palette {
            guard let data = FileManager.default.contents(atPath: themeJSONPath),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let colors = obj["colors"] as? [String: String]
            else { return .fallback() }

            func rgb(_ key: String) -> (r: Double, g: Double, b: Double)? {
                guard let hex = colors[key] else { return nil }
                var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
                h = h.replacingOccurrences(of: "#", with: "")
                guard h.count >= 6, let value = UInt64(h.prefix(6), radix: 16) else { return nil }
                return (
                    Double((value >> 16) & 0xFF) / 255.0,
                    Double((value >> 8) & 0xFF) / 255.0,
                    Double(value & 0xFF) / 255.0
                )
            }

            var palette = Palette.fallback()
            palette.name = (obj["name"] as? String) ?? palette.name
            if let mode = obj["mode"] as? String, mode == "light" || mode == "dark" {
                palette.mode = mode
            }
            palette.accent = rgb("accent") ?? palette.accent
            palette.background = rgb("background") ?? palette.background
            palette.foreground = rgb("foreground") ?? palette.foreground
            palette.muted = rgb("muted") ?? palette.muted
            palette.selection = rgb("selection") ?? palette.selection
            palette.red = rgb("red") ?? palette.red
            return palette
        }
    }
}