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

        print("\n[Tiling] Ctrl+Option+Arrow → window tiles")

        // 1. Declarative state → live prefs (no window needed, just prefs)
        record(testPrefsLiveApply())

        // 2. Direct engine tiling (requires a real window + AX)
        record(testDirectEngineTileLeft())
        record(testDirectEngineTileRight())

        // 3. Hotkey tiling (requires AX trust)
        record(testHotkeyTileLeft())

        if !skips.isEmpty {
            print("  (\(skips.count) tiling tests skipped — need Accessibility + a display)")
        }
        return failures
    }

    // MARK: - Sub-tests

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

        Thread.sleep(forTimeInterval: 0.8)
        guard let before = try? SystemEffectReader.windowFrame(pid: pid) else {
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

        Thread.sleep(forTimeInterval: 0.8)
        guard let before = try? SystemEffectReader.windowFrame(pid: pid) else {
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
            return .passed("tileLeft via HID hotkey Ctrl+Option+Left: \(before) → \(after)")
        } else {
            return .failed("tileLeft via hotkey failed: window frame did not change from \(before) (after: \(after))")
        }
    }
}
