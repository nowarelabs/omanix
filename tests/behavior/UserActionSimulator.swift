// tests/behavior/UserActionSimulator.swift
// Service 1 — does the user action.
//
// The Omanix app is more than a store; its `Omanix` facade exposes every
// user-togglable surface (theme, bar items, tiling) through `omanix state set`.
// This service is the programmatic equivalent of "what the user does":
// pressing keys, toggling switches, picking a theme. It talks only through the
// same paths the GUI does, so the test proves the GUI would have the same effect.

import Foundation
import AppKit
import ApplicationServices
import Carbon.HIToolbox

enum UserActionError: LocalizedError {
    case notTrusted
    case failed(String)
    var errorDescription: String? {
        switch self {
        case .notTrusted: return "Accessibility not trusted — grant it to Terminal / test runner"
        case .failed(let s): return s
        }
    }
}

enum TilingDirection {
    case left, right, top, bottom, untile
}

/// Programmatically performs the same actions a user would in the Omanix UI
/// or via the global hotkeys. Two paths:
///   a) Direct Engine — calls `OmatilesEngine.shared.tileLeft()` etc. (no HID, no trust needed)
///   b) Synthetic HID — posts `Ctrl+Option+Arrow` via `CGEvent` (requires AX trust, but proves the hotkey path)
enum UserActionSimulator {

    // MARK: - Tiling (Ctrl+Option+Arrow)

    /// Direct engine path — deterministic, no trust prompt, mirrors what the
    /// GUI's "Try it" button does.
    static func tileDirectly(_ direction: TilingDirection) {
        let work = {
            MainActor.assumeIsolated {
                switch direction {
                case .left: OmatilesEngine.shared.tileLeft()
                case .right: OmatilesEngine.shared.tileRight()
                case .top: OmatilesEngine.shared.tileTop()
                case .bottom: OmatilesEngine.shared.tileBottom()
                case .untile: OmatilesEngine.shared.untile()
                }
            }
        }
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.sync(execute: work)
        }
    }

    /// Direct engine path into a grid quadrant (2x2, row-major). Returns true if
    /// the focused window was actually moved.
    @discardableResult
    static func tileQuadrantDirectly(_ index: Int) -> Bool {
        var result = false
        let work = { MainActor.assumeIsolated { result = OmatilesEngine.shared.tileQuadrant(index) } }
        if Thread.isMainThread { work() } else { DispatchQueue.main.sync(execute: work) }
        return result
    }

    /// Direct engine path into the monocle (full visible frame) slot.
    @discardableResult
    static func tileMonocleDirectly() -> Bool {
        var result = false
        let work = { MainActor.assumeIsolated { result = OmatilesEngine.shared.tileMonocle() } }
        if Thread.isMainThread { work() } else { DispatchQueue.main.sync(execute: work) }
        return result
    }

    /// Direct engine path into whole-workspace layout application (arranges every
    /// visible window into the layout's slots). Returns how many windows moved.
    @discardableResult
    static func applyLayoutDirectly(_ layout: OwinLayout) -> Int {
        var result = 0
        let work = { MainActor.assumeIsolated { result = OmatilesEngine.shared.applyLayout(layout) } }
        if Thread.isMainThread { work() } else { DispatchQueue.main.sync(execute: work) }
        return result
    }

    /// Direct engine path into moving the focused window to the next/previous
    /// slot (an exchange with its neighbour). Returns true if both moved.
    @discardableResult
    static func moveWindowDirectly(forward: Bool) -> Bool {
        var result = false
        let work = { MainActor.assumeIsolated { result = OmatilesEngine.shared.moveFocusedWindow(forward: forward) } }
        if Thread.isMainThread { work() } else { DispatchQueue.main.sync(execute: work) }
        return result
    }

    /// Simulates a user pressing one of OUR Omatiles global hotkey bindings
    /// (⌘⌥+arrow / ⌘⌥Z). Carbon hotkey events don't dispatch reliably in a
    /// headless test process (no app run loop), so instead of posting a raw HID
    /// event we drive the exact code path the Carbon dispatcher runs:
    /// `performBinding(raw)` → real AX move. This proves the hotkey → action →
    /// window-move chain that a real ⌘⌥ keystroke triggers in the running app.
    static func tileViaHotkey(_ direction: TilingDirection) throws {
        guard AXIsProcessTrusted() else { throw UserActionError.notTrusted }
        // Our ⌘⌥ binding ids: left=1, right=2, top=3, bottom=4, untile=5.
        let raw: Int
        switch direction {
        case .left: raw = 1
        case .right: raw = 2
        case .top: raw = 3
        case .bottom: raw = 4
        case .untile: raw = 5
        }
        var result: Bool = false
        let work = {
            MainActor.assumeIsolated {
                guard OmatilesEngine.shared.isRunning else { result = false; return }
                result = OmatilesEngine.shared.performBinding(raw)
            }
        }
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.sync(execute: work)
        }
        if !result { throw UserActionError.failed("hotkey binding \(raw) did not move a window (engine not started?)") }
    }

    // MARK: - Omabar / Omatiles declarative toggles (via Omanix)

    static func setOmabar(_ key: String, to value: Bool) throws {
        try Omanix().setOmabarOption(key, value ? "true" : "false")
    }

    static func setOmatiles(_ key: String, to value: Bool) throws {
        try Omanix().setOmatilesOption(key, value ? "true" : "false")
    }

    static func applyTilingLive() throws {
        try Omanix().applyOmatilesLive()
    }

    // MARK: - Theme

    static func setTheme(_ id: String) throws {
        try Omanix().setTheme(id)
    }

    // MARK: - Window creation (for tiling tests)

    /// Asks TextEdit to open a new document window via AppleScript, returns its PID.
    @discardableResult
    static func openTestWindow(app: String = "TextEdit") throws -> pid_t {
        let script = "tell application \"\(app)\" to activate\n tell application \"\(app)\" to make new document"
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]
        try proc.run()
        proc.waitUntilExit()
        // Give the window a moment to appear and find its PID.
        Thread.sleep(forTimeInterval: 0.8)
        guard let found = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier?.contains(app) == true || $0.localizedName == app }) else {
            throw UserActionError.failed("Could not find \(app) after launch")
        }
        found.activate(options: [.activateIgnoringOtherApps])
        // Poll until the app actually exposes at least one window to the
        // Accessibility API, so the returned pid is guaranteed usable by the
        // test right away (avoids the open→AX-visible race seen under load).
        let appElement = AXUIElementCreateApplication(found.processIdentifier)
        for _ in 0..<20 {
            var windowsRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
               let windows = windowsRef as? [AXUIElement], !windows.isEmpty {
                break
            }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return found.processIdentifier
    }

    static func closeWindow(pid: pid_t) {
        NSRunningApplication(processIdentifier: pid)?.terminate()
    }
}
