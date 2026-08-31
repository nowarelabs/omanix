// Modules/Omatiles/WindowArranger.swift
// Strategy — the single "arrange these windows" pipeline shared by both tiling
// surfaces (OmatilesEngine and WorkspaceManager).
//
// Before this type existed, each engine independently re-encoded the same
// pipeline: "collect the windows I care about -> compute LayoutEngine frames for
// them -> apply each frame to its AX window". OmatilesEngine did it for every
// visible window on the main screen; WorkspaceManager did it for the windows of
// one workspace's apps on a named monitor. That was duplicated logic with two
// owners and no single source of truth for "how a layout becomes real window
// frames".
//
// WindowArranger owns that shared core as a Strategy: given an explicit set of
// AX windows, a layout, and a screen frame, it computes the pure frames (via
// LayoutEngine) and applies them through the AX executor (RealWindowMover),
// reporting how many actually moved. What differs between engines — WHICH
// windows and WHICH screen — stays with each caller. This gives every current
// and future tiling trigger (hotkey, auto-tile, whole-workspace apply, Owin's
// per-workspace event sink) one correct place to arrange windows.

import CoreGraphics
import ApplicationServices

struct WindowArranger {

    static let shared = WindowArranger()

    private init() {}

    /// Compute the target frames for `count` windows laid out within a screen
    /// frame. Thin, pure wrapper over LayoutEngine so callers never reach past
    /// the seam for layout math.
    static func frames(count: Int, in screenFrame: CGRect, layout: OwinLayout, gap: CGFloat) -> [CGRect] {
        LayoutEngine.frames(count: count, in: screenFrame, layout: layout, gap: gap)
    }

    /// Arrange the given windows into `layout`'s slots within a screen frame via
    /// the Accessibility executor. Returns how many windows actually moved.
    /// `.float` yields no frames (and so no moves), matching the engines' contract.
    @discardableResult
    func arrange(_ windows: [AXUIElement], layout: OwinLayout, in screenFrame: CGRect, gap: CGFloat = 8) -> Int {
        let frames = LayoutEngine.frames(count: windows.count, in: screenFrame, layout: layout, gap: gap)
        guard windows.count == frames.count, !frames.isEmpty else { return 0 }
        var moved = 0
        for (window, frame) in zip(windows, frames) {
            if (try? RealWindowMover.shared.apply(frame, to: window)) != nil {
                moved += 1
            }
        }
        return moved
    }
}
