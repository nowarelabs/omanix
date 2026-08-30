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

    /// Synthetic HID path — posts the real global hotkey the user presses
    /// (Ctrl+Option+Arrow). Requires Accessibility so the event tap can post.
    static func tileViaHotkey(_ direction: TilingDirection) throws {
        guard AXIsProcessTrusted() else { throw UserActionError.notTrusted }
        let key: CGKeyCode
        switch direction {
        case .left: key = CGKeyCode(kVK_LeftArrow)
        case .right: key = CGKeyCode(kVK_RightArrow)
        case .top: key = CGKeyCode(kVK_UpArrow)
        case .bottom: key = CGKeyCode(kVK_DownArrow)
        case .untile: key = CGKeyCode(kVK_ANSI_Z)
        }
        let flags: CGEventFlags = [.maskControl, .maskAlternate]
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: true) else {
            throw UserActionError.failed("CGEvent down is nil")
        }
        down.flags = flags
        down.post(tap: .cghidEventTap)
        guard let up = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: false) else {
            throw UserActionError.failed("CGEvent up is nil")
        }
        up.flags = flags
        up.post(tap: .cghidEventTap)
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
        Thread.sleep(forTimeInterval: 0.5)
        return found.processIdentifier
    }

    static func closeWindow(pid: pid_t) {
        NSRunningApplication(processIdentifier: pid)?.terminate()
    }
}
