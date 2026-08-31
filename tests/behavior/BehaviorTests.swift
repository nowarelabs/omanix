// tests/behavior/BehaviorTests.swift
// Headless behavioral harness — what the User does vs what the system does.
//
// Two services, as requested:
//   1. UserActionSimulator — does the action (presses the hotkey, toggles the switch)
//   2. SystemEffectReader   — reads the effect on the target system (window frame, defaults)
//
// Each test prints PASS/FAIL/SKIP; SKIPs are not failures (e.g. headless CI).
// The suite is intentionally separate from `tests/two-way` which is isolated and
// never touches the live OS; this suite *does* touch the live OS and therefore
// must be run on macOS with a display (and Accessibility for tiling).

import Foundation
import AppKit
import ApplicationServices

var behaviorFailures: [String] = []

func behaviorCheck(_ passed: Bool, _ label: String) {
    if passed {
        print("  PASS  \(label)")
    } else {
        print("  FAIL  \(label)")
        behaviorFailures.append(label)
    }
}

@main
struct BehaviorTests {
    static func main() {
        print("=== Omanix behavioral tests (User action → System effect) ===")
        print("Display: \(NSScreen.screens.count) screens, main \(String(describing: NSScreen.main?.frame))")
        print("AX trusted: \(AXIsProcessTrusted())")
        print("Omanix dir: \(Omanix().currentThemeId()) theme, Omatiles enabled: \(Omanix().currentOmatilesState().enable)")

        // Start the engine so key events and direct simulation are handled
        OmatilesEngine.shared.start()

        var allFailures: [String] = []

        allFailures.append(contentsOf: TilingBehaviorTests.runAll())
        allFailures.append(contentsOf: OmabarBehaviorTests.runAll())
        allFailures.append(contentsOf: ThemeBehaviorTests.runAll())

        print("\n=== BEHAVIORAL RESULTS ===")
        if allFailures.isEmpty {
            print("ALL BEHAVIORAL TESTS PASSED (failures: 0, some may have been SKIPPED)")
        } else {
            print("\(allFailures.count) BEHAVIORAL TEST(S) FAILED:")
            for f in allFailures { print("  - \(f)") }
            exit(1)
        }
    }
}
