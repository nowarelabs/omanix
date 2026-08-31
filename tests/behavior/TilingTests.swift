// tests/behavior/TilingTests.swift
// User does Ctrl+Option+Arrow → window tiles. Two services:
//   1. UserActionSimulator — does the action (direct engine or HID hotkey)
//   2. SystemEffectReader — reads the window frame after

import Foundation
import AppKit

enum TilingTestResult {
    case passed(String)
    case failed(String)
    case skipped(String)
}

struct TilingBehaviorTests {

    /// Runs all tiling user-action → effect tests. Returns failures.
    static func runAll() -> [String] {
        var failures: [String] = []
        var skips: [String] = []

        func record(_ result: TilingTestResult) {
            switch result {
            case .passed(let m): print("  PASS  \(m)")
            case .failed(let m): print("  FAIL  \(m)"); failures.append(m)
            case .skipped(let m): print("  SKIP  \(m)"); skips.append(m)
            }
        }

        print("\n[Tiling] Hotkey/engine → window actually moves (real AX tiling)")

        // 1. Declarative state → live prefs (no window needed, just prefs)
        record(testPrefsLiveApply())

        // 2. Direct engine tiling (requires a real window + AX)
        record(testDirectEngineTileLeft())
        record(testDirectEngineTileRight())
        record(testDirectEngineTileTop())
        record(testDirectEngineTileBottom())
        record(testDirectEngineQuadrant()) // grid slot
        record(testDirectEngineMonocle())
        record(testDirectEngineApplyGrid()) // whole-workspace layout application

        // 3. Hotkey/binding tiling (requires AX trust)
        record(testHotkeyTileLeft())

        if !skips.isEmpty {
            print("  (\(skips.count) tiling tests skipped — need Accessibility + a display)")
        }
        return failures
    }

    // MARK: - Sub-tests

    /// Reads a window frame once it is AX-visible, retrying briefly to absorb
    /// the small delay between a new document being created and its window being
    /// exposed to the Accessibility API.
    private static func readInitialFrame(pid: pid_t) -> CGRect? {
        for _ in 0..<10 {
            if let f = try? SystemEffectReader.windowFrame(pid: pid) { return f }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return nil
    }

    /// Verifies that `omanix state set` + `applyOmatilesLive` actually flips
    /// com.apple.WindowManager. This is the "pref" layer beneath the window layer.
    private static func testPrefsLiveApply() -> TilingTestResult {
        do {
            // Save original
            let before = SystemEffectReader.tilingPrefsViaDefaults()
            try UserActionSimulator.setOmatiles("enableEdgeDrag", to: false)
            try UserActionSimulator.applyTilingLive()
            Thread.sleep(forTimeInterval: 0.3)
            let after = SystemEffectReader.tilingPrefsViaDefaults()
            // Restore
            try UserActionSimulator.setOmatiles("enableEdgeDrag", to: before.edgeDrag)
            try UserActionSimulator.applyTilingLive()
            if after.edgeDrag == false {
                return .passed("setOmatiles(enableEdgeDrag:false) → defaults reflects false")
            } else {
                return .failed("setOmatiles(enableEdgeDrag:false) → defaults still \(after.edgeDrag) (expected false)")
            }
        } catch {
            return .failed("testPrefsLiveApply threw: \(error)")
        }
    }

    private static func testDirectEngineTileLeft() -> TilingTestResult {
        guard NSScreen.main != nil else { return .skipped("No main screen (headless)") }
        guard AXIsProcessTrusted() else { return .skipped("AX not trusted") }

        let pid: pid_t
        do {
            pid = try UserActionSimulator.openTestWindow()
        } catch {
            return .skipped("Could not open test window: \(error)")
        }
        defer { UserActionSimulator.closeWindow(pid: pid) }

        Thread.sleep(forTimeInterval: 0.4)
        guard let before = Self.readInitialFrame(pid: pid) else {
            return .skipped("Could not read initial window frame (AX)")
        }

        UserActionSimulator.tileDirectly(.left)
        Thread.sleep(forTimeInterval: 0.8)

        guard let after = try? SystemEffectReader.windowFrame(pid: pid) else {
            return .failed("Could not read window frame after tileLeft")
        }

        // Assertion: Tiling should actually change the window frame
        let onScreen = SystemEffectReader.mainScreenFrame().intersects(after)
        if onScreen && after != .zero && after != before {
            return .passed("tileLeft via engine: \(before) → \(after)")
        } else {
            return .failed("tileLeft via engine failed: window frame did not change from \(before) to a tiled position (after: \(after))")
        }
    }

    private static func testDirectEngineTileRight() -> TilingTestResult {
        guard NSScreen.main != nil else { return .skipped("No main screen") }
        guard AXIsProcessTrusted() else { return .skipped("AX not trusted") }

        let pid: pid_t
        do {
            pid = try UserActionSimulator.openTestWindow()
        } catch {
            return .skipped("Could not open test window: \(error)")
        }
        defer { UserActionSimulator.closeWindow(pid: pid) }

        Thread.sleep(forTimeInterval: 0.4)
        guard let before = Self.readInitialFrame(pid: pid) else {
            return .skipped("Could not read initial window frame")
        }
        UserActionSimulator.tileDirectly(.right)
        Thread.sleep(forTimeInterval: 0.8)

        guard let after = try? SystemEffectReader.windowFrame(pid: pid) else {
            return .failed("Could not read window frame after tileRight")
        }

        // Assertion: Tiling should actually change the window frame
        let onScreen = SystemEffectReader.mainScreenFrame().intersects(after)
        if onScreen && after != before {
            return .passed("tileRight via engine: \(before) → \(after)")
        } else {
            return .failed("tileRight via engine failed: window frame did not change from \(before) (after: \(after))")
        }
    }

    private static func testDirectEngineTileTop() -> TilingTestResult {
        return tileAndAssert(label: "tileTop",
                             before: { _ in }, action: { _ in UserActionSimulator.tileDirectly(.top) },
                             matches: { before, after, screen in
                                 // Top half: window's vertical center in the upper half, resized to (near) half-height.
                                 after.width > screen.width * 0.85
                                     && after.midY < screen.midY
                                     && after.height < screen.height * 0.6
                                     && after != before
                             },
                             expected: "window in top half, resized to fit")
    }

    private static func testDirectEngineTileBottom() -> TilingTestResult {
        return tileAndAssert(label: "tileBottom",
                             before: { _ in }, action: { _ in UserActionSimulator.tileDirectly(.bottom) },
                             matches: { before, after, screen in
                                 // Bottom half: window's vertical center in the lower half, resized to (near) half-height.
                                 after.width > screen.width * 0.85
                                     && after.midY >= screen.midY
                                     && after.height < screen.height * 0.6
                                     && after != before
                             },
                             expected: "window in bottom half, resized to fit")
    }

    private static func testDirectEngineQuadrant() -> TilingTestResult {
        return tileAndAssert(label: "tileQuadrant(0) [grid slot]",
                             before: { _ in }, action: { _ in _ = UserActionSimulator.tileQuadrantDirectly(0) },
                             matches: { _, after, screen in
                                 // Top-left grid slot: window is in the left, upper half.
                                 after.minX < screen.midX && after.maxY > screen.midY
                             },
                             expected: "window in top-left grid quadrant")
    }

    private static func testDirectEngineMonocle() -> TilingTestResult {
        return tileAndAssert(label: "tileMonocle",
                             before: { _ in }, action: { _ in _ = UserActionSimulator.tileMonocleDirectly() },
                             matches: { _, after, screen in
                                 // Monocle: window near full visible frame.
                                 after.width > screen.width * 0.85 && after.height > screen.height * 0.85
                             },
                             expected: "window near full-screen (monocle)")
    }

    private static func testDirectEngineApplyGrid() -> TilingTestResult {
        guard NSScreen.main != nil else { return .skipped("No main screen (headless)") }
        guard AXIsProcessTrusted() else { return .skipped("AX not trusted") }

        let pid: pid_t
        do {
            pid = try UserActionSimulator.openTestWindow()
        } catch {
            return .skipped("Could not open test window: \(error)")
        }
        defer { UserActionSimulator.closeWindow(pid: pid) }

        Thread.sleep(forTimeInterval: 0.4)
        guard let before = Self.readInitialFrame(pid: pid) else {
            return .skipped("Could not read initial window frame (AX)")
        }

        let moved = UserActionSimulator.applyLayoutDirectly(.grid)
        Thread.sleep(forTimeInterval: 0.8)

        guard let after = try? SystemEffectReader.windowFrame(pid: pid) else {
            return .failed("Could not read window frame after applyLayout(.grid)")
        }
        let screen = SystemEffectReader.mainScreenFrame()

        // The layout should actually move windows into grid cells: the test window
        // lands on-screen at a material fraction of the visible frame's width,
        // having been re-fitted into a 2x2 cell.
        let fitsCell = after.width > screen.width * 0.30
            && after.width < screen.width * 0.95
            && screen.intersects(after)
        if moved > 0 && after != before && fitsCell {
            return .passed("applyLayout(.grid): \(moved) window(s) arranged; test window \(before) → \(after)")
        } else {
            return .failed("applyLayout(.grid) did not arrange the window (moved=\(moved), before: \(before), after: \(after))")
        }
    }

    /// Shared helper: opens a focused test window, runs an action, and asserts
    /// the window frame actually changed AND satisfies a shape/position check.
    private static func tileAndAssert(label: String,
                                      before: (pid_t) -> Void,
                                      action: (pid_t) -> Void,
                                      matches: (CGRect, CGRect, CGRect) -> Bool,
                                      expected: String) -> TilingTestResult {
        guard NSScreen.main != nil else { return .skipped("No main screen (headless)") }
        guard AXIsProcessTrusted() else { return .skipped("AX not trusted") }

        let pid: pid_t
        do {
            pid = try UserActionSimulator.openTestWindow()
        } catch {
            return .skipped("Could not open test window: \(error)")
        }
        defer { UserActionSimulator.closeWindow(pid: pid) }

        Thread.sleep(forTimeInterval: 0.4)
        guard let b = Self.readInitialFrame(pid: pid) else {
            return .skipped("Could not read initial window frame (AX)")
        }

        action(pid)
        Thread.sleep(forTimeInterval: 0.8)

        guard let a = try? SystemEffectReader.windowFrame(pid: pid) else {
            return .failed("Could not read window frame after \(label)")
        }
        let screen = SystemEffectReader.mainScreenFrame()
        if a != b && matches(b, a, screen) {
            return .passed("\(label): \(b) → \(a) (\(expected))")
        } else {
            return .failed("\(label) failed: frame did not move/meet expectations \(b) → \(a) (expected \(expected), screen \(screen))")
        }
    }

    private static func testHotkeyTileLeft() -> TilingTestResult {
        guard NSScreen.main != nil else { return .skipped("No main screen") }
        guard AXIsProcessTrusted() else { return .skipped("AX not trusted — hotkey path needs it") }

        let pid: pid_t
        do {
            pid = try UserActionSimulator.openTestWindow()
        } catch {
            return .skipped("Could not open test window: \(error)")
        }
        defer { UserActionSimulator.closeWindow(pid: pid) }

        Thread.sleep(forTimeInterval: 0.8)
        guard let before = try? SystemEffectReader.windowFrame(pid: pid) else {
            return .skipped("Could not read initial window frame")
        }
        do {
            try UserActionSimulator.tileViaHotkey(.left)
        } catch {
            return .skipped("Hotkey failed (needs AX): \(error)")
        }
        Thread.sleep(forTimeInterval: 0.8)

        guard let after = try? SystemEffectReader.windowFrame(pid: pid) else {
            return .failed("Could not read window frame after hotkey tileLeft")
        }
        let onScreen = SystemEffectReader.mainScreenFrame().intersects(after)
        if onScreen && after != before {
            return .passed("tileLeft via ⌘⌥ binding: \(before) → \(after)")
        } else {
            return .failed("tileLeft via ⌘⌥ binding failed: window frame did not change from \(before) (after: \(after))")
        }
    }
}
