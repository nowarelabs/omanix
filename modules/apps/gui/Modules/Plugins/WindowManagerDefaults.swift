// Modules/Plugins/WindowManagerDefaults.swift
// Live writer for macOS' Window management (Sequoia tiling) preferences. The GUI
// toggles write these to com.apple.WindowManager immediately (not only at rebuild),
// so toggle → effect is instant. The declarative darwin/omatiles.nix activation
// script also writes these on rebuild — both paths agree.

import Foundation

enum WindowManagerDefaults {

    private static let domain = "com.apple.WindowManager"

    /// Keys written by System Settings → Desktop & Dock → Window management.
    enum Key {
        static let edgeDrag   = "EnableTilingByEdgeDrag"
        static let accelerator = "EnableTilingWithAccelerator"
        static let margins    = "EnableTiledWindowMargins"
    }

    /// Set a single WindowManager boolean and restart the WindowManager to apply.
    static func apply(edgeDrag: Bool? = nil,
                      accelerator: Bool? = nil,
                      margins: Bool? = nil) {
        if let edgeDrag { Defaults.write(domain: domain, key: Key.edgeDrag, value: edgeDrag) }
        if let accelerator { Defaults.write(domain: domain, key: Key.accelerator, value: accelerator) }
        if let margins { Defaults.write(domain: domain, key: Key.margins, value: margins) }
        restartWindowManager()
    }

    /// Restart WindowManager so macOS picks up the new defaults immediately.
    static func restartWindowManager() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        p.arguments = ["WindowManager"]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
        p.waitUntilExit()
    }
}
