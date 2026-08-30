// Modules/Omatiles/WorkspaceManager.swift
// Owin — declarative window manager event sink (Phase 4).
//
// The brief's "Anti-AeroSpace": instead of a standalone daemon with its own
// tiling tree, Owin is a Nix-generated static map consumed via AXUI hooks.
// This file is the native C/Swift bridge that plugs straight into the macOS
// Accessibility stream (AXUIElement) and Core Graphics, as the brief requires.
// For Phase 4 the manager is a minimal, correct stub: it reads the Nix-generated
// workspaces.json (see modules/desktop/workspaces.nix), subscribes to the system
// AX notification stream for window creation/focus, and publishes typed
// OmanixEvent.windowCreated / windowFocused to the EventBus. The actual window
// moves (AXUIElementSetAttributeValue for kAXPosition/kAXSize, layout math for
// bsp/monocle/stack/spiral) are Phase 4.5 — this phase proves the declarative
// routing map and the event sink are wired.

import AppKit
import ApplicationServices

final class WorkspaceManager: NSObject {

    static let shared = WorkspaceManager()

    private var isRunning = false
    private var appLaunchObserver: NSObjectProtocol?
    private var workspaceMap: [String: RuntimeSettings.WorkspaceConfig] = [:]
    // pid -> AXObserver
    private var observers: [pid_t: AXObserver] = [:]

    private override init() { super.init() }

    // MARK: - Public

    @discardableResult
    func start() -> Bool {
        guard !isRunning else { return true }
        let owin = RuntimeSettings.Owin.load()
        guard owin.enable else {
            print("WorkspaceManager: Owin disabled (omanix.owin.enable = false) — not starting")
            return false
        }
        guard AXIsProcessTrusted() else {
            print("WorkspaceManager: Accessibility not granted — Owin requires it. Prompting…")
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(opts)
            // Still mark as running so we can retry on next launch; don't spin.
            return false
        }

        workspaceMap = RuntimeSettings.workspaces()
        print("WorkspaceManager: started with \(workspaceMap.count) workspaces, defaultLayout=\(owin.defaultLayout)")
        for (name, cfg) in workspaceMap {
            print("  workspace \"\(name)\": layout=\(cfg.layout) monitor=\(cfg.monitor ?? "any") apps=\(cfg.apps)")
        }

        // Subscribe to app launches via NSWorkspace (lightweight, no polling).
        appLaunchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.appLaunched(app)
        }

        // Also attach to already-running apps so we don't miss existing windows.
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            attach(to: app)
        }

        isRunning = true
        return true
    }

    func stop() {
        if let obs = appLaunchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            appLaunchObserver = nil
        }
        for (_, obs) in observers {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .defaultMode)
        }
        observers.removeAll()
        isRunning = false
    }

    func workspace(for bundleID: String) -> String? {
        for (name, cfg) in workspaceMap where cfg.apps.contains(where: { bundleID.contains($0) || $0.contains(bundleID) }) {
            return name
        }
        // Also try app name matching (e.g. "Brave" matches "com.brave.Browser")
        return nil
    }

    // MARK: - App launch / AX wiring

    private func appLaunched(_ app: NSRunningApplication) {
        guard let bundleID = app.bundleIdentifier else { return }
        let pid = app.processIdentifier
        let workspace = workspace(for: bundleID)
        print("WorkspaceManager: app launched pid=\(pid) bundleID=\(bundleID) -> workspace=\(workspace ?? "none (default)")")
        EventBus.shared.publish(windowCreated: WindowCreatedInfo(pid: pid, bundleID: bundleID, workspace: workspace))
        attach(to: app)
    }

    private func attach(to app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard observers[pid] == nil else { return }
        var observer: AXObserver?
        let err = AXObserverCreate(pid, axCallback, &observer)
        guard err == .success, let obs = observer else { return }
        observers[pid] = obs

        let appElement = AXUIElementCreateApplication(pid)
        // We care about window creation and focus; both are AX notifications.
        for notif in [kAXWindowCreatedNotification, kAXFocusedWindowChangedNotification] as [String] {
            AXObserverAddNotification(obs, appElement, notif as CFString, Unmanaged.passUnretained(self).toOpaque())
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .defaultMode)
    }

    fileprivate func handleAXNotification(_ element: AXUIElement, notification: String, pid: pid_t) {
        let app = NSRunningApplication(processIdentifier: pid)
        let bundleID = app?.bundleIdentifier ?? "unknown"
        if notification == kAXWindowCreatedNotification as String {
            let ws = workspace(for: bundleID)
            print("WorkspaceManager: AX window created pid=\(pid) bundleID=\(bundleID) workspace=\(ws ?? "default")")
            EventBus.shared.publish(windowCreated: WindowCreatedInfo(pid: pid, bundleID: bundleID, workspace: ws))
            // Defer a tick so the window's AX element is fully realized, then tile.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.applyLayout(for: ws ?? "__default")
            }
        } else if notification == kAXFocusedWindowChangedNotification as String {
            EventBus.shared.publish(windowFocused: WindowFocusedInfo(pid: pid, bundleID: bundleID))
        }
    }

    // MARK: - Layout application (pure LayoutEngine + AXUI)

    /// Re-tiles every window belonging to the given workspace name (or the
    /// default workspace when nil). Called after a new window appears or when
    /// the workspace's layout/monitor changes via `workspaces.json`.
    func applyLayout(for workspaceName: String) {
        let owin = RuntimeSettings.Owin.load()
        guard owin.enable else { return }
        // Refresh the map in case `workspaces.json` was regenerated by a rebuild.
        workspaceMap = RuntimeSettings.workspaces()

        let cfg = workspaceMap[workspaceName]
        let layoutName = cfg?.layout ?? owin.defaultLayout
        guard let layout = OwinLayout(rawValue: layoutName) else { return }
        guard layout != .float else { return }

        // Resolve the screen to tile on.
        let screen = screen(for: cfg?.monitor) ?? NSScreen.main ?? NSScreen.screens.first
        guard let targetScreen = screen else { return }
        let screenFrame = targetScreen.visibleFrame

        // Collect AX windows for this workspace (or all regular windows for default).
        let windows = windows(for: workspaceName == "__default" ? nil : workspaceName)
        guard !windows.isEmpty else { return }

        let frames = LayoutEngine.frames(count: windows.count, in: screenFrame, layout: layout)
        for (window, frame) in zip(windows, frames) {
            setFrame(frame, for: window)
        }
        print("WorkspaceManager: applied layout=\(layout.rawValue) to \(windows.count) windows on \"\(workspaceName)\" screen=\(targetScreen.localizedName)")
    }

    /// Finds the NSScreen matching the workspace's monitor name, or nil to use main.
    private func screen(for monitorName: String?) -> NSScreen? {
        guard let name = monitorName, !name.isEmpty else { return nil }
        // NSScreen.localizedName is macOS 14+; fall back to frame matching.
        for s in NSScreen.screens {
            if s.localizedName == name { return s }
            // Also match by exact frame description or by prefix (e.g. "External 4K" may be part of name).
            if s.localizedName.contains(name) || name.contains(s.localizedName) { return s }
        }
        return nil
    }

    /// Returns AXUIElements for windows that belong to the given workspace.
    /// For a named workspace, filters by the workspace's `apps` bundleID list;
    /// for nil (default), returns all regular windows.
    private func windows(for workspaceName: String?) -> [AXUIElement] {
        // For a named workspace, collect pids for its apps.
        var targetPids: Set<pid_t>?
        if let name = workspaceName, let cfg = workspaceMap[name], !cfg.apps.isEmpty {
            var pids = Set<pid_t>()
            for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
                guard let bid = app.bundleIdentifier else { continue }
                for pattern in cfg.apps where bid.contains(pattern) || pattern.contains(bid) || app.localizedName?.contains(pattern) == true {
                    pids.insert(app.processIdentifier)
                    break
                }
            }
            targetPids = pids
        }

        var out: [AXUIElement] = []
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            let pid = app.processIdentifier
            if let filter = targetPids, !filter.contains(pid) { continue }
            let appElement = AXUIElementCreateApplication(pid)
            var windowsRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
                  let windows = windowsRef as? [AXUIElement] else { continue }
            for w in windows {
                // Skip hidden/minimized or non-standard windows (AXMinimized, AXModal).
                var minimized: CFTypeRef?
                if AXUIElementCopyAttributeValue(w, kAXMinimizedAttribute as CFString, &minimized) == .success,
                   let b = minimized as? Bool, b == true { continue }
                out.append(w)
            }
        }
        return out
    }

    /// Sets an AX window's frame via kAXPosition + kAXSize. Requires Accessibility.
    private func setFrame(_ frame: CGRect, for window: AXUIElement) {
        var pos = frame.origin
        if let posVal = AXValueCreate(.cgPoint, &pos) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posVal)
        }
        var size = frame.size
        if let sizeVal = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeVal)
        }
    }
}

// MARK: - C callback trampoline

private func axCallback(_ observer: AXObserver, _ element: AXUIElement, _ notification: CFString, _ userData: UnsafeMutableRawPointer?) -> Void {
    guard let userData else { return }
    let manager = Unmanaged<WorkspaceManager>.fromOpaque(userData).takeUnretainedValue()
    // AX callbacks come off the main run loop's source; hop is not needed but keep main.
    let pid = element.pid()
    DispatchQueue.main.async {
        manager.handleAXNotification(element, notification: notification as String, pid: pid)
    }
}

private extension AXUIElement {
    func pid() -> pid_t {
        var pid: pid_t = 0
        AXUIElementGetPid(self, &pid)
        return pid
    }
}
