// Modules/Plugins/Defaults.swift
// Thin wrapper over `/usr/bin/defaults` for writing macOS preference domains that
// don't play well with UserDefaults (e.g. the menu bar auto-hide preference which
// lives in com.apple.universalaccess). Small and synchronous like PluginShell.

import Foundation

enum Defaults {
    /// Write a value into a macOS preferences domain via `defaults write`.
    static func write(domain: String = "com.apple.universalaccess", key: String, value: Any) {
        let args: [String]
        if let bool = value as? Bool {
            args = ["write", domain, key, "-bool", bool ? "YES" : "NO"]
        } else if let int = value as? Int {
            args = ["write", domain, key, "-int", String(int)]
        } else if let str = value as? String {
            args = ["write", domain, key, "-string", str]
        } else {
            args = ["write", domain, key, "\(value)"]
        }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
        p.waitUntilExit()
    }
}
