// Modules/Omatiles/WindowTiler.swift
// Strategy — the window-arrangement ACTIONS (single-window tile and
// whole-workspace apply) for Omatiles.
//
// Extracted from OmatilesEngine (which was conflating five responsibilities:
// hotkey wiring, single-window tiling, whole-workspace apply, move/focus
// navigation, and auto-tiling). This type owns the "put windows into a
// region/layout" actions: computing the target frame (LayoutEngine) and moving
// the focused window there, or arranging every visible window into a layout's
// slots (WindowArranger). It is the Strategy over *what arrangement an action
// produces*, independent of the key bindings that trigger it and the
// auto-tiling that schedules it.

import AppKit
import CoreGraphics

@MainActor
final class WindowTiler {

    static let shared = WindowTiler()

    private init() {}

    // MARK: - Single-window tiling (⌘⌥ + edge / Z)

    /// Tiles the focused window into one of the four screen halves.
    @discardableResult
    func tileQuarter(_ edge: LayoutEngine.Half, gap: CGFloat) -> Bool {
        guard let screen = NSScreen.main else { return false }
        let frame = LayoutEngine.half(edge, in: screen.visibleFrame, gap: gap)
        GhostTilingOverlay.shared.showGhosts(for: [frame])
        return moveFocused(to: frame)
    }

    /// Tiles the focused window into one grid quadrant (2x2, row-major).
    @discardableResult
    func tileQuadrant(_ index: Int, gap: CGFloat) -> Bool {
        guard let screen = NSScreen.main,
              let frame = LayoutEngine.quadrant(index, in: screen.visibleFrame, gap: gap) else { return false }
        // Ghost the full 2x2 grid so the user sees every slot they can navigate.
        GhostTilingOverlay.shared.showGhosts(for: LayoutEngine.gridSlots(in: screen.visibleFrame, gap: gap))
        return moveFocused(to: frame)
    }

    /// Tiles the focused window full-visible-frame (monocle slot).
    @discardableResult
    func tileMonocle(gap: CGFloat) -> Bool {
        guard let screen = NSScreen.main else { return false }
        let frame = screen.visibleFrame.insetBy(dx: gap, dy: gap)
        GhostTilingOverlay.shared.showGhosts(for: [frame])
        return moveFocused(to: frame)
    }

    /// Untile (restore): puts the focused window into the full visible frame
    /// minus the gap (we don't track each window's original frame).
    @discardableResult
    func untile(gap: CGFloat) -> Bool {
        guard let screen = NSScreen.main else { return false }
        return moveFocused(to: screen.visibleFrame.insetBy(dx: gap, dy: gap))
    }

    /// Moves the focused window to an explicit frame via AX. True if it moved.
    @discardableResult
    func moveFocused(to frame: CGRect) -> Bool {
        do {
            try RealWindowMover.shared.moveFocusedWindow(to: frame)
            return true
        } catch {
            print("OmatilesEngine: tile to \(frame) failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Whole-workspace layout (auto-tile re-flow + Window Manager Apply)

    /// Arranges every visible window on the main screen into the layout's slots.
    /// Returns how many windows actually moved.
    @discardableResult
    func applyLayout(_ layout: OwinLayout, gap: CGFloat) -> Int {
        let (windows, frames) = layoutPlan(layout: layout, gap: gap)
        guard !windows.isEmpty, !frames.isEmpty, let screen = NSScreen.main else { return 0 }
        // Ghost the slots first so the parking spots are visible immediately.
        GhostTilingOverlay.shared.showGhosts(for: LayoutEngine.gridSlots(in: screen.visibleFrame, gap: gap))
        let moved = WindowArranger.shared.arrange(windows, layout: layout, in: screen.visibleFrame, gap: gap)
        print("OmatilesEngine: applied layout \(layout.rawValue) to \(moved)/\(windows.count) windows")
        return moved
    }

    /// Arranges every visible window into the persisted default layout.
    @discardableResult
    func applyDefaultLayout(layoutName: String, gap: CGFloat) -> Int {
        let layout = OwinLayout(rawValue: layoutName) ?? .bsp
        return applyLayout(layout, gap: gap)
    }

    // MARK: - Plan

    /// Orderly visible windows plus their target frames for a layout. Empty
    /// frames for `.float` or when untrusted / no main screen.
    private func layoutPlan(layout: OwinLayout, gap: CGFloat) -> ([AXUIElement], [CGRect]) {
        guard AXIsProcessTrusted(), let screen = NSScreen.main, layout != .float else { return ([], []) }
        let windows = RealWindowMover.shared.allVisibleWindows()
        let frames = LayoutEngine.frames(count: windows.count, in: screen.visibleFrame, layout: layout, gap: gap)
        return (windows, frames)
    }
}
