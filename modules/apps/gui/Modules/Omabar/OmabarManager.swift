// Modules/Omabar/OmabarManager.swift
// Omabar — Omanix status items living INSIDE the native macOS menu bar.
//
// This is the rewritten architecture: no custom bar panel, no notch math, no
// SwiftUI. We add up to five small items (running-apps, Wi-Fi, battery, volume,
// clock) to Apple's real menu bar via NSStatusItem/NSStatusBar, so the OS owns
// the look & feel, spacing, and Appearance handling. Each item hides or reuses
// macOS's own status behaviors and opens menus / system settings deep links.
//
// The corresponding native Control Center items are hidden at activation time
// (darwin/omabar.nix) so ours don't duplicate them.

import AppKit
import Combine

@MainActor
final class OmabarManager: NSObject {

    static let shared = OmabarManager()

    private(set) var isRunning = false
    private var settings: RuntimeSettings.Omabar = .load()

    private let model = OmabarModel()
    private var items: [StatusItemKind: BarItem] = [:]
    private var modelSubscriber: AnyCancellable?

    /// Which Omabar status items exist, and their order.
    private enum StatusItemKind: CaseIterable, Hashable {
        case apps, wifi, battery, volume, clock
    }

    /// One installed status item plus its (reusable) menu.
    private final class BarItem: NSObject, NSMenuDelegate {
        let item: NSStatusItem
        let menu: NSMenu
        var menuOpen = false

        init(kind: StatusItemKind, menuable: Bool) {
            item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            menu = NSMenu()
            super.init()
            if menuable {
                menu.delegate = self
                item.menu = menu
            }
        }

        var button: NSStatusBarButton? { item.button }

        func menuWillOpen(_ menu: NSMenu) { menuOpen = true }
        func menuDidClose(_ menu: NSMenu) { menuOpen = false }
    }

    private override init() { super.init() }

    /// Symbols come in as template images so they follow the menu bar Appearance.
    private static func symbol(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: name)
        image?.isTemplate = true
        return image
    }

    // MARK: - Lifecycle

    @discardableResult
    func start(settings: RuntimeSettings.Omabar = RuntimeSettings.Omabar.load()) -> Bool {
        guard !isRunning else { return true }
        self.settings = settings
        model.start()
        installItems(settings: settings)
        modelSubscriber = model.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in self?.render() }
        }
        isRunning = true
        render()
        return true
    }

    /// Re-installs a running bar from new declarative settings (no rebuild needed).
    func apply(settings: RuntimeSettings.Omabar) {
        guard isRunning else { return }
        self.settings = settings
        removeItems()
        installItems(settings: settings)
        render()
    }

    func stop() {
        modelSubscriber?.cancel(); modelSubscriber = nil
        model.stop()
        removeItems()
        isRunning = false
    }

    func refresh() {
        let loaded = RuntimeSettings.Omabar.load()
        if isRunning { apply(settings: loaded) } else { _ = start(settings: loaded) }
    }

    // MARK: - Installation

    private func installItems(settings: RuntimeSettings.Omabar) {
        if settings.showApps { makeBarItem(.apps, menuable: true) }
        if settings.showWifi { makeBarItem(.wifi, menuable: true) }
        if settings.showBattery { makeBarItem(.battery, menuable: true) }
        if settings.showVolume { makeBarItem(.volume, menuable: true) }
        if settings.showClock { makeBarItem(.clock, menuable: false) }
    }

    private func makeBarItem(_ kind: StatusItemKind, menuable: Bool) {
        let barItem = BarItem(kind: kind, menuable: menuable)
        barItem.item.button?.target = self
        barItem.item.button?.action = menuable ? nil : #selector(clockClicked(_:))
        barItem.item.button?.sendAction(on: menuable ? [.leftMouseUp] : [.leftMouseUp, .rightMouseUp])
        items[kind] = barItem
    }

    private func removeItems() {
        for barItem in items.values {
            NSStatusBar.system.removeStatusItem(barItem.item)
        }
        items.removeAll()
    }

    // MARK: - Rendering (fires whenever the model publishes)

    /// Pushes current model values into the buttons and refreshes menu contents.
    private func render() {
        renderApps()
        renderWifi()
        renderBattery()
        renderVolume()
        renderClock()
    }

    private func renderApps() {
        guard let barItem = items[.apps], let button = barItem.button else { return }
        if let frontmost = NSWorkspace.shared.frontmostApplication {
            button.title = ""
            button.image = (frontmost.icon ?? Self.symbol("square.grid.2x2"))?.withSymbolConfiguration(.init(pointSize: 15, weight: .regular))
        } else {
            button.title = ""
            button.image = Self.symbol("laptopcomputer")
        }
        guard !barItem.menuOpen else { return }
        barItem.menu.removeAllItems()
        let header = NSMenuItem(title: "Running Apps", action: nil, keyEquivalent: "")
        header.isEnabled = false
        barItem.menu.addItem(header)
        if model.visibleApps.isEmpty {
            barItem.menu.addItem(NSMenuItem(title: "No windows visible", action: nil, keyEquivalent: ""))
            return
        }
        for app in model.visibleApps {
            let runner = NSRunningApplication(processIdentifier: app.pid)
            let entry = NSMenuItem(title: app.name, action: #selector(activateApp(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = NSNumber(value: app.pid)
            if app.isFocused { entry.state = .on }
            if let icon = runner?.icon {
                entry.image = icon.withSymbolConfiguration(.init(pointSize: 15, weight: .regular))
            }
            barItem.menu.addItem(entry)
        }
    }

    private func renderWifi() {
        guard let barItem = items[.wifi], let button = barItem.button else { return }
        button.image = Self.symbol(model.wifiOn ? "wifi" : "wifi.slash")
        guard !barItem.menuOpen else { return }
        barItem.menu.removeAllItems()

        let wifiDetail = model.wifiOn
            ? (model.wifiName.isEmpty ? "Wi-Fi: On" : "Wi-Fi: On · \(model.wifiName)")
            : "Wi-Fi: Off"
        let header = NSMenuItem(title: wifiDetail, action: nil, keyEquivalent: "")
        header.isEnabled = false
        barItem.menu.addItem(header)

        let toggle = NSMenuItem(title: model.wifiOn ? "Turn Wi-Fi Off" : "Turn Wi-Fi On", action: #selector(toggleWifi(_:)), keyEquivalent: "")
        toggle.target = self
        barItem.menu.addItem(toggle)

        let settingsItem = NSMenuItem(title: "Wi-Fi Settings…", action: #selector(openWifiSettings(_:)), keyEquivalent: "")
        settingsItem.target = self
        barItem.menu.addItem(settingsItem)
    }

    private func renderBattery() {
        guard let barItem = items[.battery], let button = barItem.button else { return }
        button.title = model.batteryText
        button.image = model.charging ? Self.symbol("bolt.fill") : nil
        guard !barItem.menuOpen else { return }
        barItem.menu.removeAllItems()

        let detail = model.charging
            ? "Battery — \(model.batteryText) · Charging"
            : "Battery — \(model.batteryText)"
        let header = NSMenuItem(title: detail, action: nil, keyEquivalent: "")
        header.isEnabled = false
        barItem.menu.addItem(header)

        let settingsItem = NSMenuItem(title: "Battery Settings…", action: #selector(openBatterySettings(_:)), keyEquivalent: "")
        settingsItem.target = self
        barItem.menu.addItem(settingsItem)
    }

    private func renderVolume() {
        guard let barItem = items[.volume], let button = barItem.button else { return }
        button.title = "\(model.volume)%"
        let level: String
        switch model.volume {
        case ..<34: level = "speaker.wave.1.fill"
        case ..<67: level = "speaker.wave.2.fill"
        default:    level = "speaker.wave.3.fill"
        }
        button.image = Self.symbol(model.muted ? "speaker.slash.fill" : level)
        guard !barItem.menuOpen else { return }
        barItem.menu.removeAllItems()

        let toggle = NSMenuItem(title: model.muted ? "Unmute" : "Mute", action: #selector(toggleMute(_:)), keyEquivalent: "")
        toggle.target = self
        toggle.state = model.muted ? .on : .off
        barItem.menu.addItem(toggle)

        let settingsItem = NSMenuItem(title: "Sound Settings…", action: #selector(openSoundSettings(_:)), keyEquivalent: "")
        settingsItem.target = self
        barItem.menu.addItem(settingsItem)
    }

    private func renderClock() {
        guard let barItem = items[.clock], let button = barItem.button else { return }
        button.title = model.timeString
        button.image = Self.symbol("clock")
    }

    // MARK: - Actions (status item clicks / menu commands)

    /// Clock: left-click opens Calendar; right-click opens the clock settings menu.
    @objc private func clockClicked(_ sender: NSStatusBarButton) {
        let settingsMenu = NSMenu()
        let calendar = NSMenuItem(title: "Open Calendar", action: #selector(openCalendar(_:)), keyEquivalent: "")
        calendar.target = self
        settingsMenu.addItem(calendar)
        let prefs = NSMenuItem(title: "Date & Time Settings…", action: #selector(openDateTimeSettings(_:)), keyEquivalent: "")
        prefs.target = self
        settingsMenu.addItem(prefs)

        if NSApp.currentEvent?.type == .rightMouseUp {
            settingsMenu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        } else {
            openCalendar(sender)
        }
    }

    @objc private func activateApp(_ sender: NSMenuItem) {
        guard let pid = (sender.representedObject as? NSNumber)?.int32Value else { return }
        NSRunningApplication(processIdentifier: pid)?.activate()
    }

    @objc private func toggleWifi(_ sender: NSMenuItem) { model.toggleWifi() }
    @objc private func toggleMute(_ sender: NSMenuItem) { model.toggleMute() }

    @objc private func openWifiSettings(_ sender: NSMenuItem) { openSystemSettingsPane("com.apple.settings.Wi-Fi") }
    @objc private func openBatterySettings(_ sender: NSMenuItem) { openSystemSettingsPane("com.apple.settings.Battery") }
    @objc private func openSoundSettings(_ sender: NSMenuItem) { openSystemSettingsPane("com.apple.settings.Sound") }
    @objc private func openDateTimeSettings(_ sender: NSMenuItem) { openSystemSettingsPane("com.apple.settings.DateTime") }
    @objc private func openCalendar(_ sender: AnyObject) { NSWorkspace.shared.open(URL(string: "ical://")!) }

    private func openSystemSettingsPane(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}