// Modules/Omatiles/KdlWorkspaceCompiler.swift
//
// The "interpretation" half of the Interpreter pattern for the declarative KDL
// layout surface. It walks the `KdlNode` AST produced by `KdlParser` and emits
// exactly the `[String: WorkspaceConfig]` map that `RuntimeSettings.workspaces()`
// and `WorkspaceManager` already consume — so Owin's routing/tiling pipeline is
// unchanged and this bridge is purely additive.
//
// Accepted document shape (Zellij-style):
//
//   layout {
//     workspace "1: Web" {
//       layout "monocle"      // optional, default "bsp"
//       monitor "External 4K" // optional, default nil
//       app "Brave"           // repeatable, order preserved
//       app "Slack"
//     }
//   }
//
// Only the top-level `layout { }` block is read; anything outside it is ignored.
// A workspace outside the `layout` block, or a document that fails to parse,
// contributes nothing (no crash, no silently-broken config).

import Foundation

enum KdlWorkspaceCompiler {

    static func compile(_ text: String) -> [String: RuntimeSettings.WorkspaceConfig] {
        guard let roots = KdlParser.parse(text) else { return [:] }

        // Only a top-level `layout` node is the declarative surface.
        guard let layout = roots.first(where: { $0.name == "layout" }) else { return [:] }

        var out: [String: RuntimeSettings.WorkspaceConfig] = [:]
        for ws in layout.children where ws.name == "workspace" {
            // The workspace name is its first positional value (or a "name" property).
            guard let name = ws.args.first ?? ws.properties["name"], !name.isEmpty else { continue }

            var config = RuntimeSettings.WorkspaceConfig(monitor: nil, layout: "bsp", apps: [])
            for stmt in ws.children {
                switch stmt.name {
                case "layout":
                    config.layout = stmt.args.first ?? "bsp"
                case "monitor":
                    config.monitor = stmt.args.first
                case "app":
                    if let app = stmt.args.first, !app.isEmpty {
                        config.apps.append(app)   // order preserved
                    }
                default:
                    break // unknown child ignored, forward-compatible
                }
            }
            out[name] = config
        }
        return out
    }
}
