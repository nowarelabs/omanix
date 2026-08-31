// Modules/Omatiles/KdlWorkspaceCompiler.swift
//
// The "interpretation" half of the Interpreter pattern for the declarative KDL
// layout surface. It walks the AST produced by the vendored KDL library
// (Modules/Kdl), a spec-complete KDL 1.0/2.0 parser, and emits exactly the
// `[String: WorkspaceConfig]` map that `RuntimeSettings.workspaces()` and
// `WorkspaceManager` already consume — so Owin's routing/tiling pipeline is
// unchanged and this bridge is purely additive.
//
// Parsing (KDL) and interpretation (this file) are kept separate: the compiler
// knows nothing about KDL grammar, and the KDL library knows nothing about
// workspaces. Each is independently testable and swappable (separation of
// concerns).
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
        // The vendored parser throws on malformed input; a broken document must
        // degrade to an empty, harmless map — never throw past this boundary.
        let document: KDLDocument
        do {
            document = try KDL.parseDocument(text, version: 2)
        } catch {
            return [:]
        }

        // Only a top-level `layout` node is the declarative surface.
        guard let layout = document.nodes.first(where: { $0.name == "layout" }) else { return [:] }

        var out: [String: RuntimeSettings.WorkspaceConfig] = [:]
        for ws in layout.children where ws.name == "workspace" {
            // The workspace name is its first positional argument.
            guard let name = stringValue(ws.arguments.first), !name.isEmpty else { continue }

            var config = RuntimeSettings.WorkspaceConfig(monitor: nil, layout: "bsp", apps: [])
            for stmt in ws.children {
                switch stmt.name {
                case "layout":
                    config.layout = stringValue(stmt.arguments.first) ?? "bsp"
                case "monitor":
                    config.monitor = stringValue(stmt.arguments.first)
                case "app":
                    if let app = stringValue(stmt.arguments.first), !app.isEmpty {
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

    /// Extract the text a KDL value represents. Favours the `.string` case (our
    /// workspace/app/layout/monitor values) and falls back to the value's own
    /// KDL representation so non-string literals still round-trip safely.
    private static func stringValue(_ value: KDLValue?) -> String? {
        guard let value else { return nil }
        if case .string(let s, _, _) = value { return s }
        return String(describing: value)
    }
}
