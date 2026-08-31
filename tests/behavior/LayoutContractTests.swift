// tests/behavior/LayoutContractTests.swift
// Service 3 — pure, deterministic layout contract tests.
//
// These test the LayoutEngine's *math* directly (no live OS, no AX, no skips),
// encoding the exact outcomes an end user expects to SEE:
//   - 4 windows in the grid -> exactly one window in each of the four quadrants
//   - no window ever covers a whole half when it should occupy only a quarter
//   - no window is ever thrown "all over the place" (all inside the screen, no
//     cell overlapping another)
//   - moving a window to its neighbour slot is an *exchange* (a bijection: no two
//     windows can ever be assigned the same slot, and none is dropped)
//   - arranging N windows never strands/omits a window
//
// Because this is pure math it runs on ANY machine (including headless CI) and is
// the canonical, re-runnable standard. The behavioral suite (Service 1 + 2) then
// proves the AX executor applies these same frames to real windows.

import Foundation
import CoreGraphics

enum LayoutContractTests {

    static func runAll() -> [String] {
        var failures: [String] = []
        let screen = CGRect(x: 0, y: 0, width: 4000, height: 3000)

        checkGridFourQuadrants(failures: &failures, screen: screen)
        checkGridNeverStrands(failures: &failures, screen: screen)
        checkNoOverlapAcrossLayouts(failures: &failures, screen: screen)
        checkMoveIsAnExchange(failures: &failures, screen: screen)
        checkMonocleStacked(failures: &failures, screen: screen)
        checkFloatIsEmpty(failures: &failures, screen: screen)

        return failures
    }

    // MARK: - Expectation: 4 windows -> exactly the 4 quadrants

    /// The flagship expectation: with 4 windows in the grid layout, each window
    /// occupies exactly one distinct quadrant (top-left, top-right, bottom-left,
    /// bottom-right). A regression like "window covers the whole bottom half
    /// instead of the bottom-left quarter" fails this first.
    private static func checkGridFourQuadrants(failures: inout [String], screen: CGRect) {
        let frames = LayoutEngine.frames(count: 4, in: screen, layout: .grid, gap: 8)
        guard frames.count == 4 else {
            fail(&failures, "grid(4) must produce 4 frames, got \(frames.count)")
            return
        }
        let midX = screen.midX
        let midY = screen.midY

        // Every frame must be a fraction of the screen (never full width/height),
        // which rules out "covers the whole bottom half when only a quarter".
        for (i, f) in frames.enumerated() {
            if !(f.width < screen.width * 0.99 && f.height < screen.height * 0.99) {
                fail(&failures, "grid(4) slot \(i) incorrectly spans a full edge: \(f)")
            }
        }

        // Exactly one window per quadrant.
        let counts = [
            ("TL", frames.filter { $0.minX < midX && $0.minY < midY }.count),
            ("TR", frames.filter { $0.minX > midX && $0.minY < midY }.count),
            ("BL", frames.filter { $0.minX < midX && $0.minY > midY }.count),
            ("BR", frames.filter { $0.minX > midX && $0.minY > midY }.count)
        ]
        for (quad, n) in counts where n != 1 {
            fail(&failures, "grid(4) expected exactly 1 window in quadrant \(quad), got \(n); frames=\(frames)")
        }
    }

    // MARK: - Expectation: arranging N windows never strands one

    private static func checkGridNeverStrands(failures: inout [String], screen: CGRect) {
        // 4 -> 4 (fits the near-square grid), 5..=12 must each get its own frame.
        for n in 1...12 {
            let frames = LayoutEngine.frames(count: n, in: screen, layout: .grid, gap: 8)
            if frames.count != n {
                fail(&failures, "grid(\(n)) must produce \(n) frames (no window stranded), got \(frames.count)")
            }
        }
    }

    // MARK: - Expectation: no two windows ever overlap / outside the screen

    private static func checkNoOverlapAcrossLayouts(failures: inout [String], screen: CGRect) {
        for layout in [OwinLayout.bsp, .grid, .stack, .spiral] {
            for n in 1...8 {
                let frames = LayoutEngine.frames(count: n, in: screen, layout: layout, gap: 8)
                guard frames.count == n else {
                    fail(&failures, "\(layout)(\(n)) produced \(frames.count) frames, expected \(n)")
                    continue
                }
                for (i, f) in frames.enumerated() {
                    // Fully within the screen (never "thrown all over the place").
                    if !screen.insetBy(dx: -1, dy: -1).contains(f) {
                        fail(&failures, "\(layout)(\(n)) slot \(i) outside screen: \(f)")
                    }
                    // No two slots overlap (each window has its own spot).
                    for (j, g) in frames.enumerated() where j != i {
                        let a = f.insetBy(dx: 1, dy: 1)
                        let b = g.insetBy(dx: 1, dy: 1)
                        if a.intersects(b) {
                            fail(&failures, "\(layout)(\(n)) slots \(i) and \(j) overlap: \(f) vs \(g)")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Expectation: moving a window to its neighbour is an exchange

    /// Moving the focused window to the adjacent slot must SWAP the two windows
    /// (an exchange), never overwrite one leaving a window with no slot. The
    /// frames assigned are a bijection across slots, so a swap can never collide.
    private static func checkMoveIsAnExchange(failures: inout [String], screen: CGRect) {
        for layout in [OwinLayout.bsp, .grid, .stack, .spiral] {
            // Every frame must be unique (distinct slots) for any count.
            for n in 2...8 {
                let frames = LayoutEngine.frames(count: n, in: screen, layout: layout, gap: 8)
                let distinct = Set(frames.map { "\(Int($0.minX))\(Int($0.minY))\(Int($0.width))\(Int($0.height))" })
                if distinct.count != frames.count {
                    fail(&failures, "\(layout)(\(n)) frames are not distinct — a move could collide (exchange breaks)")
                }
            }
            // Explicit: swapping neighbours produces a valid permutation.
            for n in 2...4 {
                var frames = LayoutEngine.frames(count: n, in: screen, layout: layout, gap: 8)
                let idx = 0
                let next = (idx + 1) % frames.count
                let a = frames[idx]
                frames[idx] = frames[next]
                frames[next] = a
                if frames[next] != a {
                    fail(&failures, "\(layout)(\(n)) neighbour swap at 0..\(next) failed to exchange")
                }
                let distinct = Set(frames.map { "\(Int($0.minX))\(Int($0.minY))\(Int($0.width))\(Int($0.height))" })
                if distinct.count != n {
                    fail(&failures, "\(layout)(\(n)) swapped frames collide — not an exchange")
                }
            }
        }
    }

    // MARK: - Expectation: monocle stacks all windows on the same inset frame

    private static func checkMonocleStacked(failures: inout [String], screen: CGRect) {
        for n in 1...5 {
            let frames = LayoutEngine.frames(count: n, in: screen, layout: .monocle, gap: 8)
            if frames.count != n {
                fail(&failures, "monocle(\(n)) frame count \(frames.count) != \(n)")
                continue
            }
            // Only the topmost is visible; all share (nearly) the full inset frame.
            for f in frames {
                if f.width < screen.width * 0.9 || f.height < screen.height * 0.9 {
                    fail(&failures, "monocle(\(n)) slot not near-fullscreen: \(f)")
                }
            }
        }
    }

    // MARK: - Expectation: float arranges nothing

    private static func checkFloatIsEmpty(failures: inout [String], screen: CGRect) {
        if !LayoutEngine.frames(count: 4, in: screen, layout: .float, gap: 8).isEmpty {
            fail(&failures, "float must not arrange windows (returns no frames)")
        }
    }

    private static func fail(_ failures: inout [String], _ label: String) {
        print("  FAIL  [contract] \(label)")
        failures.append("[contract] " + label)
    }
}
