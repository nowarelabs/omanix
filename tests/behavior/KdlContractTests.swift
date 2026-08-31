// tests/behavior/KdlContractTests.swift
// Pure, deterministic contract tests for the KDL -> workspaces bridge.
//
// These encode exactly what the end user expects: they write a Zellij-style KDL
// document describing their workspaces and apps, and the system must present the
// resulting workspace map to Owin so apps get routed and tiled. Like the layout
// contract tests, this runs headless on any machine and is the re-runnable
// standard; the AX executor (WorkspaceManager) consumes the same map shape.
//
// End-user expectations encoded here:
//   - "I described one workspace with apps; I get exactly that workspace, with
//     those apps, in that order, on that monitor, with that layout."
//   - "I described several workspaces; I get one entry per workspace."
//   - "When I omit a layout / monitor / apps, I get sensible defaults, never a
//     crash or a silently-empty workspace."
//   - "A typo'd or empty document produces an empty map, never a crash."

import Foundation

enum KdlContractTests {

    static func runAll() -> [String] {
        var failures: [String] = []
        checkSingleWorkspace(failures: &failures)
        checkMultipleWorkspaces(failures: &failures)
        checkAppOrderPreserved(failures: &failures)
        checkDefaultsWhenOmitted(failures: &failures)
        checkMalformedProducesEmpty(failures: &failures)
        checkTopLevelOnlyLayoutAccepted(failures: &failures)
        checkCommentsIgnored(failures: &failures)
        checkAppCustomLayoutAndMonitor(failures: &failures)
        return failures
    }

    // MARK: - Expectation: one documented workspace -> exactly that workspace

    /// The flagship expectation: a KDL doc with one workspace declaring a layout,
    /// a monitor, and two apps must compile to a map with exactly that one
    /// workspace carrying all three, in order.
    private static func checkSingleWorkspace(failures: inout [String]) {
        let kdl = """
        layout {
          workspace "1: Web" {
            layout "monocle"
            monitor "External 4K"
            app "Brave"
            app "Slack"
          }
        }
        """
        let out = KdlWorkspaceCompiler.compile(kdl)
        guard out.count == 1, let ws = out["1: Web"] else {
            fail(&failures, "single workspace must compile to exactly one entry, got \(out.keys.sorted())")
            return
        }
        if ws.layout != "monocle" {
            fail(&failures, "workspace layout must be 'monocle', got \(ws.layout)")
        }
        if ws.monitor != "External 4K" {
            fail(&failures, "workspace monitor must be 'External 4K', got \(ws.monitor ?? "nil")")
        }
        if ws.apps != ["Brave", "Slack"] {
            fail(&failures, "workspace apps must be ['Brave','Slack'], got \(ws.apps)")
        }
    }

    // MARK: - Expectation: N documented workspaces -> N entries

    private static func checkMultipleWorkspaces(failures: inout [String]) {
        let kdl = """
        layout {
          workspace "1: Web" { app "Brave" }
          workspace "2: Code" {
            app "Ghostty"
            layout "bsp"
          }
        }
        """
        let out = KdlWorkspaceCompiler.compile(kdl)
        if out.count != 2 {
            fail(&failures, "two workspaces must compile to exactly two entries, got \(out.count)")
            return
        }
        if out["1: Web"] == nil || out["2: Code"] == nil {
            fail(&failures, "both workspace names must survive compilation, got \(out.keys.sorted())")
        }
    }

    // MARK: - Expectation: apps appear in the order the user declared them

    private static func checkAppOrderPreserved(failures: inout [String]) {
        let kdl = """
        layout {
          workspace "Tools" {
            app "Ghostty"
            app "com.figma.Desktop"
            app "Tower"
          }
        }
        """
        guard let ws = KdlWorkspaceCompiler.compile(kdl)["Tools"] else {
            fail(&failures, "order test workspace missing")
            return
        }
        if ws.apps != ["Ghostty", "com.figma.Desktop", "Tower"] {
            fail(&failures, "apps must preserve declaration order, got \(ws.apps)")
        }
    }

    // MARK: - Expectation: omitted fields fall back to sane defaults

    /// If the user writes only `app "X"` (no layout, no monitor), the workspace
    /// still exists with `bsp` layout, no monitor, and that one app — not a crash
    /// and not an empty apps list.
    private static func checkDefaultsWhenOmitted(failures: inout [String]) {
        let kdl = """
        layout {
          workspace "Minimal" { app "Notes" }
        }
        """
        guard let ws = KdlWorkspaceCompiler.compile(kdl)["Minimal"] else {
            fail(&failures, "defaults test workspace missing")
            return
        }
        if ws.layout != "bsp" { fail(&failures, "omitted layout must default to 'bsp', got \(ws.layout)") }
        if ws.monitor != nil { fail(&failures, "omitted monitor must default to nil, got \(ws.monitor ?? "nil")") }
        if ws.apps != ["Notes"] { fail(&failures, "omitted extras must keep the declared app, got \(ws.apps)") }
    }

    // MARK: - Expectation: a workspace with no apps still exists (a clean target)

    private static func checkAppCustomLayoutAndMonitor(failures: inout [String]) {
        let kdl = """
        layout {
          workspace "Empty" {
            layout "stack"
          }
        }
        """
        guard let ws = KdlWorkspaceCompiler.compile(kdl)["Empty"] else {
            fail(&failures, "workspace with no apps must still exist")
            return
        }
        if ws.layout != "stack" { fail(&failures, "workspace layout must be 'stack', got \(ws.layout)") }
        if ws.apps != [] { fail(&failures, "workspace with no apps must have empty apps, got \(ws.apps)") }
    }

    // MARK: - Expectation: empty/malformed documents are harmless

    private static func checkMalformedProducesEmpty(failures: inout [String]) {
        let inputs = ["", "   ", "not a valid doc", "layout { workspace {", "app 'Brave'"]
        for input in inputs {
            let out = KdlWorkspaceCompiler.compile(input)
            if !out.isEmpty {
                fail(&failures, "malformed/empty KDL must produce an empty map, got \(out.keys) for input '\(input)'")
            }
        }
    }

    // MARK: - Expectation: only a top-level `layout` block is read

    private static func checkTopLevelOnlyLayoutAccepted(failures: inout [String]) {
        // A stray top-level workspace (not wrapped in layout { }) contributes nothing.
        let kdl = """
        workspace "stray" {
          app "X"
        }
        layout {
          workspace "real" {
            app "Y"
          }
        }
        """
        let out = KdlWorkspaceCompiler.compile(kdl)
        if out["stray"] != nil {
            fail(&failures, "a workspace outside the top-level layout block must be ignored")
        }
        if out["real"] == nil {
            fail(&failures, "a workspace inside the layout block must be honoured")
        }
    }

    // MARK: - Expectation: KDL comments (// and /* */) are ignored

    private static func checkCommentsIgnored(failures: inout [String]) {
        let kdl = """
        // this is a comment
        layout {
          /* block
             comment */
          workspace "1: Code" {
            app "Ghostty" // trailing comment
          }
          // another comment
        }
        """
        let out = KdlWorkspaceCompiler.compile(kdl)
        guard let ws = out["1: Code"] else {
            fail(&failures, "comment-only noise must not break the workspace, got \(out.keys.sorted())")
            return
        }
        if ws.apps != ["Ghostty"] {
            fail(&failures, "comments must be ignored, got \(ws.apps)")
        }
    }

    private static func fail(_ failures: inout [String], _ label: String) {
        print("  FAIL  [kdl] \(label)")
        failures.append("[kdl] " + label)
    }
}
