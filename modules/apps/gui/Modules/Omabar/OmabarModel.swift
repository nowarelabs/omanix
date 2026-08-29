// Modules/Omabar/OmabarModel.swift
// Omabar content model: clock, battery (pmset), volume (osascript, click-to-mute),
// Wi-Fi (networksetup), frontmost app, and the on-screen app list used for workspace
// pills. Foundation/AppKit only — polls on a cadence, publishes for SwiftUI.

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
    @Published var frontAppName = ""
    @Published var frontAppIcon = NSImage()
    @Published var visibleApps: [(name: String, isFocused: Bool)] = []

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
            Task { @MainActor in self?.refreshBattery(); self?.refreshWifi() }
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
    }

    // MARK: - Frontmost app

    func refreshFrontApp() {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            frontAppName = ""
            frontAppIcon = NSImage()
            return
        }
        frontAppName = app.localizedName ?? ""
        frontAppIcon = app.icon ?? NSImage()
    }

    // MARK: - App pills (workspaces overview)

    func refreshWindows() {
        let names = Desktop.visibleAppNames()
        visibleApps = names.map { (name: $0, isFocused: $0 == frontAppName) }
    }

    // MARK: - Battery

    func refreshBattery() {
        let out = run("/usr/bin/pmset", ["-g", "batt"])
        guard let line = out.split(separator: "\n").first(where: { $0.contains("%") }) else {
            batteryText = "—"
            charging = false
            return
        }
        guard let pctStr = line.replacingOccurrences(of: "\t", with: " ")
            .split(separator: " ")
            .first(where: { $0.hasSuffix("%") }) else {
            batteryText = "—"
            charging = false
            return
        }
        let pct = Int(pctStr.dropLast()) ?? 0
        batteryText = "\(pct)%"
        charging = line.contains("charging") || line.contains("AC attached")
        if line.contains("charged") { batteryText = "100%" }
    }

    // MARK: - Volume

    func refreshVolume() {
        let vol = run("/usr/bin/osascript", ["-e", "output volume of (get volume settings)"])
        volume = Int(vol.trimmingCharacters(in: .whitespacesAndNewlines)) ?? volume
        let m = run("/usr/bin/osascript", ["-e", "output muted of (get volume settings)"])
        muted = m.contains("true")
    }

    /// Click-to-mute / unmute.
    func toggleMute() {
        let next = muted
        _ = run("/usr/bin/osascript", ["-e", "set volume output muted to \(next ? "false" : "true")"])
        muted = !next
    }

    // MARK: - Wi-Fi

    func refreshWifi() {
        var name = ""
        for iface in ["en0", "en1"] {
            let out = run("/usr/sbin/networksetup", ["-getairportnetwork", iface])
            if let line = out.split(separator: "\n").first(where: { $0.contains("Current Wi-Fi Network:") }), !line.isEmpty {
                if let colon = line.firstIndex(of: ":") {
                    let tail = line[line.index(after: colon)...].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !tail.isEmpty { name = String(tail); break }
                }
            }
        }
        wifiName = name
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

    // MARK: - Process helper

    private func run(_ executable: String, _ arguments: [String]) -> String {
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
    }
}