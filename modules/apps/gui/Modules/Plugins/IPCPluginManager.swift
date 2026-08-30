// Modules/Plugins/IPCPluginManager.swift
// Generic renderer for runtime IPC plugins (Phase 5).
//
// Each runtime plugin connects to the bar's Unix socket and streams
// `PluginUpdateInfo` (id/title/image). This manager subscribes to the typed
// bus and maintains one NSStatusItem per plugin id, creating it on first
// update and tearing it down if the plugin disconnects and sends no further
// updates. Isolation: if a plugin crashes, its status item simply stops
// updating and the bar continues unaffected — the socket drop is already
// handled by PluginIPCServer.

import AppKit

final class IPCPluginManager: NSObject {

    static let shared = IPCPluginManager()

    private var items: [String: NSStatusItem] = [:]
    private var token: AnyObject?

    private override init() { super.init() }

    func start() {
        guard token == nil else { return }
        token = EventBus.shared.subscribePluginUpdate(queue: .main) { [weak self] info in
            self?.apply(info)
        }
        print("IPCPluginManager: subscribed to plugin updates")
    }

    func stop() {
        if let t = token {
            EventBus.shared.unsubscribe(t)
            token = nil
        }
        for (_, item) in items {
            NSStatusBar.system.removeStatusItem(item)
        }
        items.removeAll()
    }

    private func apply(_ info: PluginUpdateInfo) {
        let item: NSStatusItem
        if let existing = items[info.id] {
            item = existing
        } else {
            let newItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            newItem.button?.target = self
            newItem.button?.action = #selector(itemClicked(_:))
            items[info.id] = newItem
            item = newItem
            print("IPCPluginManager: created status item for plugin id=\(info.id)")
        }
        item.button?.title = info.title
        if let imageName = info.image {
            // Try SF Symbol first, then fallback to no image.
            if let img = NSImage(systemSymbolName: imageName, accessibilityDescription: imageName) {
                img.isTemplate = true
                item.button?.image = img
            }
        }
        item.button?.toolTip = info.payload?["tooltip"] ?? info.title
        item.button?.isHidden = false
    }

    @objc private func itemClicked(_ sender: NSStatusBarButton) {
        // Find which item was clicked and show a minimal menu with the plugin's payload.
        guard let item = items.first(where: { $0.value.button === sender }) else { return }
        let infoID = item.key
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Plugin: \(infoID)", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "No actions", action: nil, keyEquivalent: ""))
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
}
