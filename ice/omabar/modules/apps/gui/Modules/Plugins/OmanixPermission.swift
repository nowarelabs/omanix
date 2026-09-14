// Modules/Plugins/OmanixPermission.swift
// A permission a plugin (or module) may require from macOS. Kept framework-light
// (Foundation + AppKit only) so both the menu bar module and the GUI can use it.
//
// Each permission knows how to read its own current status and how to direct the
// user to grant it. This is the single source of truth the UI renders, so "which
// permissions do I still need to grant" is always discoverable and grantable.

import Foundation
import AppKit
import ApplicationServices

enum OmanixPermission: String, CaseIterable, Identifiable, Hashable {
    case accessibility
    case screenRecording
    case network
    case fullDisk

    var id: String { rawValue }

    // MARK: Presentation

    /// Short, user-facing name (shown as a row title).
    var title: String {
        switch self {
        case .accessibility:    return "Accessibility"
        case .screenRecording:  return "Screen Recording"
        case .network:          return "Network"
        case .fullDisk:         return "Full Disk Access"
        }
    }

    /// What the permission is actually used for (shown as the row subtitle).
    var explanation: String {
        switch self {
        case .accessibility:    return "Let Omanix post the ⌘⌥ tiling shortcuts and control windows."
        case .screenRecording:  return "Read window titles so plugins can show what is open."
        case .network:          return "Check reachability or query local services plugins need."
        case .fullDisk:         return "Read/mark files that live outside the sandbox where needed."
        }
    }

    /// Which plugin surface typically needs this (informational category label).
    var category: String {
        switch self {
        case .accessibility:    return "Tiling & shortcuts"
        case .screenRecording:  return "Desktop snapshot"
        case .network:          return "Network"
        case .fullDisk:         return "Storage"
        }
    }

    // MARK: Status

    /// Current granted/denied state for this permission.
    var granted: Bool {
        switch self {
        case .accessibility:   return AXIsProcessTrusted()
        case .screenRecording: return hasScreenRecordingGrant()
        case .network:         return true   // no persistent grant gate; reported granted
        case .fullDisk:        return hasFullDiskGrant()
        }
    }

    /// Deep-link to the exact System Settings pane so the user can grant it in one click.
    /// Returns the pane identifier (nil when only the generic Privacy & Security pane exists).
    func systemSettingsPane() -> String? {
        switch self {
        case .accessibility:   return "Privacy_Accessibility"
        case .screenRecording: return "Privacy_ScreenCapture"
        case .network:         return nil
        case .fullDisk:        return "Privacy_AllFiles"
        }
    }

    /// Opens System Settings at the right pane. Call from a UI action.
    func openSettings() {
        guard let pane = systemSettingsPane() else { return }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Private checks

    /// Screen Recording is keyed to a CGWindowList snapshot failing to include
    /// titles when not granted — there is no public API. We approximate by seeing
    /// whether window titles are actually readable for another app.
    private func hasScreenRecordingGrant() -> Bool {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        for info in list {
            let layer = (info[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 1
            if layer == 0,
               let name = info[kCGWindowName as String] as? String,
               !name.isEmpty,
               (info[kCGWindowOwnerName as String] as? String) != "Window Server" {
                return true
            }
        }
        return false
    }

    /// Full Disk Access: any file outside a standard sandbox is unreadable when
    /// denied. We probe a home file (the user's own config) which is always inside
    /// the sandbox — so instead probe an obviously-outside path that needs FDA.
    private func hasFullDiskGrant() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        // ~/Library/Application Support is outside the default sandbox; unreadable without FDA.
        let probe = home.appendingPathComponent("Library/Application Support")
        return (try? FileManager.default.contentsOfDirectory(atPath: probe.path)) != nil
    }
}
