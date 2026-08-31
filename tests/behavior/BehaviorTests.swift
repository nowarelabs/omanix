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

        // Start the engine so key events and direct simulation are handled.
        // Auto-tiling is left OFF here so the deterministic manual-tiling tests
        // (tileLeft etc.) are never disturbed by a background re-flow. A dedicated
        // auto-tile test enables it deliberately.
        OmatilesEngine.shared.start(settings: RuntimeSettings.Omatiles(
            enable: true, bindings: true, gap: 8, defaultLayout: "bsp", autoTile: false
        ))

        var allFailures: [String] = []

        // Service 3 — PURE layout contract tests. Always run (headless-safe),
        // they encode the exact user-visible layout expectations (4 windows → 4
        // quadrants, no overlap, exchanges are bijections, nothing stranded).
        allFailures.append(contentsOf: LayoutContractTests.runAll())

        // Service 3c — PURE WindowArranger seam contract tests. Headless and
        // deterministic: the shared arrangement seam must hand every tiling
        // surface (OmatilesEngine apply, WorkspaceManager event sink) the exact
        // same canonical layout frames, so Windows always land in the one place.
        allFailures.append(contentsOf: WindowArrangerContractTests.runAll())

        // Service 3b — PURE KDL -> workspaces contract tests. Headless-safe and
        // always run: they encode the user-visible expectation that a declarative
        // KDL layout document compiles to the exact workspace map Owin routes on.
        allFailures.append(contentsOf: KdlContractTests.runAll())

        // Live seam: writing layout.kdl makes Owin's reader see those workspaces.
        allFailures.append(contentsOf: KdlWorkspaceBehaviorTests.runAll())

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
