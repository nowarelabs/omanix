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
        // Resolve the app for this pid to get bundleID.
        let app = NSRunningApplication(processIdentifier: pid)
        let bundleID = app?.bundleIdentifier ?? "unknown"
        if notification == kAXWindowCreatedNotification as String {
            let ws = workspace(for: bundleID)
            print("WorkspaceManager: AX window created pid=\(pid) bundleID=\(bundleID) workspace=\(ws ?? "default")")
            EventBus.shared.publish(windowCreated: WindowCreatedInfo(pid: pid, bundleID: bundleID, workspace: ws))
            // Future: layout engine decides frame via AXUIElementSetAttributeValue
            // for kAXPositionAttribute / kAXSizeAttribute based on workspace.layout.
        } else if notification == kAXFocusedWindowChangedNotification as String {
            EventBus.shared.publish(windowFocused: WindowFocusedInfo(pid: pid, bundleID: bundleID))
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
