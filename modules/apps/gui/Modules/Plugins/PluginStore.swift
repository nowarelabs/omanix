// Modules/Plugins/PluginStore.swift
// Persists plugin-wide user choices — which plugins are enabled and their display
// order — as JSON at ~/.config/omanix/plugins.json. Keeping plugin state here (rather
// than editing configuration.nix per item) cleanly separates the reusable plugin
// surface from the OS-level Nix config, and makes drag-to-reorder trivially persistable.
//
// This file is Foundation-only so the module and GUI can both use it.

import Foundation

/// A stored record for one plugin.
struct PluginRecord: Codable, Equatable {
    var id: String
    var enabled: Bool
}

/// User-facing menu bar display preferences that drive our own clock / battery
/// renderers (as opposed to the OS-level Nix options). Persisted separately from
/// plugin order so the two concerns stay independent.
struct MenubarPrefs: Codable, Equatable {
    /// Hide the macOS menu bar until the pointer reaches the top of the screen.
    var autoHide: Bool
    /// Render the abbreviated date beside the time in the Clock plugin.
    var showDate: Bool
    /// Show the numeric charge % beside the battery icon.
    var showBatteryPercent: Bool
    /// Use a 24-hour clock ("digital") instead of 12-hour.
    var use24Hour: Bool
    /// "digital" renders an HH:mm title; "analog" renders a small clock glyph.
    var clockFormat: String

    static let `default` = MenubarPrefs(
        autoHide: false,
        showDate: true,
        showBatteryPercent: true,
        use24Hour: false,
        clockFormat: "digital"
    )
}

final class PluginStore {

    static let shared = PluginStore()

    private let fileURL = URL(fileURLWithPath: NSHomeDirectory() + "/.config/omanix/plugins.json")
    private let prefsURL = URL(fileURLWithPath: NSHomeDirectory() + "/.config/omanix/menubar.json")

    /// Persisted records; a plugin missing from this list falls back to its default.
    private(set) var records: [PluginRecord] = []

    /// Persisted display preferences for our menu bar renderers.
    private(set) var prefs: MenubarPrefs = .default

    init() {
        load()
        loadPrefs()
    }

    // MARK: - Display preferences

    func menuBarPrefs() -> MenubarPrefs { prefs }

    func setMenuBarPrefs(_ newPrefs: MenubarPrefs) {
        prefs = newPrefs
        savePrefs()
    }

    func updateMenuBarPrefs(_ mutate: (inout MenubarPrefs) -> Void) {
        var p = prefs
        mutate(&p)
        prefs = p
        savePrefs()
    }

    // MARK: Preferred order / enabled

    /// Ordered, filtered list of plugin IDs as the user has arranged them, with the
    /// registry defaults appended for any plugin not yet persisted.
    func orderedIDs(all plugins: [any OmanixPlugin]) -> [String] {
        let defaults = plugins.map(\.id)
        var result = records.map(\.id)
        for d in defaults where !result.contains(d) {
            result.append(d)
        }
        return result.filter { defaults.contains($0) }
    }

    /// Index of a plugin in the persisted order.
    func index(of id: String) -> Int {
        records.firstIndex { $0.id == id } ?? Int.max
    }

    func isEnabled(_ id: String, default defaultVal: Bool) -> Bool {
        records.first { $0.id == id }?.enabled ?? defaultVal
    }

    func setEnabled(_ id: String, _ enabled: Bool) {
        upsert(PluginRecord(id: id, enabled: enabled))
    }

    /// Reorders `id` to `destination` (the position it should occupy in the full list).
    func move(id: String, to destination: Int) {
        let ids = orderedIDs(all: PluginRegistry.all)
        guard let from = ids.firstIndex(of: id) else { return }
        var newIDs = ids
        newIDs.remove(at: from)
        let clamped = max(0, min(destination, newIDs.count))
        newIDs.insert(id, at: clamped)

        var byID: [String: Bool] = [:]
        for r in records { byID[r.id] = r.enabled }
        records = newIDs.map { PluginRecord(id: $0, enabled: byID[$0] ?? defaultEnabled(for: $0)) }
        save()
    }

    private func defaultEnabled(for id: String) -> Bool {
        // Keep prior per-item defaults that shipped with omanix.omabar.*
        switch id {
        case "clock", "battery", "volume", "wifi": return true
        case "apps": return false
        default: return true
        }
    }

    private func upsert(_ record: PluginRecord) {
        let index = records.firstIndex { $0.id == record.id }
        if let index {
            var mutable = records
            mutable[index] = record
            records = mutable
        } else {
            records.append(record)
        }
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([PluginRecord].self, from: data) else {
            records = []
            return
        }
        records = decoded
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(records)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Silently ignore: persistence is best-effort and non-blocking.
        }
    }

    private func loadPrefs() {
        guard let data = try? Data(contentsOf: prefsURL),
              let decoded = try? JSONDecoder().decode(MenubarPrefs.self, from: data) else {
            prefs = .default
            return
        }
        prefs = decoded
    }

    private func savePrefs() {
        do {
            try FileManager.default.createDirectory(
                at: prefsURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(prefs)
            try data.write(to: prefsURL, options: .atomic)
        } catch {
            // Silently ignore: persistence is best-effort and non-blocking.
        }
    }
}
