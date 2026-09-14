// Modules/Plugins/BuiltinPlugins.swift
// The built-in, user-facing plugins shipped with Omanix. Everything here is
// expressed through the OmanixPlugin protocol — nothing is hard-wired into the UI
// or menu bar code. To add a plugin, add a type here and register it in
// PluginRegistry.all (bottom of this file).

import AppKit
import Combine

// MARK: - Clock

struct ClockPlugin: OmanixPlugin {
    let id = "clock"
    let name = "Clock"
    let subtitle = "Time & date — click opens Calendar"
    let symbol = "clock"
    let tint = PlatformColor.systemPurple
    let permissions: [OmanixPermission] = []
    let isAvailable = true
    func menubarRenderer() -> (any OmanixMenubarRenderer)? { ClockRenderer() }
}

// MARK: - Battery

struct BatteryPlugin: OmanixPlugin {
    let id = "battery"
    let name = "Battery"
    let subtitle = "Charge level, bolt while charging"
    let symbol = "battery.100"
    let tint = PlatformColor.systemGreen
    let permissions: [OmanixPermission] = []
    let isAvailable = true
    func menubarRenderer() -> (any OmanixMenubarRenderer)? { BatteryRenderer() }
}

// MARK: - Volume

struct VolumePlugin: OmanixPlugin {
    let id = "volume"
    let name = "Volume"
    let subtitle = "Volume level — click to mute"
    let symbol = "speaker.wave.2"
    let tint = PlatformColor.systemOrange
    let permissions: [OmanixPermission] = []
    let isAvailable = true
    func menubarRenderer() -> (any OmanixMenubarRenderer)? { VolumeRenderer() }
}

// MARK: - Wi-Fi

struct WifiPlugin: OmanixPlugin {
    let id = "wifi"
    let name = "Wi-Fi"
    let subtitle = "Connected network, or off"
    let symbol = "wifi"
    let tint = PlatformColor.systemBlue
    let permissions: [OmanixPermission] = []
    let isAvailable = true
    func menubarRenderer() -> (any OmanixMenubarRenderer)? { WifiRenderer() }
}

// MARK: - Running Apps

struct AppsPlugin: OmanixPlugin {
    let id = "apps"
    let name = "Running Apps"
    let subtitle = "Switch between open apps"
    let symbol = "square.grid.2x2"
    let tint = PlatformColor.systemTeal
    let permissions: [OmanixPermission] = [.screenRecording]
    let isAvailable = true
    func menubarRenderer() -> (any OmanixMenubarRenderer)? { AppsRenderer() }
}

// MARK: - Focus (Do Not Disturb)

struct FocusPlugin: OmanixPlugin {
    let id = "focus"
    let name = "Focus"
    let subtitle = "Toggle Do Not Disturb in one click"
    let symbol = "moon.fill"
    let tint = PlatformColor.systemIndigo
    let permissions: [OmanixPermission] = []
    let isAvailable = true
    func menubarRenderer() -> (any OmanixMenubarRenderer)? { FocusRenderer() }
}

// MARK: - Now Playing

struct NowPlayingPlugin: OmanixPlugin {
    let id = "nowplaying"
    let name = "Now Playing"
    let subtitle = "From the current media app"
    let symbol = "music.note"
    let tint = PlatformColor.systemPink
    let permissions: [OmanixPermission] = [.screenRecording]
    let isAvailable = true
    func menubarRenderer() -> (any OmanixMenubarRenderer)? { NowPlayingRenderer() }
}

// MARK: - Clipboard

struct ClipboardPlugin: OmanixPlugin {
    let id = "clipboard"
    let name = "Clipboard"
    let subtitle = "Recent copies at a glance"
    let symbol = "doc.on.clipboard"
    let tint = PlatformColor.systemGray
    let permissions: [OmanixPermission] = [.fullDisk]
    let isAvailable = true
    func menubarRenderer() -> (any OmanixMenubarRenderer)? { ClipboardRenderer() }
}

// MARK: - Registry

enum PluginRegistry {
    /// All known plugins, in their default (installation) order. The user can
    /// reorder / hide any of these; that choice is persisted separately.
    static let all: [any OmanixPlugin] = [
        AppsPlugin(),
        ClockPlugin(),
        BatteryPlugin(),
        VolumePlugin(),
        WifiPlugin(),
        FocusPlugin(),
        NowPlayingPlugin(),
        ClipboardPlugin(),
    ]

    static func plugin(id: String) -> (any OmanixPlugin)? {
        all.first { $0.id == id }
    }
}
