// tests/behavior/OmabarBehaviorTests.swift
// User toggles Omabar switch → declarative state + live bar reflects it.

import Foundation

struct OmabarBehaviorTests {
    static func runAll() -> [String] {
        var failures: [String] = []
        func record(_ passed: Bool, _ label: String) {
            if passed {
                print("  PASS  \(label)")
            } else {
                print("  FAIL  \(label)")
                failures.append(label)
            }
        }

        print("\n[Omabar] User toggles bar item → state + reader reflect it")

        // ShowClock toggle via Omanix (the same path the GUI switch uses)
        do {
            let before = SystemEffectReader.omabarState().showClock
            try UserActionSimulator.setOmabar("showClock", to: !before)
            // Give state.nix a moment to be written and read back
            Thread.sleep(forTimeInterval: 0.2)
            let after = SystemEffectReader.omabarState().showClock
            record(after == !before, "toggle showClock \(before) → \(after)")
            // Restore
            try UserActionSimulator.setOmabar("showClock", to: before)
            Thread.sleep(forTimeInterval: 0.2)
            let restored = SystemEffectReader.omabarState().showClock
            record(restored == before, "restore showClock → \(restored)")
        } catch {
            record(false, "Omabar toggle threw: \(error)")
        }

        // ShowVolumeText (structured component override path)
        do {
            let before = SystemEffectReader.omabarState().showVolumeText
            try UserActionSimulator.setOmabar("showVolumeText", to: !before)
            Thread.sleep(forTimeInterval: 0.2)
            let after = SystemEffectReader.omabarState().showVolumeText
            record(after == !before, "toggle showVolumeText \(before) → \(after)")
            try UserActionSimulator.setOmabar("showVolumeText", to: before)
        } catch {
            record(false, "showVolumeText toggle threw: \(error)")
        }

        return failures
    }
}
