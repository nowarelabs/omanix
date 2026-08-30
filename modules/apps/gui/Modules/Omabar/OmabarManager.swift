// Modules/Omabar/OmabarManager.swift
// Omabar — Omanix status items living INSIDE the native macOS menu bar.
//
// This is the plugin-driven manager: it renders whatever plugins are enabled in
// the plugin registry/store as NSStatusItems in Apple's real menu bar (so the OS
// owns the look & feel). Which plugins are shown and their left-to-right order are
// user choices persisted in PluginStore, so drag-to-reorder "just works".
//
// A plugin becomes a status item by returning an OmanixMenubarRenderer from its
// `menubarRenderer()`; the manager installs, refreshes, and tears it down via the
// OmanixMenubarHost surface. Nothing here knows about a specific plugin.
//
// Live updates: the manager watches ~/.config/omanix (plugins.json + menubar.json).
// The GUI writes those files when the user toggles a plugin or reorders the bar.
// The standalone launchd --omabar process is a separate instance that would never
// notice those files otherwise, so the watcher reloads PluginStore and re-applies
// the bar members/format immediately.

import AppKit
import Combine
import Dispatch

@MainActor
final class OmabarManager: NSObject, OmanixMenubarHost {

    static let shared = OmabarManager()

    private(set) var isRunning = false

    /// id -> live renderer for every enabled plugin currently shown.
    private var renderers: [String: any OmanixMenubarRenderer] = [:]

    /// File-system watcher for ~/.config/omanix (plugin enable/order + bar prefs).
    private var watcher: DispatchSourceFileSystemObject?
    /// Second watcher for ~/.omanix/state.nix (Phase 3: declarative components).
    private var stateWatcher: DispatchSourceFileSystemObject?

    private override init() {
        super.init()
    }

    // MARK: - Public lifecycle (signatures kept for backward compatibility)

    @discardableResult
    func start(settings: RuntimeSettings.Omabar = RuntimeSettings.Omabar.load()) -> Bool {
        guard !isRunning else { return true }
        isRunning = true
        installAll()
        startWatching()
        return true
    }

    func apply(settings: RuntimeSettings.Omabar = RuntimeSettings.Omabar.load()) {
        guard isRunning else { return }
        removeAll()
        installAll()
    }

    func stop() {
        watcher?.cancel()
        watcher = nil
        stateWatcher?.cancel()
        stateWatcher = nil
        removeAll()
        isRunning = false
    }

    func refresh() {
        let loaded = RuntimeSettings.Omabar.load()
        if isRunning { apply(settings: loaded) } else { _ = start(settings: loaded) }
    }

    /// Push the latest display preferences (date, % , 24-hour, clock format) into the
    /// live renderers without tearing down the status items.
    func applyDisplayPrefs() {
        guard isRunning else { return }
        for renderer in renderers.values {
            renderer.refresh()
        }
    }

    // MARK: - File watching (live GUI -> module-sync)

    /// Watches the plugin registry directory and re-applies the bar whenever the GUI
    /// (or anything else) writes plugins.json / menubar.json. Idempotent.
    private func startWatching() {
        guard watcher == nil else { return }
        let fd = open(PluginStore.configDir, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            // The GUI writes atomically (tmp + rename): give it a beat, then re-read.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.registryChanged()
            }
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        watcher = source

        // Phase 3: also watch the declarative state file so `omanix state set
        // omanix.omabar.components.*.enable` live-applies without a rebuild.
        guard stateWatcher == nil else { return }
        let stateDir = (RuntimeSettings.statePath as NSString).deletingLastPathComponent
        let sfd = open(stateDir, O_EVTONLY)
        guard sfd >= 0 else { return }
        let stateSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: sfd,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        stateSource.setEventHandler { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.registryChanged()
            }
        }
        stateSource.setCancelHandler { close(sfd) }
        stateSource.resume()
        stateWatcher = stateSource
    }

    private func registryChanged() {
        PluginStore.shared.reload()
        refresh()
    }

    // MARK: - Host surface for renderers

    func makeStatusItem(menuable: Bool) -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if menuable {
            item.menu = NSMenu()
        }
        return item
    }

    func menu(for item: NSStatusItem) -> NSMenu {
        if let menu = item.menu { return menu }
        let menu = NSMenu()
        item.menu = menu
        return menu
    }

    // MARK: - Installation

    private func installAll() {
        let plugins = PluginRegistry.all
        let order = PluginStore.shared.orderedIDs(all: plugins)
        for id in order {
            guard PluginStore.shared.isEnabled(id, default: defaultEnabled(id)),
                  let plugin = PluginRegistry.plugin(id: id),
                  plugin.isAvailable,
                  let renderer = plugin.menubarRenderer() else { continue }
            renderers[id] = renderer
            renderer.install(into: self)
        }
    }

    private func removeAll() {
        for renderer in renderers.values {
            renderer.uninstall()
        }
        renderers.removeAll()
    }

    private func defaultEnabled(_ id: String) -> Bool {
        // Structured `components.<id>.enable` (Phase 3) overrides the flat defaults;
        // RuntimeSettings.Omabar.load() already folds that logic.
        let s = RuntimeSettings.Omabar.load()
        switch id {
        case "clock": return s.showClock
        case "battery": return s.showBattery
        case "volume": return s.showVolume
        case "wifi": return s.showWifi
        case "apps": return s.showApps
        default:
            if let v = RuntimeSettings.option("omanix.omabar.components.\(id).enable") { return v == "true" }
            return true
        }
    }
}
