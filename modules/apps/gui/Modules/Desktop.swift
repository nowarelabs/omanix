// Modules/Desktop.swift
// A tiny, framework-light window snapshot shared by the Omabar (workspace/app pills)
// and Omatiles (tiling candidates) runtimes. CGWindowList requires no permissions,
// so both modules can introspect the desktop without Accessibility being granted.

import Foundation
import CoreGraphics
import AppKit

enum Desktop {

    struct Window {
        let pid: pid_t
        let owner: String
        let title: String
        let frame: CGRect
        let layer: Int
        var number: CGWindowID
    }

    /// All normal, on-screen windows of other apps (layer 0, sizable, not our own).
    static func snapshot(excludingOwnPID ownPID: Int32 = ProcessInfo.processInfo.processIdentifier) -> [Window] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        var windows: [Window] = []
        for info in list {
            guard let pidNum = info[kCGWindowOwnerPID as String] as? NSNumber else { continue }
            let pid = pidNum.int32Value
            if pid == ownPID { continue }

            let layer = (info[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 1
            guard layer == 0 else { continue }

            let bounds = info[kCGWindowBounds as String] as? [String: Any]
            let frame = CGRect(
                x: (bounds?["X"] as? NSNumber)?.doubleValue ?? 0,
                y: (bounds?["Y"] as? NSNumber)?.doubleValue ?? 0,
                width: (bounds?["Width"] as? NSNumber)?.doubleValue ?? 0,
                height: (bounds?["Height"] as? NSNumber)?.doubleValue ?? 0
            )
            guard frame.width >= 120, frame.height >= 80 else { continue }

            let owner = (info[kCGWindowOwnerName as String] as? String) ?? ""
            guard !owner.isEmpty, owner != "Window Server" else { continue }

            windows.append(Window(
                pid: pid,
                owner: owner,
                title: (info[kCGWindowName as String] as? String) ?? "",
                frame: frame,
                layer: layer,
                number: CGWindowID(truncating: (info[kCGWindowNumber as String] as? NSNumber) ?? 0)
            ))
        }

        // Stable order: top-most (maxY) first, then leftmost.
        windows.sort { a, b in
            let ay = 1_000_000 - a.frame.maxY
            let by = 1_000_000 - b.frame.maxY
            if abs(ay - by) > 1 { return ay < by }
            return a.frame.minX < b.frame.minX
        }
        return windows
    }

    /// A running app on screen, keyed by pid so multiple windows of the same app
    /// collapse into one menu entry (the Omabar app switcher shows apps, not windows).
    struct VisibleApp {
        let pid: pid_t
        let name: String
    }

    /// Distinct on-screen apps (highest window first), each with its pid.
    static func visibleApps(excludingOwnPID ownPID: Int32 = ProcessInfo.processInfo.processIdentifier) -> [VisibleApp] {
        var seen = Set<pid_t>()
        var result: [VisibleApp] = []
        for window in snapshot(excludingOwnPID: ownPID) {
            guard !seen.contains(window.pid) else { continue }
            seen.insert(window.pid)
            result.append(VisibleApp(pid: window.pid, name: window.owner))
        }
        return result
    }
}