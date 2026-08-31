// Modules/Omatiles/WindowNavigator.swift
// Strategy — Aerospace-style move/focus navigation between tiled windows.
//
// Extracted from OmatilesEngine (see WindowTiler's header for the rationale).
// This type owns "cycle the focused window through the layout's slots": moving
// the focused window to the next/previous slot (an exchange with its neighbour)
// and putting keyboard focus on the next/previous window. It depends only on the
// window-ordering + frame math from LayoutEngine/RealWindowMover — no key
// bindings, no auto-tiling.

import AppKit
import ApplicationServices
import CoreGraphics

@MainActor
final class WindowNavigator {

    static let shared = WindowNavigator()

    private init() {}

    /// Moves the focused window to the next (or previous) layout slot, swapping
    /// frames with its neighbour so nothing is stranded. True if both moved.
    @discardableResult
    func moveFocusedWindow(forward: Bool, defaultLayout: String, gap: CGFloat) -> Bool {
        guard AXIsProcessTrusted(), NSScreen.main != nil else { return false }
        let layout = OwinLayout(rawValue: defaultLayout) ?? .bsp
        let (windows, frames) = layoutPlan(layout: layout, gap: gap)
        guard windows.count > 1,
              let focused = RealWindowMover.shared.focusedWindowElement(),
              let idx = windows.firstIndex(where: { CFEqual($0, focused) }) else { return false }
        let step = (forward ? 1 : -1)
        let next = (idx + step + windows.count) % windows.count
        // Swap the two windows' frames so the focused window lands in the neighbor slot.
        let fFrame = frames[idx]
        let nFrame = frames[next]
        let ok1 = (try? RealWindowMover.shared.apply(nFrame, to: windows[idx])) != nil
        let ok2 = (try? RealWindowMover.shared.apply(fFrame, to: windows[next])) != nil
        GhostTilingOverlay.shared.showGhosts(for: frames)
        return ok1 && ok2
    }

    /// Puts keyboard focus on the next/previous visible window by raising and
    /// activating the owning application (and its window). True on success.
    @discardableResult
    func focusNextWindow(forward: Bool, defaultLayout: String, gap: CGFloat) -> Bool {
        guard AXIsProcessTrusted(), NSScreen.main != nil else { return false }
        let layout = OwinLayout(rawValue: defaultLayout) ?? .bsp
        let (windows, _) = layoutPlan(layout: layout, gap: gap)
        guard windows.count > 1 else { return false }
        // Find the focused window's index in the ordered set. CFEqual compares the
        // represented element (not wrapper pointer identity), which stays stable.
        guard let focused = RealWindowMover.shared.focusedWindowElement(),
              let focusedIndex = windows.firstIndex(where: { CFEqual($0, focused) }) else { return false }
        let step = (forward ? 1 : -1)
        let next = (focusedIndex + step + windows.count) % windows.count
        let target = windows[next]
        var pid: pid_t = 0
        AXUIElementGetPid(target, &pid)
        guard pid > 0, let app = NSRunningApplication(processIdentifier: pid) else { return false }
        app.activate()
        // Bring the target window to the front within its app.
        AXUIElementPerformAction(target, kAXRaiseAction as CFString)
        return true
    }

    /// Orderly visible windows plus their target frames for the default layout.
    private func layoutPlan(layout: OwinLayout, gap: CGFloat) -> ([AXUIElement], [CGRect]) {
        guard let screen = NSScreen.main, layout != .float else { return ([], []) }
        let windows = RealWindowMover.shared.allVisibleWindows()
        let frames = LayoutEngine.frames(count: windows.count, in: screen.visibleFrame, layout: layout, gap: gap)
        return (windows, frames)
    }
}
