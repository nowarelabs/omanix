// tests/behavior/ThemeBehaviorTests.swift
// User picks a theme in the Store → Omanix writes it → reader sees it.

import Foundation

struct ThemeBehaviorTests {
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

        print("\n[Theme] User picks theme → state reflects it")

        let original = SystemEffectReader.theme()
        do {
            try UserActionSimulator.setTheme("one-dark")
            Thread.sleep(forTimeInterval: 0.2)
            let after = SystemEffectReader.theme()
            record(after == "one-dark", "setTheme one-dark → reader \(after)")

            try UserActionSimulator.setTheme(original)
            Thread.sleep(forTimeInterval: 0.2)
            let restored = SystemEffectReader.theme()
            record(restored == original, "restore theme → \(restored) (was \(original))")
        } catch {
            record(false, "Theme set threw: \(error)")
        }

        return failures
    }
}
