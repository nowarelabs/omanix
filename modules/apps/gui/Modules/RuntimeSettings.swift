// Modules/RuntimeSettings.swift
// Runtime reads of the declarative `omanix.omabar.*` / `omanix.omatiles.*` options
// from ~/.omanix/configuration.nix. The GUI Settings pages write these same options
// through OmanixStore; this module is what lets the Omabar/Omatiles runtimes obey
// them without a rebuild (and what launchd module-mode uses directly).
//
// Omabar now hosts status items in the NATIVE macOS menu bar, and Omatiles now
// bridges onto macOS Sequoia's built-in tiling — so neither needs theme color
// knowledge at runtime (the OS bar and OS tiling own the look & feel).
//
// Foundation ONLY — no SwiftUI/AppKit.

import Foundation

enum RuntimeSettings {

    private static let configPath = NSHomeDirectory() + "/.omanix/configuration.nix"

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

    // MARK: - Omabar (native menu bar status items)

    struct Omabar {
        var enable = true
        var showClock = true
        var showBattery = true
        var showVolume = true
        var showWifi = true
        var showApps = false

        static func load() -> Omabar {
            Omabar(
                enable: bool("omanix.omabar.enable", default: true),
                showClock: bool("omanix.omabar.showClock", default: true),
                showBattery: bool("omanix.omabar.showBattery", default: true),
                showVolume: bool("omanix.omabar.showVolume", default: true),
                showWifi: bool("omanix.omabar.showWifi", default: true),
                showApps: bool("omanix.omabar.showApps", default: false)
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