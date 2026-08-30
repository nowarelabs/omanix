// Modules/Plugins/OmanixPlugin.swift
// The core plugin contract for Omanix. A plugin describes something the user can
// add to the system — most commonly a menu bar (status) item — together with any
// macOS permissions it needs. The UI is generic: it lists plugins from the registry
// and lets the user reorder / enable / disable them. The runtime wires enabled
// plugins into our renderers.
//
// To BUILD YOUR OWN PLUGIN you only have to:
//   1. Conform to OmanixPlugin (id, name, subtitle, symbol, tint).
//   2. Optionally specify `permissions` it needs.
//   3. Optionally return a `menubarRenderer()` so it appears as a status item.
//   4. Register it in `PluginRegistry.all` — from there it shows up everywhere
//      (Settings list, menu bar, permission screen) with no other wiring.
//
// Menubar renderers use AppKit so they can return NSStatusItem content; the plugin
// definition itself stays data-only so it is trivially testable.

import AppKit

/// The color type plugins express their tint in. AppKit so the menu bar renderers
/// (NSStatusItem icons) can use it directly; the SwiftUI UI converts via .nsColor.
typealias PlatformColor = NSColor

/// A single plugin offered to the user. Conforming types are value-like and cheap.
protocol OmanixPlugin {
    /// Stable identifier used for persistence (must not change between launches).
    var id: String { get }
    /// User-facing name.
    var name: String { get }
    /// Short tagline shown under the name.
    var subtitle: String { get }
    /// SF Symbol used for the icon tile and menu bar glyph (template).
    var symbol: String { get }
    /// Tint used for the icon tile in the UI.
    var tint: PlatformColor { get }
    /// Permissions this plugin may require (empty when none).
    var permissions: [OmanixPermission] { get }
    /// Whether this plugin is available on the current system (e.g. macOS version).
    var isAvailable: Bool { get }
    /// When non-nil, this plugin renders as a menu bar status item.
    /// The renderer is instantiated once per plugin when enabled.
    @MainActor
    func menubarRenderer() -> (any OmanixMenubarRenderer)?
}

/// A renderable status item for the native macOS menu bar. Implement once per
/// plugin, reuse across reorders/enables automatically.
@MainActor
protocol OmanixMenubarRenderer: AnyObject {
    /// Called before the item is shown; add your NSStatusItem(s) to the bar.
    func install(into manager: OmanixMenubarHost)
    /// Re-push current values into the status item(s). Called on model change.
    func refresh()
    /// Called before the item is removed from the menu bar.
    func uninstall()
    /// Clicked action for the primary button (nil to open the plugin's menu).
    var primaryAction: Selector? { get }
    /// Target for the primary action (recommend the renderer itself).
    var actionTarget: AnyObject? { get }
}

/// Minimal host surface the manager exposes to a renderer (install helpers).
@MainActor
protocol OmanixMenubarHost: AnyObject {
    /// Create a variable-length NSStatusItem owned by the host.
    func makeStatusItem(menuable: Bool) -> NSStatusItem
    /// A ready-to-use menu assigned to the item (when menuable).
    func menu(for item: NSStatusItem) -> NSMenu
}
