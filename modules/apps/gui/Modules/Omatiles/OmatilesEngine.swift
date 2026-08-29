// Modules/Omatiles/OmatilesEngine.swift
// The native SwiftUI/AppKit window tiling engine. Enumerates on-screen windows via
// CGWindowList, computes a layout, and repositions them through the Accessibility API.
// Runs either as a standalone module process ("--omatiles") or inside the GUI.
//
// Correctness notes:
//  - Every on-screen CGWindow is matched to its exact AX window via
//    _AXUIElementGetWindow, so multi-window apps tile each window precisely
//    (an app's AX "windows.first" is NOT the same as the on-screen set).
//  - Candidates are grouped by the screen they occupy; the work area is computed
//    per monitor (and drops the Omabar height only on the bar's screen).
//  - Watch mode is event-driven: space/app/window changes re-tile instantly,
//    with a slow fallback poll for invisible changes.
//  - Bindings use Carbon RegisterEventHotKey so ⌘⌥T/J/K/L are consumed and never
//    leak into the frontmost app.
//
// Keyboard bindings (when `omanix.omatiles.bindings` is enabled):
//   ⌘⌥T  tile now      ⌘⌥J  focus previous    ⌘⌥K  focus next    ⌘⌥L  cycle layout

import Foundation
import AppKit
import CoreGraphics
import ApplicationServices
import Carbon.HIToolbox

@MainActor
final class OmatilesEngine: ObservableObject {

    static let shared = OmatilesEngine()

    @Published private(set) var isRunning = false
    @Published private(set) var tiledCount = 0
    @Published private(set) var activeLayout = "tiles"

    private var settings: RuntimeSettings.Omatiles = .load()
    private var watchTimer: Timer?
    private var watchObservers: [NSObjectProtocol]?
    private var viewMonitor: Any?
    private var lastSignature = ""
    private var appliedSettingsKey = ""

    /// Carbon hot-key registration, one ref per action id.
    private var hotKeyRefs: [Int: EventHotKeyRef] = [:]
    private static var hotKeyDispatcher: EventHandlerRef?

    private enum HotkeyAction: Int {
        case tile = 1, focusPrevious = 2, focusNext = 3, cycleLayout = 4
    }

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
        installViewMonitor()
        tile()
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
        guard !candidates.isEmpty else {
            tiledCount = 0
            return
        }

        // Group candidates by the display they actually occupy, so each monitor
        // gets its own work area and layout. Grouping preserves per-screen order.
        let screens = NSScreen.screens
        let groups = Dictionary(grouping: candidates) { candidate -> Int in
            guard let screen = screen(containing: candidate.frame),
                  let index = screens.firstIndex(where: { $0 === screen }) else { return 0 }
            return index
        }

        var applied = 0
        for (index, group) in groups {
            guard screens.indices.contains(index) else { continue }
            let workArea = visibleScreenArea(for: screens[index])
            guard !workArea.isEmpty else { continue }

            let frames = OmatilesLayouts.compute(
                layout: settings.layout,
                count: group.count,
                workArea: workArea,
                gapInner: CGFloat(settings.gapInner)
            )
            for (i, candidate) in group.enumerated() where i < frames.count {
                if setAXFrame(for: candidate, to: frames[i]) { applied += 1 }
            }
        }
        tiledCount = applied
    }

    // MARK: - Window enumeration

    private struct Candidate {
        let pid: pid_t
        let owner: String
        let windowID: CGWindowID
        let frame: CGRect
    }

    /// On-screen windows eligible for tiling (skips floating bundle IDs + own process).
    private func tilingCandidates() -> [Candidate] {
        let floats = Set(settings.floatingApps.map { $0.lowercased() })
        var result: [Candidate] = []
        for win in Desktop.snapshot() {
            let bundleID = NSRunningApplication(processIdentifier: win.pid)?.bundleIdentifier?.lowercased()
            if let bundleID, floats.contains(bundleID) { continue }
            result.append(Candidate(pid: win.pid, owner: win.owner, windowID: win.number, frame: win.frame))
        }
        return result
    }

    /// The screen whose frame contains the midpoint of `frame`.
    private func screen(containing frame: CGRect) -> NSScreen? {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        return NSScreen.screens.first { $0.frame.insetBy(dx: -1, dy: -1).contains(center) }
    }

    /// Area inside a given screen's edges AND under (or above) the Omabar when it
    /// is on that screen.
    private func visibleScreenArea(for screen: NSScreen) -> CGRect {
        var area = screen.frame.insetBy(
            dx: CGFloat(settings.gapOuter),
            dy: CGFloat(settings.gapOuter)
        )
        let bar = RuntimeSettings.Omabar.load()
        if bar.enable, screen === NSScreen.main {
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

    // MARK: - AX↔CGWindow matching

    /// All AX windows of an application.
    private func axWindows(of pid: pid_t) -> [AXUIElement] {
        let app = AXUIElementCreateApplication(pid)
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &ref) == .success,
              let windows = ref as? [AXUIElement] else { return [] }
        return windows
    }

    /// Returns the AX window whose CoreGraphics window id matches `candidate`.
    /// Falls back to the first AX window when the id can't be resolved (some apps
    /// never expose it), so a wrong-but-close move is preferable to no move.
    private func axWindow(for candidate: Candidate) -> AXUIElement? {
        let windows = axWindows(of: candidate.pid)
        guard !windows.isEmpty else { return nil }
        if let exact = windows.first(where: { axWindowID(of: $0) == candidate.windowID }) {
            return exact
        }
        return windows.first
    }

    /// Maps an AX window back to its CGWindowID (bridged private symbol — the same
    /// trick Reef uses; there is no public Swift-visible equivalent).
    private func axWindowID(of element: AXUIElement) -> CGWindowID? {
        var windowID = CGWindowID(0)
        guard _AXUIElementGetWindow(element, &windowID) == .success, windowID != 0 else { return nil }
        return windowID
    }

    // MARK: - Accessibility window moves

    /// Positions a candidate's matching AX window. Returns false when the move failed.
    private func setAXFrame(for candidate: Candidate, to frame: CGRect) -> Bool {
        guard let window = axWindow(for: candidate) else { return false }

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

        guard let app = NSRunningApplication(processIdentifier: target.pid) else { return }
        app.activate()

        if let window = axWindow(for: target) {
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
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
        guard watchObservers == nil else { return }
        let nc = NotificationCenter.default
        let notify: @Sendable (Notification) -> Void = { [weak self] _ in
            Task { @MainActor in self?.watchTick() }
        }

        var observers: [NSObjectProtocol] = []
        observers.append(nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main, using: notify))
        observers.append(nc.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main, using: notify))
        observers.append(nc.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main, using: notify))
        observers.append(nc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main, using: notify))
        observers.append(nc.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main, using: notify))
        watchObservers = observers

        // Slow fallback so invisible changes (e.g. a window resized by hand) also re-tile.
        watchTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.watchTick() }
        }
    }

    private func stopWatch() {
        watchTimer?.invalidate()
        watchTimer = nil
        if let watchObservers {
            for observer in watchObservers {
                NotificationCenter.default.removeObserver(observer)
            }
            self.watchObservers = nil
        }
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

    // MARK: - Keyboard bindings (Carbon hotkeys — consumed, not leaked)

    private func installHotkeys() {
        guard hotKeyRefs.isEmpty else { return }

        // Install the C dispatcher exactly once per engine lifetime.
        Self.installHotKeyDispatcher(owner: self)

        _ = registerHotkey(.tile, keyCode: kVK_ANSI_T)
        _ = registerHotkey(.focusPrevious, keyCode: kVK_ANSI_J)
        _ = registerHotkey(.focusNext, keyCode: kVK_ANSI_K)
        _ = registerHotkey(.cycleLayout, keyCode: kVK_ANSI_L)
    }

    private func registerHotkey(_ action: HotkeyAction, keyCode: Int) -> Bool {
        let hotKeyID = EventHotKeyID(signature: OSType(0x4F4D4E58), id: UInt32(action.rawValue)) // "OMNX"
        let modifiers = UInt32(cmdKey) | UInt32(optionKey) // ⌘⌥
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(keyCode), modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return false }
        hotKeyRefs[action.rawValue] = ref
        return true
    }

    private func removeHotkeys() {
        for ref in hotKeyRefs.values {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        if let dispatcher = Self.hotKeyDispatcher {
            RemoveEventHandler(dispatcher)
            Self.hotKeyDispatcher = nil
        }
    }

    private func handleHotkey(_ actionRaw: Int) {
        guard let action = HotkeyAction(rawValue: actionRaw) else { return }
        switch action {
        case .tile: tile()
        case .focusPrevious: focusPrevious()
        case .focusNext: focusNext()
        case .cycleLayout: cycleLayout()
        }
    }

    private static func installHotKeyDispatcher(owner: OmatilesEngine) {
        guard hotKeyDispatcher == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPointer = Unmanaged.passUnretained(owner).toOpaque()

        let handler: EventHandlerUPP = { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }

            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard status == noErr else { return OSStatus(eventNotHandledErr) }

            let engine = Unmanaged<OmatilesEngine>.fromOpaque(userData).takeUnretainedValue()
            Task { @MainActor in engine.handleHotkey(Int(hotKeyID.id)) }
            return noErr
        }

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            selfPointer,
            &hotKeyDispatcher
        )
        _ = installStatus
    }

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

// Private Core Accessibility API (same symbol Reef bridges) — maps an AX window
// back to its CGWindowID so we can tile an app's specific on-screen window.
@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError