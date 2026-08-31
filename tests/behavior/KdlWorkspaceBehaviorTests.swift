// tests/behavior/KdlWorkspaceBehaviorTests.swift
// User drops a Zellij-style layout.kdl into ~/.config/omanix → Owin's workspace
// reader (RuntimeSettings.workspaces()) reflects exactly those workspaces.
//
// This is the end-to-end seam: it exercises the same function the WorkspaceManager
// AX sink calls every launch, so it proves the KDL bridge is actually consumed,
// not just compilable. It runs at the config/prefs layer (no windows) so it is
// headless-safe. The test creates and then removes a real layout.kdl, leaving the
// system exactly as it found it.

import Foundation

struct KdlWorkspaceBehaviorTests {
    static func runAll() -> [String] {
        var failures: [String] = []
        func record(_ passed: Bool, _ label: String) {
            if passed { print("  PASS  \(label)") }
            else { print("  FAIL  \(label)"); failures.append(label) }
        }

        print("\n[KDL] User writes layout.kdl → Owin sees those workspaces")

        let path = RuntimeSettings.kdlConfigPath
        let fm = FileManager.default

        // Remember whether a layout.kdl already existed so we fully restore.
        let existed = fm.fileExists(atPath: path)
        let original = existed ? (try? String(contentsOfFile: path, encoding: .utf8)) : nil

        defer {
            do {
                if existed {
                    if let original { try original.write(toFile: path, atomically: true, encoding: .utf8) }
                } else {
                    try? fm.removeItem(atPath: path)
                }
            } catch {}
        }

        let kdl = """
        layout {
          workspace "1: Web" {
            layout "monocle"
            monitor "External 4K"
            app "Brave"
            app "Slack"
          }
          workspace "2: Code" {
            app "Ghostty"
          }
        }
        """
        do {
            try fm.createDirectory(atPath: (path as NSString).deletingLastPathComponent,
                                   withIntermediateDirectories: true)
            try kdl.write(toFile: path, atomically: true, encoding: .utf8)

            let map = RuntimeSettings.workspaces()

            // Expectation: exactly the two documented workspaces, correct fields.
            let names = Set(map.keys)
            record(names == ["1: Web", "2: Code"],
                   "layout.kdl yields exactly the 2 documented workspaces (got \(names.sorted()))")

            if let web = map["1: Web"] {
                record(web.layout == "monocle", "1: Web layout = 'monocle' (got \(web.layout))")
                record(web.monitor == "External 4K", "1: Web monitor = 'External 4K' (got \(web.monitor ?? "nil"))")
                record(web.apps == ["Brave", "Slack"], "1: Web apps = ['Brave','Slack'] in order (got \(web.apps))")
            } else {
                record(false, "1: Web workspace missing")
            }

            if let code = map["2: Code"] {
                record(code.layout == "bsp", "2: Code defaulted to layout 'bsp' (got \(code.layout))")
                record(code.apps == ["Ghostty"], "2: Code apps = ['Ghostty'] (got \(code.apps))")
            } else {
                record(false, "2: Code workspace missing")
            }
        } catch {
            record(false, "KDL integration test threw: \(error)")
        }
        return failures
    }
}
