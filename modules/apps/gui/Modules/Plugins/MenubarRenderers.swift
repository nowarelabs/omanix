// Modules/Plugins/MenubarRenderers.swift
// Concrete menu bar renderers for the built-in plugins. Each renderer owns one or
// more NSStatusItems (created via the host) and re-pushes values via refresh().
// These are deliberately self-contained so a plugin author can copy one and adapt it.

import AppKit
import Combine

// MARK: - Shared shell helper (off the main thread)

enum PluginShell {
    /// Runs a command and returns its combined stdout+stderr. Blocking; keep for
    /// short, infrequent pollers. Rendering into a status button is quick, so a
    /// short semaphore wait here is fine.
    static func run(_ executable: String, _ arguments: [String]) -> String {
        let semaphore = DispatchSemaphore(value: 0)
        let result: Box<String> = Box("")
        Task.detached {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: executable)
            p.arguments = arguments
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = pipe
            do { try p.run() } catch { result.value = ""; semaphore.signal(); return }
            p.waitUntilExit()
            result.value = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            semaphore.signal()
        }
        semaphore.wait()
        return result.value
    }

    private final class Box<T> {
        var value: T
        init(_ value: T) { self.value = value }
    }
}

private func templateImage(_ name: String) -> NSImage? {
    let img = NSImage(systemSymbolName: name, accessibilityDescription: name)
    img?.isTemplate = true
    return img
}

private func openSettingsPane(_ pane: String) {
    if let url = URL(string: "x-apple.systempreferences:\(pane)") {
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Clock

final class ClockRenderer: OmanixMenubarRenderer {
    private var item: NSStatusItem?
    weak var host: (any OmanixMenubarHost)?
    private var eventToken: AnyObject?

    var primaryAction: Selector? { nil }
    var actionTarget: AnyObject? { self }

    func install(into manager: any OmanixMenubarHost) {
        host = manager
        let status = manager.makeStatusItem(menuable: false)
        status.button?.target = self
        status.button?.action = #selector(clockClicked(_:))
        status.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        item = status
        eventToken = SystemEvents.observeClock { [weak self] date in
            self?.render(date: date)
        }
    }

    func refresh() {
        render(date: Date())
    }

    private func render(date: Date) {
        let prefs = PluginStore.shared.menuBarPrefs()
        item?.button?.image = nil

        if prefs.clockFormat == "analog" {
            item?.button?.title = ""
            item?.button?.image = templateImage("clock")
            item?.button?.toolTip = dateString(prefs: prefs, date: date)
            return
        }

        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        if prefs.use24Hour {
            f.dateFormat = prefs.showDate ? "EEE d MMM  HH:mm" : "HH:mm"
        } else {
            f.dateFormat = prefs.showDate ? "EEE d MMM  h:mm a" : "h:mm a"
        }
        item?.button?.title = f.string(from: date)
        item?.button?.toolTip = dateString(prefs: prefs, date: date)
    }

    private func dateString(prefs: MenubarPrefs, date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = prefs.showDate ? "EEEE, MMMM d" : "EEEE, MMMM d, yyyy"
        return f.string(from: date)
    }

    func uninstall() {
        if let token = eventToken {
            SystemEvents.unobserveClock(token)
            eventToken = nil
        }
        if let item { NSStatusBar.system.removeStatusItem(item) }
        item = nil
    }

    @objc private func clockClicked(_ sender: NSStatusBarButton) {
        let menu = NSMenu()
        let calendar = NSMenuItem(title: "Open Calendar", action: #selector(openCalendar), keyEquivalent: "")
        calendar.target = self
        menu.addItem(calendar)
        let prefs = NSMenuItem(title: "Date & Time Settings…", action: #selector(openDateTime), keyEquivalent: "")
        prefs.target = self
        menu.addItem(prefs)
        if NSApp.currentEvent?.type == .rightMouseUp {
            menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        } else {
            openCalendar()
        }
    }

    @objc private func openCalendar() { NSWorkspace.shared.open(URL(string: "ical://")!) }
    @objc private func openDateTime() { openSettingsPane("com.apple.settings.DateTime") }
}

// MARK: - Battery

final class BatteryRenderer: OmanixMenubarRenderer {
    private var item: NSStatusItem?
    weak var host: (any OmanixMenubarHost)?
    private var percent = -1
    private var charging = false
    private var onAC = false
    private var eventToken: AnyObject?

    var primaryAction: Selector? { nil }
    var actionTarget: AnyObject? { self }

    func install(into manager: any OmanixMenubarHost) {
        host = manager
        let status = manager.makeStatusItem(menuable: false)
        status.button?.target = self
        status.button?.action = #selector(openMenu(_:))
        status.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        item = status
        eventToken = SystemEvents.observeBattery { [weak self] state in
            self?.render(state)
        }
    }

    func refresh() {
        render(BatteryMonitor.shared.readState())
    }

    func uninstall() {
        if let token = eventToken {
            SystemEvents.unobserveBattery(token)
            eventToken = nil
        }
        if let item { NSStatusBar.system.removeStatusItem(item) }
        item = nil
    }

    private func render(_ state: BatteryState) {
        percent = state.percent
        charging = state.charging
        onAC = state.onAC
        let text: String
        if state.percent < 0 {
            text = "—"
        } else if state.onAC && !state.charging {
            text = "100%"
        } else {
            text = "\(max(0, state.percent))%"
        }
        let showPercent = PluginStore.shared.menuBarPrefs().showBatteryPercent
        item?.button?.image = templateImage(charging ? "bolt.fill" : "battery.75percent")
        item?.button?.title = showPercent ? text : ""
        item?.button?.toolTip = "Battery \(text)\(charging ? " — charging" : "")"
    }

    @objc private func openMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()
        let text = percent < 0 ? "—" : "\(max(0, percent))%"
        let header = NSMenuItem(title: "Battery — \(text)", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        let prefs = NSMenuItem(title: "Battery Settings…", action: #selector(openBattery), keyEquivalent: "")
        prefs.target = self
        menu.addItem(prefs)
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    @objc private func openBattery() { openSettingsPane("com.apple.settings.Battery") }
}

// MARK: - Volume

final class VolumeRenderer: OmanixMenubarRenderer {
    private var item: NSStatusItem?
    weak var host: (any OmanixMenubarHost)?
    private var volume = 60
    private var muted = false

    /// CoreAudio event subscription (keeps the renderer in sync with hardware
    /// volume/mute keys via native property listeners — no polling, no shell).
    private var eventToken: AnyObject?

    var primaryAction: Selector? { nil }
    var actionTarget: AnyObject? { self }

    func install(into manager: any OmanixMenubarHost) {
        host = manager
        let status = manager.makeStatusItem(menuable: false)
        status.button?.target = self
        status.button?.action = #selector(openMenu(_:))
        status.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        item = status
        // Subscribe before drawing; observeVolume delivers an initial sample
        // immediately, so the icon/title are correct right away.
        eventToken = SystemEvents.observeVolume { [weak self] state in
            self?.render(volume: state.volume, muted: state.muted)
        }
    }

    func refresh() {
        render(volume: volume, muted: muted)
    }

    func uninstall() {
        if let token = eventToken {
            SystemEvents.unobserveVolume(token)
            eventToken = nil
        }
        if let item { NSStatusBar.system.removeStatusItem(item) }
        item = nil
    }

    /// Draws the status item for a known (volume, muted) pair.
    private func render(volume: Int, muted: Bool) {
        self.volume = volume
        self.muted = muted
        let level: String
        switch volume {
        case ..<34: level = "speaker.wave.1.fill"
        case ..<67: level = "speaker.wave.2.fill"
        default:    level = "speaker.wave.3.fill"
        }
        item?.button?.image = templateImage(muted ? "speaker.slash.fill" : level)
        let showText = RuntimeSettings.Omabar.load().showVolumeText
        item?.button?.title = showText ? "\(volume)%" : ""
    }

    @objc private func openMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()
        let toggle = NSMenuItem(title: muted ? "Unmute" : "Mute", action: #selector(toggleMute), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Sound Settings…", action: #selector(openSound), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    @objc private func toggleMute() {
        SystemEvents.setVolumeMuted(!muted)
    }
    @objc private func openSound() { openSettingsPane("com.apple.settings.Sound") }
}

// MARK: - Wi-Fi

final class WifiRenderer: OmanixMenubarRenderer {
    private var item: NSStatusItem?
    weak var host: (any OmanixMenubarHost)?
    private var on = true
    private var name = ""
    private var eventToken: AnyObject?

    var primaryAction: Selector? { nil }
    var actionTarget: AnyObject? { self }

    func install(into manager: any OmanixMenubarHost) {
        host = manager
        let status = manager.makeStatusItem(menuable: false)
        status.button?.target = self
        status.button?.action = #selector(openMenu(_:))
        status.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        item = status
        eventToken = SystemEvents.observeWifi { [weak self] state in
            self?.render(state)
        }
    }

    func refresh() {
        render(WifiMonitor.shared.readState())
    }

    func uninstall() {
        if let token = eventToken {
            SystemEvents.unobserveWifi(token)
            eventToken = nil
        }
        if let item { NSStatusBar.system.removeStatusItem(item) }
        item = nil
    }

    private func render(_ state: WifiState) {
        on = state.powerOn
        name = state.ssid
        item?.button?.image = templateImage(on ? "wifi" : "wifi.slash")
        item?.button?.toolTip = on ? (name.isEmpty ? "Wi-Fi: On" : "Wi-Fi: \(name)") : "Wi-Fi: Off"
    }

    @objc private func openMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()
        let header = NSMenuItem(title: on ? (name.isEmpty ? "Wi-Fi: On" : "Wi-Fi: On · \(name)") : "Wi-Fi: Off", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        let toggle = NSMenuItem(title: on ? "Turn Wi-Fi Off" : "Turn Wi-Fi On", action: #selector(toggleWifi), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Wi-Fi Settings…", action: #selector(openWifi), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    @objc private func toggleWifi() {
        SystemEvents.setWifiPowerOn(!on)
    }
    @objc private func openWifi() { openSettingsPane("com.apple.settings.Wi-Fi") }
}

// MARK: - Running Apps

final class AppsRenderer: OmanixMenubarRenderer {
    private var item: NSStatusItem?
    weak var host: (any OmanixMenubarHost)?
    private var apps: [(pid: pid_t, name: String)] = []

    var primaryAction: Selector? { nil }
    var actionTarget: AnyObject? { self }

    func install(into manager: any OmanixMenubarHost) {
        host = manager
        let status = manager.makeStatusItem(menuable: true)
        status.button?.target = self
        status.button?.action = nil
        item = status
        refresh()
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        apps = Desktop.visibleApps().map { (pid: $0.pid, name: $0.name) }
        item?.button?.image = templateImage("square.grid.2x2")
        guard let menu = item?.menu else { return }
        menu.removeAllItems()
        let header = NSMenuItem(title: "Running Apps", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        if apps.isEmpty {
            menu.addItem(NSMenuItem(title: "No windows visible", action: nil, keyEquivalent: ""))
            return
        }
        for app in apps {
            let entry = NSMenuItem(title: app.name, action: #selector(activateApp(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = NSNumber(value: app.pid)
            menu.addItem(entry)
        }
    }

    func uninstall() {
        if let item { NSStatusBar.system.removeStatusItem(item) }
        item = nil
    }

    @objc private func activateApp(_ sender: NSMenuItem) {
        guard let pid = (sender.representedObject as? NSNumber)?.int32Value else { return }
        NSRunningApplication(processIdentifier: pid)?.activate()
    }
}

// MARK: - Focus (Do Not Disturb)

final class FocusRenderer: OmanixMenubarRenderer {
    private var item: NSStatusItem?
    weak var host: (any OmanixMenubarHost)?
    private var focused = false

    var primaryAction: Selector? { #selector(toggle(_:)) }
    var actionTarget: AnyObject? { self }

    func install(into manager: any OmanixMenubarHost) {
        host = manager
        let status = manager.makeStatusItem(menuable: false)
        status.button?.target = self
        status.button?.action = primaryAction
        item = status
        refresh()
    }

    func refresh() {
        // Approximation: unread indicator unavailable without notification permission.
        item?.button?.image = templateImage(focused ? "moon.fill" : "moon")
        item?.button?.toolTip = focused ? "Focus on" : "Focus off"
    }

    @objc private func toggle(_ sender: NSStatusBarButton) {
        focused.toggle()
        refresh()
    }

    /// Focus (Do Not Disturb) is toggled per-focus via System Settings's /Focus.
    private func openFocus() { openSettingsPane("com.apple.preference.notifications") }
    func uninstall() {
        if let item { NSStatusBar.system.removeStatusItem(item) }
        item = nil
    }
}

// MARK: - Now Playing

final class NowPlayingRenderer: OmanixMenubarRenderer {
    private var item: NSStatusItem?
    weak var host: (any OmanixMenubarHost)?
    private var title = "No media"

    var primaryAction: Selector? { nil }
    var actionTarget: AnyObject? { self }

    func install(into manager: any OmanixMenubarHost) {
        host = manager
        let status = manager.makeStatusItem(menuable: false)
        status.button?.target = self
        status.button?.action = #selector(focus(_:))
        status.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        item = status
        refresh()
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        // Lightweight: query Music/TV when running, else fall back to "No media".
        let script = """
        if application "Music" is running then
            tell application "Music"
                if player state is playing then
                    return "♫ " & (name of current track as text)
                end if
            end tell
        end if
        return ""
        """
        let out = PluginShell.run("/usr/bin/osascript", ["-e", script]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !out.isEmpty {
            title = out
            item?.button?.title = out
            item?.button?.image = templateImage("music.note")
        } else {
            title = ""
            item?.button?.title = ""
            item?.button?.image = templateImage("music.note")
        }
    }

    @objc private func focus(_ sender: NSStatusBarButton) {
        let menu = NSMenu()
        let header = NSMenuItem(title: title.isEmpty ? "No media playing" : title, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())
        let openMusic = NSMenuItem(title: "Open Music", action: #selector(openMusic), keyEquivalent: "")
        openMusic.target = self
        menu.addItem(openMusic)
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    @objc private func openMusic() {
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/System/Applications/Music.app"), configuration: NSWorkspace.OpenConfiguration())
    }

    func uninstall() {
        if let item { NSStatusBar.system.removeStatusItem(item) }
        item = nil
    }
}

// MARK: - Clipboard

final class ClipboardRenderer: OmanixMenubarRenderer {
    private var item: NSStatusItem?
    weak var host: (any OmanixMenubarHost)?
    private var history: [String] = []
    private var lastChange: Int = -1

    var primaryAction: Selector? { nil }
    var actionTarget: AnyObject? { self }

    func install(into manager: any OmanixMenubarHost) {
        host = manager
        let status = manager.makeStatusItem(menuable: false)
        status.button?.target = self
        status.button?.action = #selector(openMenu(_:))
        item = status
        refresh()
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        let pb = NSPasteboard.general
        let change = pb.changeCount
        guard change != lastChange else { return }
        lastChange = change
        if let s = pb.string(forType: .string), !s.isEmpty {
            history.insert(s, at: 0)
            if history.count > 8 { history = Array(history.prefix(8)) }
        }
        item?.button?.title = "\(history.count)"
        item?.button?.image = templateImage("doc.on.clipboard")
    }

    @objc private func openMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()
        let header = NSMenuItem(title: "Clipboard", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        if history.isEmpty {
            menu.addItem(NSMenuItem(title: "Nothing copied yet", action: nil, keyEquivalent: ""))
        } else {
            for snippet in history.prefix(5) {
                let preview = snippet.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
                let label = String(preview.prefix(30))
                let entry = NSMenuItem(title: label.isEmpty ? "(image)" : label, action: #selector(copy(_:)), keyEquivalent: "")
                entry.target = self
                entry.representedObject = snippet
                menu.addItem(entry)
            }
        }
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    @objc private func copy(_ sender: NSMenuItem) {
        guard let s = sender.representedObject as? String else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }

    func uninstall() {
        if let item { NSStatusBar.system.removeStatusItem(item) }
        item = nil
    }
}
