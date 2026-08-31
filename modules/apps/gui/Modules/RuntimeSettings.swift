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
import CoreGraphics

enum RuntimeSettings {

    static let omanixDir = NSHomeDirectory() + "/.omanix"
    static let configPath = omanixDir + "/configuration.nix"
    static let statePath = omanixDir + "/state.nix"

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
        var showVolumeText = true
        var showWifi = true
        var showApps = false
        var autoHide = false
        var showDate = true
        var showBatteryPercent = true
        var use24Hour = false
        var clockFormat = "digital"

        static func load() -> Omabar {
            // Structured `components.<name>.*` overrides flat `show*` when set (Phase 3).
            func compBool(_ name: String, _ key: String, flat: String, default def: Bool) -> Bool {
                if let v = option("omanix.omabar.components.\(name).\(key)") { return v == "true" }
                return bool(flat, default: def)
            }
            func compString(_ name: String, _ key: String, flat: String, default def: String) -> String {
                option("omanix.omabar.components.\(name).\(key)") ?? option(flat) ?? def
            }
            return Omabar(
                enable: bool("omanix.omabar.enable", default: true),
                showClock: compBool("clock", "enable", flat: "omanix.omabar.showClock", default: true),
                showBattery: compBool("battery", "enable", flat: "omanix.omabar.showBattery", default: true),
                showVolume: compBool("volume", "enable", flat: "omanix.omabar.showVolume", default: true),
                showVolumeText: compBool("volume", "showText", flat: "omanix.omabar.showVolumeText", default: true),
                showWifi: compBool("wifi", "enable", flat: "omanix.omabar.showWifi", default: true),
                showApps: compBool("apps", "enable", flat: "omanix.omabar.showApps", default: false),
                autoHide: bool("omanix.omabar.autoHide", default: false),
                showDate: bool("omanix.omabar.showDate", default: true),
                showBatteryPercent: compBool("battery", "showText", flat: "omanix.omabar.showBatteryPercent", default: true),
                use24Hour: bool("omanix.omabar.use24Hour", default: false),
                clockFormat: compString("clock", "style", flat: "omanix.omabar.clockFormat", default: "digital")
            )
        }
    }

    // MARK: - Omatiles (bridge onto macOS' built-in tiling)

    struct Omatiles {
        var enable = true
        var bindings = true
        var gap: CGFloat = 8
        /// Layout applied to ALL visible windows when auto-tiling or the user
        /// presses Apply. One of bsp/grid/monocle/stack/spiral/float.
        var defaultLayout = "bsp"
        /// When true, windows are automatically re-arranged into `defaultLayout`
        /// as they open (and when the layout/focus changes), Aerospace-style.
        var autoTile = true

        static func load() -> Omatiles {
            Omatiles(
                enable: bool("omanix.omatiles.enable", default: true),
                bindings: bool("omanix.omatiles.bindings", default: true),
                gap: CGFloat(option("omanix.omatiles.gap").flatMap(Double.init) ?? 8),
                defaultLayout: option("omanix.omatiles.defaultLayout") ?? "bsp",
                autoTile: bool("omanix.omatiles.autoTile", default: true)
            )
        }
    }

    // MARK: - Owin (Phase 4: declarative window manager)

    struct Owin {
        var enable = false
        var defaultLayout = "bsp"

        static func load() -> Owin {
            Owin(
                enable: bool("omanix.owin.enable", default: false),
                defaultLayout: option("omanix.owin.defaultLayout") ?? "bsp"
            )
        }
    }

    /// Where the declarative KDL layout document lives (`layout.kdl`), mirroring
    /// the Zellij convention. When present and it compiles to a non-empty map it
    /// takes precedence over the Nix-generated JSON (Strangler pattern: KDL is the
    /// human-facing declarative surface, Nix remains the fallback / bootstrap).
    static let kdlConfigPath = NSHomeDirectory() + "/.config/omanix/layout.kdl"

    /// Workspace map consumed by Owin. Sources are tried in order:
    ///   1. a declarative `layout.kdl` document (if it exists and yields a map)
    ///   2. the Nix-generated `workspaces.json`
    /// Returns `workspaceName -> { monitor, layout, apps }`. Empty when neither is
    /// present or Owin is disabled.
    static func workspaces() -> [String: WorkspaceConfig] {
        // 1. Declarative KDL source (Zellij-style) takes precedence.
        if let fromKdl = workspacesFromKDL(at: kdlConfigPath) {
            return fromKdl
        }

        // 2. Nix-generated JSON fallback.
        let path = omanixDir + "/../.config/omanix/workspaces.json"
        // Also try the canonical XDG path (home-manager writes via xdg.configFile).
        let candidates = [
            NSHomeDirectory() + "/.config/omanix/workspaces.json",
            omanixDir + "/workspaces.json",
            path
        ]
        for p in candidates {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: p)),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ws = obj["workspaces"] as? [String: Any] else { continue }
            var out: [String: WorkspaceConfig] = [:]
            for (name, raw) in ws {
                guard let dict = raw as? [String: Any] else { continue }
                out[name] = WorkspaceConfig(
                    monitor: dict["monitor"] as? String,
                    layout: (dict["layout"] as? String) ?? "bsp",
                    apps: (dict["apps"] as? [String]) ?? []
                )
            }
            return out
        }
        return [:]
    }

    /// Compiles a KDL layout document at `path` into the workspace map. Returns nil
    /// when the file is absent or does not compile to any workspace, so callers can
    /// transparently fall back. This is the pure, single-responsibility seam that
    /// lets the KDL bridge be tested headlessly without touching Nix.
    static func workspacesFromKDL(at path: String) -> [String: WorkspaceConfig]? {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        let compiled = KdlWorkspaceCompiler.compile(text)
        return compiled.isEmpty ? nil : compiled
    }

    struct WorkspaceConfig {
        var monitor: String?
        var layout: String
        var apps: [String]
    }

    // MARK: - Plugins (Phase 5: IPC socket)

    struct Plugins {
        var enable = true
        var socketPath = NSHomeDirectory() + "/.config/omanix/omanix.sock"

        static func load() -> Plugins {
            let enable = bool("omanix.plugins.enable", default: true)
            let raw = option("omanix.plugins.socketPath") ?? ".config/omanix/omanix.sock"
            let abs: String
            if raw.hasPrefix("/") {
                abs = raw
            } else if raw.hasPrefix("~") {
                abs = (raw as NSString).expandingTildeInPath
            } else {
                abs = NSHomeDirectory() + "/" + raw
            }
            return Plugins(enable: enable, socketPath: abs)
        }
    }
}