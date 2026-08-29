// Modules/Omatiles/OmatilesEngine.swift
// The native SwiftUI/AppKit window tiling engine. Enumerates on-screen windows via
// CGWindowList, computes a layout, and repositions them through the Accessibility API.
// Runs either as a standalone module process ("--omatiles") or inside the GUI.
//
// Keyboard bindings (when `omanix.omatiles.bindings` is enabled):
//   ⌘⌥T  tile now      ⌘⌥J  focus previous    ⌘⌥K  focus next    ⌘⌥L  cycle layout

import Foundation
import AppKit
import CoreGraphics
import ApplicationServices

@MainActor
final class OmatilesEngine: ObservableObject {

    static let shared = OmatilesEngine()

    @Published private(set) var isRunning = false
    @Published private(set) var tiledCount = 0
    @Published private(set) var activeLayout = "tiles"

    private var settings: RuntimeSettings.Omatiles = .load()
    private var watchTimer: Timer?
    private var viewMonitor: Any?
    private var lastSignature = ""
    private var appliedSettingsKey = ""

    private init() {}

    // MARK: - Lifecycle

    /// Starts the engine. Prompts for Accessibility once (only when interactively launched).
    func start(settings: RuntimeSettings.Omatiles = RuntimeSettings.Omatiles.load()) {
        self.settings = settings
        activeLayout = settings.layout
        isRunning = true
        if settings.bindings { installHotkeys() }
        if settings.watch { startWatch() }
        appliedSettingsKey = settingsKey()
        tile()
        installViewMonitor()
    }

    /// Applies new declarative settings to a running engine (no rebuild needed).
    func apply(settings: RuntimeSettings.Omatiles) {
        let wasRunning = isRunning
        let bindingsChanged = settings.bindings != self.settings.bindings
        let watchChanged = settings.watch != self.settings.watch
        self.settings = settings
        activeLayout = settings.layout

        if bindingsChanged {
            removeHotkeys()
            if settings.bindings { installHotkeys() }
        }
        if watchChanged {
            stopWatch()
            if settings.watch { startWatch() }
        }
        if wasRunning, settingsKey() != appliedSettingsKey {
            appliedSettingsKey = settingsKey()
            tile()
        }
    }

    func stop() {
        isRunning = false
        removeHotkeys()
        stopWatch()
        removeViewMonitor()
    }

    private func settingsKey() -> String {
        "\(settings.layout)|\(settings.gapInner)|\(settings.gapOuter)"
    }

    // MARK: - Accessibility

    /// True if the Accessibility permission is granted; otherwise prompts (once).
    /// The prompt is only shown when this app is frontmost, so launchd autostart
    /// never bothers the user on login.
    @discardableResult
    static func ensureAccessibility() -> Bool {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            let isFrontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier
                == ProcessInfo.processInfo.processIdentifier
            if isFrontmost {
                nsPromptForAccessibility()
            }
        }
        return AXIsProcessTrusted()
    }

    private static func nsPromptForAccessibility() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }

    // MARK: - Tiling

    /// Re-tiles everything on the current space (⌘⌥T / "Tile now").
    func tile() {
        guard isRunning else { return }
        guard AXIsProcessTrusted() else {
            _ = Self.ensureAccessibility()
            return
        }

        let candidates = tilingCandidates()
        let workArea = visibleScreenArea()
        guard !candidates.isEmpty, !workArea.isEmpty else {
            tiledCount = 0
            return
        }

        let frames = OmatilesLayouts.compute(
            layout: settings.layout,
            count: candidates.count,
            workArea: workArea,
            gapInner: CGFloat(settings.gapInner)
        )

        var applied = 0
        for (i, candidate) in candidates.enumerated() where i < frames.count {
            if setAXFrame(for: candidate, to: frames[i]) { applied += 1 }
        }
        tiledCount = applied
    }

    // MARK: - Window enumeration

    private struct Candidate {
        let pid: pid_t
        let owner: String
        let windowID: CGWindowID
    }

    /// On-screen windows eligible for tiling (skips floating bundle IDs + own process).
    private func tilingCandidates() -> [Candidate] {
        let floats = Set(settings.floatingApps.map { $0.lowercased() })
        var result: [Candidate] = []
        for win in Desktop.snapshot() {
            let bundleID = NSRunningApplication(processIdentifier: win.pid)?.bundleIdentifier?.lowercased()
            if let bundleID, floats.contains(bundleID) { continue }
            result.append(Candidate(pid: win.pid, owner: win.owner, windowID: win.number))
        }
        return result
    }

    /// Area inside the screen edges AND under (or above) the Omabar when it is enabled.
    private func visibleScreenArea() -> CGRect {
        guard let screen = NSScreen.main else { return .zero }
        var area = screen.frame.insetBy(
            dx: CGFloat(settings.gapOuter),
            dy: CGFloat(settings.gapOuter)
        )
        let bar = RuntimeSettings.Omabar.load()
        if bar.enable {
            let h = CGFloat(bar.height)
            if bar.position == "top" {
                area.origin.y += h
                area.size.height -= h
            } else {
                area.size.height -= h
            }
        }
        return area.standardized
    }

    // MARK: - Accessibility window moves

    /// Positions a candidate's front-most AX window. Returns false when the move failed.
    private func setAXFrame(for candidate: Candidate, to frame: CGRect) -> Bool {
        let app = AXUIElementCreateApplication(candidate.pid)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement],
              let window = windows.first
        else { return false }

        var point = CGPoint(x: frame.minX, y: frame.minY)
        var size = CGSize(width: frame.width, height: frame.height)
        guard let posValue = AXValueCreate(.cgPoint, &point),
              let sizeValue = AXValueCreate(.cgSize, &size)
        else { return false }

        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        return true
    }

    // MARK: - Focus (⌘⌥J / ⌘⌥K)

    func focusNext() { cycleFocus(step: 1) }
    func focusPrevious() { cycleFocus(step: -1) }

    private func cycleFocus(step: Int) {
        guard AXIsProcessTrusted() else { return }
        let candidates = tilingCandidates()
        guard !candidates.isEmpty else { return }

        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1
        var index = candidates.firstIndex { $0.pid == frontPID } ?? -1
        index = (index + step + candidates.count) % candidates.count
        let target = candidates[index]

        NSRunningApplication(processIdentifier: target.pid)?.activate()
        let app = AXUIElementCreateApplication(target.pid)
        var windowsRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef) == .success,
           let windows = windowsRef as? [AXUIElement],
           let window = windows.first {
            AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        }
    }

    // MARK: - Layout cycle (⌘⌥L)

    func cycleLayout() {
        settings.layout = OmatilesLayout.cycle(from: settings.layout)
        activeLayout = settings.layout
        appliedSettingsKey = settingsKey()
        tile()
    }

    // MARK: - Watch mode

    private func startWatch() {
        guard watchTimer == nil else { return }
        watchTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.watchTick() }
        }
    }

    private func stopWatch() {
        watchTimer?.invalidate()
        watchTimer = nil
        lastSignature = ""
    }

    /// Re-tiles when the set of on-screen candidate windows changes.
    private func watchTick() {
        guard isRunning, AXIsProcessTrusted() else { return }
        let sig = tilingCandidates().map { "\($0.pid):\($0.windowID)" }.joined(separator: ",")
        if sig != lastSignature {
            lastSignature = sig
            tile()
        }
    }

    // MARK: - Keyboard bindings

    private func installHotkeys() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard mods.contains(.command), mods.contains(.option),
                  !mods.contains(.control), !mods.contains(.shift)
            else { return }
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "t": Task { @MainActor in self.tile() }
            case "j": Task { @MainActor in self.focusPrevious() }
            case "k": Task { @MainActor in self.focusNext() }
            case "l": Task { @MainActor in self.cycleLayout() }
            default: break
            }
        }
    }

    private func removeHotkeys() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private var keyMonitor: Any?

    // MARK: - Screen changes

    private func installViewMonitor() {
        guard viewMonitor == nil else { return }
        viewMonitor = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.tile() }
        }
    }

    private func removeViewMonitor() {
        if let viewMonitor {
            NotificationCenter.default.removeObserver(viewMonitor)
            self.viewMonitor = nil
        }
    }
}