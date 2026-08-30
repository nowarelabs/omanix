// tests/behavior/SystemEffectReader.swift
// Service 2 — reads the effect on the target system.
//
// After `UserActionSimulator` does something, this service inspects what
// actually happened on the macOS target: window frames via AX/CGWindowList,
// tiling prefs via `defaults`, theme via Omanix. It mirrors how a user would
// verify the result visually, but programmatically.

import Foundation
import AppKit
import ApplicationServices
import CoreGraphics

enum EffectReaderError: LocalizedError {
    case noWindow
    case axFailed(String)
}

struct TilingPrefs: Equatable {
    var edgeDrag: Bool
    var accelerator: Bool
    var margins: Bool
}

enum SystemEffectReader {

    // MARK: - Tiling prefs (com.apple.WindowManager)

    static func tilingPrefs() -> TilingPrefs {
        func readBool(_ key: String, fallback: Bool) -> Bool {
            let v = UserDefaults(suiteName: "com.apple.WindowManager")?.object(forKey: key)
            if let b = v as? Bool { return b }
            if let n = v as? Int { return n != 0 }
            return fallback
        }
        // Also try `defaults read` as fallback (suite may be cached).
        let suite = UserDefaults(suiteName: "com.apple.WindowManager")
        return TilingPrefs(
            edgeDrag: suite?.object(forKey: "EnableTilingByEdgeDrag") as? Bool ?? true,
            accelerator: suite?.object(forKey: "EnableTilingWithAccelerator") as? Bool ?? true,
            margins: suite?.object(forKey: "EnableTiledWindowMargins") as? Bool ?? false
        )
    }

    static func tilingPrefsViaDefaults() -> TilingPrefs {
        func shell(_ key: String) -> String {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
            p.arguments = ["read", "com.apple.WindowManager", key]
            let pipe = Pipe()
            p.standardOutput = pipe
            try? p.run()
            p.waitUntilExit()
            return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        return TilingPrefs(
            edgeDrag: shell("EnableTilingByEdgeDrag") == "1",
            accelerator: shell("EnableTilingWithAccelerator") == "1",
            margins: shell("EnableTiledWindowMargins") == "1"
        )
    }

    // MARK: - Window frame via AX

    /// Returns the frame of the frontmost window for the given pid, via AX.
    /// Requires Accessibility.
    static func windowFrame(pid: pid_t) throws -> CGRect {
        let app = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement],
              let front = windows.first else {
            throw EffectReaderError.noWindow
        }
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(front, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(front, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let posVal = posRef, let sizeVal = sizeRef else {
            throw EffectReaderError.axFailed("Could not read position/size")
        }
        var pos = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posVal as! AXValue, .cgPoint, &pos)
        AXValueGetValue(sizeVal as! AXValue, .cgSize, &size)
        return CGRect(origin: pos, size: size)
    }

    /// Fallback via CGWindowList (no AX needed, but less precise — includes window chrome).
    static func windowFrameViaCG(pid: pid_t) -> CGRect? {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return nil }
        for entry in list where (entry[kCGWindowOwnerPID as String] as? Int32) == pid {
            if let bounds = entry[kCGWindowBounds as String] as? [String: Any],
               let x = bounds["X"] as? CGFloat, let y = bounds["Y"] as? CGFloat,
               let w = bounds["Width"] as? CGFloat, let h = bounds["Height"] as? CGFloat {
                return CGRect(x: x, y: y, width: w, height: h)
            }
        }
        return nil
    }

    // MARK: - Omanix declarative state (via Omanix reader)

    static func omabarState() -> OmabarState {
        Omanix().currentOmabarState()
    }

    static func omatilesState() -> OmatilesState {
        Omanix().currentOmatilesState()
    }

    static func theme() -> String {
        // Prefer the declarative state file (what `setTheme` writes) over the
        // cached theme.json (which only updates after a rebuild).
        Omanix().readOption("omanix.theme") ?? Omanix().currentThemeId()
    }

    // MARK: - Screen

    static func mainScreenFrame() -> CGRect {
        NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
    }
}
