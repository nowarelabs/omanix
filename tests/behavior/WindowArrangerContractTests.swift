// tests/behavior/WindowArrangerContractTests.swift
// Service 3c — pure contract tests for the shared arrangement seam.
//
// The point of the WindowArranger refactor is that BOTH tiling surfaces
// (OmatilesEngine's whole-workspace apply and WorkspaceManager's per-workspace
// event sink) arrange windows through ONE pipeline. The user-visible guarantee
// that encodes is: "it doesn't matter which engine or trigger causes an
// arrangement — the windows land in the same, canonical layout frames."
//
// These tests are headless and deterministic. They prove the seam's frame
// computation is byte-for-byte the canonical LayoutEngine math (so any engine
// routing through the seam produces identical physical layout), and that a
// `.float` layout arranges nothing (no frames -> no moves), matching the
// engines' existing contract.

import Foundation
import CoreGraphics

enum WindowArrangerContractTests {

    static func runAll() -> [String] {
        var failures: [String] = []
        let screen = CGRect(x: 0, y: 0, width: 4000, height: 3000)

        checkSeamMatchesCanonicalMath(failures: &failures, screen: screen)
        checkFloatArrangesNothing(failures: &failures, screen: screen)
        checkZeroWindowsNoFrames(failures: &failures, screen: screen)

        return failures
    }

    /// Expectation: the shared seam hands callers EXACTLY the canonical layout
    /// frames. If a future engine ever diverges, whichever trigger an end user
    /// presses (⌘⌥Apply vs an Owin window-event) would tile differently — this
    /// fails first. Spanning every layout and counts 0...12.
    private static func checkSeamMatchesCanonicalMath(failures: inout [String], screen: CGRect) {
        let layouts: [OwinLayout] = [.bsp, .grid, .monocle, .stack, .spiral, .float]
        for layout in layouts {
            for n in 0...12 {
                let fromSeam = WindowArranger.frames(count: n, in: screen, layout: layout, gap: 8)
                let fromCanonical = LayoutEngine.frames(count: n, in: screen, layout: layout, gap: 8)
                if fromSeam != fromCanonical {
                    fail(&failures, "WindowArranger.frames(\(layout), n=\(n)) != LayoutEngine.frames (seam diverged from canonical math)")
                }
            }
        }
    }

    /// Expectation: a `.float` workspace moves nothing — there are no target
    /// frames, so an arrangement through the seam yields zero moves. A window in
    /// a floating workspace must stay put, never be re-arranged.
    private static func checkFloatArrangesNothing(failures: inout [String], screen: CGRect) {
        let frames = WindowArranger.frames(count: 4, in: screen, layout: .float, gap: 8)
        if !frames.isEmpty {
            fail(&failures, "WindowArranger.frames(.float) must be empty (floating windows stay put), got \(frames.count)")
        }
    }

    /// Expectation: nothing to arrange -> nothing arranged. Zero windows must
    /// never produce arbitrary frames (no phantom slots).
    private static func checkZeroWindowsNoFrames(failures: inout [String], screen: CGRect) {
        for layout in [OwinLayout.bsp, .grid, .stack, .spiral] {
            let frames = WindowArranger.frames(count: 0, in: screen, layout: layout, gap: 8)
            if !frames.isEmpty {
                fail(&failures, "WindowArranger.frames(\(layout), n=0) must be empty, got \(frames.count)")
            }
        }
    }

    private static func fail(_ failures: inout [String], _ label: String) {
        print("  FAIL  [arranger] \(label)")
        failures.append("[arranger] " + label)
    }
}
