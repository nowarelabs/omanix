// plugins/spotify-demo/SpotifyPlugin.swift
// Demo compile-time plugin: a Spotify Now-Playing widget compiled into the bar.
//
// To use it, add a flake input and set in configuration.nix:
//   omanix.plugins.compileTime.spotify.src = inputs.spotify-demo;
// Or for a local path:
//   omanix.plugins.compileTime.spotify.src = ./plugins/spotify-demo;
// On next `omanix rebuild`, the activation script copies this file into
// `~/.omanix/modules/apps/gui/Modules/Plugins/` before swiftc, so it becomes
// part of the bar binary — hermetic, with no runtime shell cost.

import AppKit

struct SpotifyPlugin: OmanixPlugin {
    let id = "spotify"
    let name = "Spotify"
    let subtitle = "Now playing from Spotify — compile-time demo"
    let symbol = "music.note.list"
    let tint = PlatformColor.systemGreen
    let permissions: [OmanixPermission] = []
    let isAvailable = true
    func menubarRenderer() -> (any OmanixMenubarRenderer)? { SpotifyRenderer() }
}

final class SpotifyRenderer: OmanixMenubarRenderer {
    private var item: NSStatusItem?
    weak var host: (any OmanixMenubarHost)?
    var primaryAction: Selector? { nil }
    var actionTarget: AnyObject? { self }

    func install(into manager: any OmanixMenubarHost) {
        host = manager
        let status = manager.makeStatusItem(menuable: false)
        status.button?.target = self
        status.button?.action = #selector(showMenu(_:))
        status.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        item = status
        refresh()
        // In a real plugin, this would subscribe to a Now-Playing EventBus via
        // a Rust crate's FFI or a Swift package's notification, not poll.
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        // Demo: would query Spotify's AppleScript or MPRIS in a real build.
        item?.button?.title = "♫ Demo"
        item?.button?.image = NSImage(systemSymbolName: "music.note.list", accessibilityDescription: "spotify")
        item?.button?.image?.isTemplate = true
    }

    func uninstall() {
        if let item { NSStatusBar.system.removeStatusItem(item) }
        item = nil
    }

    @objc private func showMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Spotify — compile-time plugin demo", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Open Spotify", action: #selector(openSpotify), keyEquivalent: ""))
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
    @objc private func openSpotify() {
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/Applications/Spotify.app"), configuration: NSWorkspace.OpenConfiguration())
    }
}
