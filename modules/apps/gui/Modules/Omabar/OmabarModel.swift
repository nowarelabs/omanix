// Modules/Omabar/OmabarModel.swift
// Omabar content model: clock, battery (pmset), volume (osascript, click-to-mute),
// Wi-Fi (networksetup), frontmost app, and the on-screen app list used for workspace
// pills. Foundation/AppKit only.
//
// All shell work runs OFF the main actor (Task.detached) so the bar never hitches
// on pmset/osascript/networksetup; results are published back on the main actor.

import Foundation
import AppKit
import Combine

@MainActor
final class OmabarModel: ObservableObject {

    @Published var now = Date()
    @Published var batteryText = "—"
    @Published var charging = false
    @Published var volume = 60
    @Published var muted = false
    @Published var wifiName = ""
    @Published var wifiOn = true
    @Published var frontAppName = ""
    @Published var frontAppIcon = NSImage()
    @Published var visibleApps: [VisibleApp] = []
    @Published var palette = RuntimeSettings.Palette.load()

    /// An on-screen app pill (deduped by pid).
    struct VisibleApp: Identifiable {
        let pid: pid_t
        let name: String
        var isFocused = false
        var id: pid_t { pid }
    }

    private var clockTimer: Timer?
    private var pollTimer: Timer?
    private var windowsTimer: Timer?
    private var workspacesObserver: NSObjectProtocol?
    private var lastPollSoon = false

    func start() {
        refreshAll()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.now = Date()
            }
        }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshBattery()
                self?.refreshWifi()
                self?.refreshVolume()
                self?.refreshPalette()
            }
        }
        windowsTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshWindows() }
        }
        workspacesObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshFrontApp(); self?.refreshWindows() }
        }
    }

    func stop() {
        clockTimer?.invalidate(); clockTimer = nil
        pollTimer?.invalidate(); pollTimer = nil
        windowsTimer?.invalidate(); windowsTimer = nil
        if let workspacesObserver {
            NotificationCenter.default.removeObserver(workspacesObserver)
            self.workspacesObserver = nil
        }
    }

    func refreshAll() {
        refreshFrontApp()
        refreshWindows()
        refreshBattery()
        refreshVolume()
        refreshWifi()
        refreshPalette()
    }

    /// Reloads the active theme palette (rare — called on bar apply + slow poll).
    func refreshPalette() {
        palette = RuntimeSettings.Palette.load()
    }

    // MARK: - Frontmost app

    func refreshFrontApp() {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            frontAppName = ""
            frontAppIcon = NSImage()
            markFocusedPill()
            return
        }
        frontAppName = app.localizedName ?? ""
        frontAppIcon = app.icon ?? NSImage()
        markFocusedPill()
    }

    // MARK: - App pills (workspaces overview)

    func refreshWindows() {
        let apps = Desktop.visibleApps()
        visibleApps = apps.map { app in
            VisibleApp(pid: app.pid, name: app.name, isFocused: app.name == frontAppName)
        }
    }

    private func markFocusedPill() {
        for index in visibleApps.indices {
            visibleApps[index].isFocused = visibleApps[index].name == frontAppName
        }
    }

    /// Activates the running app behind a pill (Reef-style refocus).
    func activate(_ app: VisibleApp) {
        NSRunningApplication(processIdentifier: app.pid)?.activate()
    }

    // MARK: - Battery

    func refreshBattery() {
        Task { @MainActor [weak self] in
            let out = await Self.shell("/usr/bin/pmset", ["-g", "batt"])
            guard let self, !Task.isCancelled else { return }
            guard let rawLine = out.split(separator: "\n").first(where: { $0.contains("%") }) else {
                batteryText = "—"
                charging = false
                return
            }
            let line = String(rawLine).replacingOccurrences(of: "\t", with: " ")
            guard let token = line.split(separator: " ").first(where: { $0.hasSuffix("%") }) else {
                batteryText = "—"
                charging = false
                return
            }
            if let pct = Int(token.dropLast()) {
                batteryText = "\(pct)%"
            }
            charging = line.contains("charging") || line.contains("AC attached")
            if line.contains("charged") { batteryText = "100%" }
        }
    }

    // MARK: - Volume

    func refreshVolume() {
        Task { @MainActor [weak self] in
            guard let self, !Task.isCancelled else { return }
            let vol = await Self.shell("/usr/bin/osascript", ["-e", "output volume of (get volume settings)"])
            if let parsed = Int(vol.trimmingCharacters(in: .whitespacesAndNewlines)) {
                volume = parsed
            }
            let m = await Self.shell("/usr/bin/osascript", ["-e", "output muted of (get volume settings)"])
            muted = m.contains("true")
        }
    }

    /// Click-to-mute / unmute (async so the bar doesn't hitch).
    func toggleMute() {
        let next = muted
        muted = !next
        Task { @MainActor in
            await Self.shell("/usr/bin/osascript", ["-e", "set volume output muted to \(next ? "false" : "true")"])
        }
    }

    // MARK: - Wi-Fi

    func refreshWifi() {
        Task { @MainActor [weak self] in
            guard let self, !Task.isCancelled else { return }
            var name = ""
            var power = true
            for interface in ["en0", "en1"] {
                let powerOut = await Self.shell("/usr/sbin/networksetup", ["-getairportpower", interface])
                if powerOut.lowercased().contains("on") {
                    power = true
                    let out = await Self.shell("/usr/sbin/networksetup", ["-getairportnetwork", interface])
                    if let line = out.split(separator: "\n").first(where: { $0.contains("Current Wi-Fi Network:") }), !line.isEmpty {
                        if let colon = line.firstIndex(of: ":") {
                            let tail = line[line.index(after: colon)...].trimmingCharacters(in: .whitespacesAndNewlines)
                            if !tail.isEmpty { name = String(tail); break }
                        }
                    }
                } else if powerOut.lowercased().contains("off") {
                    power = false
                }
            }
            wifiName = name
            wifiOn = power
        }
    }

    /// Toggles Wi-Fi power off/on via networksetup.
    func toggleWifi() {
        let nowOn = wifiOn
        Task { @MainActor in
            _ = await Self.shell("/usr/sbin/networksetup", ["-setairportpower", "en0", nowOn ? "off" : "on"])
            refreshWifi()
        }
    }

    // MARK: - Time formatting

    var timeString: String {
        Self.timeFormatter.string(from: now)
    }

    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM  HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    // MARK: - Shell helper (off the main actor)

    /// Runs a command detached so no status poll ever blocks the bar. The outer
    /// method may be actor-isolated; that only costs a brief setup hop — the pipe
    /// I/O and wait all happen on a utility priority task.
    static func shell(_ executable: String, _ arguments: [String]) async -> String {
        await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            do { try process.run() } catch { return "" }
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        }.value
    }
}