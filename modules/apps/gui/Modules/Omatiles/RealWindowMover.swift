// Modules/Omatiles/RealWindowMover.swift
// Deterministic window moves via the macOS Accessibility API.
//
// The legacy OmatilesEngine bridged to macOS' built-in tiling by synthesizing
// ⌃⌥+arrow key events, which silently does nothing when the OS tiling switches
// are off or the keystroke isn't accepted. This type instead sets an AX window's
// position and size directly, so "tile left" genuinely moves the focused window
// into the left half — no dependence on OS tiling being enabled.

import AppKit
import ApplicationServices
import CoreGraphics

enum RealWindowMoverError: LocalizedError {
    case notTrusted
    case noFocus
    case axFailed(String)
    var errorDescription: String? {
        switch self {
        case .notTrusted: return "Accessibility not granted"
        case .noFocus: return "No focused window to tile"
        case .axFailed(let s): return "AX move failed: \(s)"
        }
    }
}

final class RealWindowMover {

    static let shared = RealWindowMover()

    private init() {}

    /// Moves the frontmost application's focused window into `frame`.
    /// Requires Accessibility trust. Throws on failure so callers/tests can
    /// distinguish "tiled" from "nothing happened".
    func moveFocusedWindow(to frame: CGRect) throws {
        guard AXIsProcessTrusted() else { throw RealWindowMoverError.notTrusted }
        guard let window = focusedWindowElement() else { throw RealWindowMoverError.noFocus }
        try apply(frame, to: window)
    }

    /// Returns the AX element of the frontmost app's focused window, if any.
    func focusedWindowElement() -> AXUIElement? {
        guard let front = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(front.processIdentifier)
        var windowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
              let window = windowRef else { return nil }
        return (window as! AXUIElement)
    }

    /// Sets an arbitrary AX window's frame. Used to arrange many windows at once
    /// (whole-workspace layouts). Requires Accessibility trust; throws on failure.
    func apply(_ frame: CGRect, to window: AXUIElement) throws {
        guard AXIsProcessTrusted() else { throw RealWindowMoverError.notTrusted }
        try setFrame(frame, on: window)
    }

    /// Enumerates on-screen, non-minimized AX windows belonging to regular apps
    /// (skip dock/notification-only agents). This is the set the layout engine
    /// arranges when "Apply" is pressed.
    func allVisibleWindows() -> [AXUIElement] {
        var out: [AXUIElement] = []
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            var windowsRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
                  let windows = windowsRef as? [AXUIElement] else { continue }
            for w in windows {
                var minimized: CFTypeRef?
                if AXUIElementCopyAttributeValue(w, kAXMinimizedAttribute as CFString, &minimized) == .success,
                   let b = minimized as? Bool, b == true { continue }
                out.append(w)
            }
        }
        return out
    }

    private func setFrame(_ frame: CGRect, on window: AXUIElement) throws {
        var pos = frame.origin
        var size = frame.size
        guard let posVal = AXValueCreate(.cgPoint, &pos),
              let sizeVal = AXValueCreate(.cgSize, &size) else {
            throw RealWindowMoverError.axFailed("Could not box frame")
        }
        let posErr = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posVal)
        guard posErr == .success else {
            throw RealWindowMoverError.axFailed("setPosition(\(posErr.rawValue))")
        }
        let sizeErr = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeVal)
        guard sizeErr == .success else {
            throw RealWindowMoverError.axFailed("setSize(\(sizeErr.rawValue))")
        }
    }
}
