// Modules/Plugins/PluginItem.swift
// A SwiftUI-friendly projection of an OmanixPlugin for the Settings UI. It bundles
// the plugin's presentation data with its current persisted enabled/order state, so
// the UI stays generic and a plugin only ever needs to conform to OmanixPlugin.

import SwiftUI

struct PluginItem: Identifiable {
    let id: String
    let name: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let permissions: [OmanixPermission]
    var isEnabled: Bool

    init(_ plugin: any OmanixPlugin, isEnabled: Bool) {
        self.id = plugin.id
        self.name = plugin.name
        self.subtitle = plugin.subtitle
        self.symbol = plugin.symbol
        self.tint = Color(nsColor: plugin.tint)
        self.permissions = plugin.permissions
        self.isEnabled = isEnabled
    }
}
