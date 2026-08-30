// Modules/RuntimeSettings.swift
// Runtime reads of the declarative `omanix.omabar.*` / `omanix.omatiles.*` options
// from ~/.omanix/state.nix (machine-written) then configuration.nix. The GUI writes
// these options through `omanix state set` -> state.nix; this module is what lets the
// Omabar/Omatiles runtimes obey them without a rebuild (and what launchd module-mode
// uses directly).
//
// Omabar now hosts status items in the NATIVE macOS menu bar, and Omatiles now
// bridges onto macOS Sequoia's built-in tiling — so neither needs theme color
// knowledge at runtime (the OS bar and OS tiling own the look & feel).
//
// Foundation ONLY — no SwiftUI/AppKit.

import Foundation

enum RuntimeSettings {

    private static let omanixDir = NSHomeDirectory() + "/.omanix"
    private static let configPath = omanixDir + "/configuration.nix"
    private static let statePath = omanixDir + "/state.nix"

    // MARK: - Configuration reading

    /// Raw text of a Nix file (nil when unreadable).
    private static func nixText(_ path: String) -> String? {
        try? String(contentsOfFile: path, encoding: .utf8)
    }

    /// Reads a literal `option = value;` from state.nix first (machine-written,
    /// newer source), then configuration.nix (human-written), stripping quotes.
    static func option(_ path: String) -> String? {
        for file in [statePath, configPath] {
            if let v = literal(path, inFile: file) { return v }
        }
        return nil
    }

    /// Extracts the value of one `option = value;` assignment from a Nix file.
    private static func literal(_ path: String, inFile file: String) -> String? {
        guard let text = nixText(file) else { return nil }
        let escaped = NSRegularExpression.escapedPattern(for: path)
        guard let regex = try? NSRegularExpression(pattern: #"\#(escaped)\s*=\s*([^;]+);"#) else { return nil }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return ns.substring(with: match.range(at: 1))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }

    static func bool(_ path: String, default defaultVal: Bool) -> Bool {
        option(path).map { $0 == "true" } ?? defaultVal
    }

    // MARK: - Omabar (native menu bar status items)

    struct Omabar {
        var enable = true
        var showClock = true
        var showBattery = true
        var showVolume = true
        var showWifi = true
        var showApps = false
        var autoHide = false
        var showDate = true
        var showBatteryPercent = true
        var use24Hour = false
        var clockFormat = "digital"

        static func load() -> Omabar {
            Omabar(
                enable: bool("omanix.omabar.enable", default: true),
                showClock: bool("omanix.omabar.showClock", default: true),
                showBattery: bool("omanix.omabar.showBattery", default: true),
                showVolume: bool("omanix.omabar.showVolume", default: true),
                showWifi: bool("omanix.omabar.showWifi", default: true),
                showApps: bool("omanix.omabar.showApps", default: false),
                autoHide: bool("omanix.omabar.autoHide", default: false),
                showDate: bool("omanix.omabar.showDate", default: true),
                showBatteryPercent: bool("omanix.omabar.showBatteryPercent", default: true),
                use24Hour: bool("omanix.omabar.use24Hour", default: false),
                clockFormat: option("omanix.omabar.clockFormat") ?? "digital"
            )
        }
    }

    // MARK: - Omatiles (bridge onto macOS' built-in tiling)

    struct Omatiles {
        var enable = true
        var bindings = true

        static func load() -> Omatiles {
            Omatiles(
                enable: bool("omanix.omatiles.enable", default: true),
                bindings: bool("omanix.omatiles.bindings", default: true)
            )
        }
    }
}