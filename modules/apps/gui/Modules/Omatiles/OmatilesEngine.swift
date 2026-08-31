// Modules/Omatiles/OmatilesEngine.swift
// Omatiles — a thin bridge onto macOS Sequoia's BUILT-IN window tiling.
//
// There is deliberately NO layout engine here: no rect math, no per-monitor work
// areas, no AX window matching, no watch mode. macOS already tiles windows (drag
// to a screen edge, ⌃⌥+arrow keyboard shortcuts, tiled margins) — Omatiles only:
//   1. re-binds our own keys (⌘⌥+arrows / ⌘⌥Z) to the platform's ⌃⌥+arrow
//      shortcuts by synthesizing those key events, and
//   2. leaves the System Settings "Window management" switches to the declarative
//      defaults in darwin/omatiles.nix.
// Runs either as a standalone module process ("--omatiles") or inside the GUI.
//
// Keyboard bindings (when `omanix.omatiles.bindings` is enabled):
//   ⌘⌥←  tile left half        ⌘⌥→  tile right half
//   ⌘⌥↑  tile top half         ⌘⌥↓  tile bottom half
//   ⌘⌥Z  untile (restore)

import Foundation
import AppKit
import CoreGraphics
import Carbon.HIToolbox

@MainActor
final class OmatilesEngine {

    static let shared = OmatilesEngine()

    private(set) var isRunning = false

    private var settings: RuntimeSettings.Omatiles = .load()

    /// Carbon hot-key registration, one ref per binding id.
    private var hotKeyRefs: [Int: EventHotKeyRef] = [:]
    private static var hotKeyDispatcher: EventHandlerRef?

    /// Auto-tile observers (re-flow on window/app activity). Kept so we can remove.
    private var autoTileObservers: [NSObjectProtocol] = []
    private var autoTileTask: DispatchWorkItem?

    private enum BindingID: Int {
        case left = 1, right = 2, top = 3, bottom = 4, untile = 5
        case moveNext = 6, movePrev = 7, focusNext = 8, focusPrev = 9
    }

    private enum TilingAction {
        case left, right, top, bottom, untile
    }

    private init() {}

    // MARK: - Lifecycle

    /// Starts the engine: registers the global ⌘⌥ bindings when enabled.
    func start(settings: RuntimeSettings.Omatiles = RuntimeSettings.Omatiles.load()) {
        self.settings = settings
        isRunning = true
        if settings.bindings { installBindings() }
        installAutoTiling(if: settings.autoTile)
    }

    /// Applies new declarative settings to a running engine (no rebuild needed).
    func apply(settings: RuntimeSettings.Omatiles) {
        let bindingsChanged = settings.bindings != self.settings.bindings
        let autoTileChanged = settings.autoTile != self.settings.autoTile
        let layoutChanged = settings.defaultLayout != self.settings.defaultLayout
        let gapChanged = settings.gap != self.settings.gap
        self.settings = settings
        if bindingsChanged {
            removeBindings()
            if settings.bindings { installBindings() }
        }
        if autoTileChanged {
            removeAutoTiling()
            installAutoTiling(if: settings.autoTile)
        }
        // A layout or gap change should re-flow the open windows immediately.
        if layoutChanged || gapChanged {
            scheduleAutoTiling()
        }
    }

    func stop() {
        isRunning = false
        removeBindings()
        removeAutoTiling()
    }

    // MARK: - Real tiling actions (AX window moves; public, used by GUI + tests)

    /// Tiles the focused window into the left half. `@discardableResult` so the
    /// GUI can ignore success but tests can verify the window actually moved.
    @discardableResult
    func tileLeft() -> Bool { tile(.left) }
    @discardableResult
    func tileRight() -> Bool { tile(.right) }
    @discardableResult
    func tileTop() -> Bool { tile(.top) }
    @discardableResult
    func tileBottom() -> Bool { tile(.bottom) }
    @discardableResult
    func untile() -> Bool { restore() }

    /// Tiles the focused window into one of the layout engine's grid slots
    /// (2x2, row-major: 0 = top-left, 1 = top-right, 2 = bottom-left, 3 = bottom-right).
    @discardableResult
    func tileQuadrant(_ index: Int) -> Bool {
        guard let screen = NSScreen.main,
              let frame = LayoutEngine.quadrant(index, in: screen.visibleFrame, gap: settings.gap) else { return false }
        // Ghost the full 2x2 grid so the user sees every slot they can navigate.
        GhostTilingOverlay.shared.showGhosts(for: LayoutEngine.gridSlots(in: screen.visibleFrame, gap: settings.gap))
        return apply(frame)
    }

    /// Tiles the focused window full-visible-frame (monocle slot). Returns false
    /// if the move didn't happen.
    @discardableResult
    func tileMonocle() -> Bool {
        guard let screen = NSScreen.main else { return false }
        let frame = screen.visibleFrame.insetBy(dx: settings.gap, dy: settings.gap)
        GhostTilingOverlay.shared.showGhosts(for: [frame])
        return apply(frame)
    }

    /// Moves the focused window to an explicit CGRect via AX. Returns false if
    /// the move didn't happen (no trust, no focused window, AX failure).
    @discardableResult
    func moveFocusedWindow(to frame: CGRect) -> Bool {
        apply(frame)
    }

    /// Arranges every visible window on the main screen into the given layout's
    /// slots (BSP / Grid / Monocle / Stack / Spiral). The slots act as persistent
    /// "parking spots": each window is moved and resized to fill its slot, and the
    /// ghost overlay is left showing the spots so the user can park further windows
    /// there via the ⌘⌥ hotkeys. Returns how many windows were actually moved.
    @discardableResult
    func applyLayout(_ layout: OwinLayout, gap: CGFloat? = nil) -> Int {
        let g = gap ?? settings.gap
        let (windows, frames) = layoutPlan(layout: layout, gap: g)
        guard !windows.isEmpty, !frames.isEmpty else { return 0 }
        // Ghost the slots first so the parking spots are visible immediately.
        if let screen = NSScreen.main {
            GhostTilingOverlay.shared.showGhosts(for: LayoutEngine.gridSlots(in: screen.visibleFrame, gap: g))
        }
        return apply(frames: frames, to: windows, layoutName: layout.rawValue)
    }

    /// Applies the persisted default layout to all visible windows. Used by
    /// auto-tiling (window/focus changes) and by the Window Manager "Apply".
    @discardableResult
    func applyDefaultLayout(gap: CGFloat? = nil) -> Int {
        let layout = OwinLayout(rawValue: settings.defaultLayout) ?? .bsp
        return applyLayout(layout, gap: gap)
    }

    // MARK: - Whole-workspace helper

    /// Orderly visible windows (topmost-last AX order is unreliable, so we use the
    /// enumerated order across regular apps) plus their target frames for a layout.
    /// Returns empty frames for `.float`.
    private func layoutPlan(layout: OwinLayout, gap: CGFloat) -> ([AXUIElement], [CGRect]) {
        guard AXIsProcessTrusted(), let screen = NSScreen.main, layout != .float else { return ([], []) }
        let windows = RealWindowMover.shared.allVisibleWindows()
        let frames = LayoutEngine.frames(count: windows.count, in: screen.visibleFrame, layout: layout, gap: gap)
        return (windows, frames)
    }

    private func apply(frames: [CGRect], to windows: [AXUIElement], layoutName: String) -> Int {
        guard windows.count == frames.count else { return 0 }
        var moved = 0
        for (window, frame) in zip(windows, frames) {
            if (try? RealWindowMover.shared.apply(frame, to: window)) != nil {
                moved += 1
            }
        }
        print("OmatilesEngine: applied layout \(layoutName) to \(moved)/\(windows.count) windows")
        return moved
    }

    // MARK: - Movement / focus (⌘⌥, Aerospace-style)
    // Binds set:
    //   ⌘⌥←/→/↑/↓  tile focused window to that screen region
    //   ⌘⌥]        move focused window to the next slot
    //   ⌘⌥[        move focused window to the previous slot
    //   ⌘⌥PageDn/PageUp  focus the next / previous window
    @discardableResult
    func moveFocusedWindow(forward: Bool) -> Bool {
        guard AXIsProcessTrusted(), NSScreen.main != nil, isRunning else { return false }
        let layout = OwinLayout(rawValue: settings.defaultLayout) ?? .bsp
        let (windows, frames) = layoutPlan(layout: layout, gap: settings.gap)
        guard windows.count > 1,
              let focused = RealWindowMover.shared.focusedWindowElement(),
              let idx = windows.firstIndex(where: { CFEqual($0, focused) }) else { return false }
        let step = (forward ? 1 : -1)
        let next = (idx + step + windows.count) % windows.count
        // Swap the two windows' frames so the focused window lands in the neighbor slot.
        let fFrame = frames[idx]
        let nFrame = frames[next]
        let ok1 = (try? RealWindowMover.shared.apply(nFrame, to: windows[idx])) != nil
        let ok2 = (try? RealWindowMover.shared.apply(fFrame, to: windows[next])) != nil
        GhostTilingOverlay.shared.showGhosts(for: frames)
        return ok1 && ok2
    }

    /// Puts keyboard focus on the next/previous visible window by raising and
    /// activating the owning application (and its window). Returns true on success.
    @discardableResult
    func focusNextWindow(forward: Bool) -> Bool {
        guard AXIsProcessTrusted(), NSScreen.main != nil, isRunning else { return false }
        let layout = OwinLayout(rawValue: settings.defaultLayout) ?? .bsp
        let (windows, _) = layoutPlan(layout: layout, gap: settings.gap)
        guard windows.count > 1 else { return false }
        // Find the focused window's index in the ordered set. CFEqual compares the
        // represented element (not wrapper pointer identity), which stays stable.
        guard let focused = RealWindowMover.shared.focusedWindowElement(),
              let focusedIndex = windows.firstIndex(where: { CFEqual($0, focused) }) else { return false }
        let step = (forward ? 1 : -1)
        let next = (focusedIndex + step + windows.count) % windows.count
        let target = windows[next]
        var pid: pid_t = 0
        AXUIElementGetPid(target, &pid)
        guard pid > 0, let app = NSRunningApplication(processIdentifier: pid) else { return false }
        app.activate()
        // Bring the target window to the front within its app.
        AXUIElementPerformAction(target, kAXRaiseAction as CFString)
        return true
    }

    // MARK: - Auto-tiling (Aerospace-style re-flow on window/app activity)

    /// Installs NSWorkspace observers so that when a window-bearing app launches,
    /// hides, unhides, or terminates, every visible window is re-arranged into the
    /// default layout — so a newly opened window flows into a spot. Deliberately
    /// does NOT re-flow on mere focus changes (`didActivate`), which would fight a
    /// user who is manually placing windows. Debounced so a burst of events
    /// re-flows once. Note: in-app window creation (e.g. File > New Tab) is not
    /// observed here; that requires per-process AX observers and is a later
    /// refinement — app launch/close covers the common "open an app" case.
    private func installAutoTiling(if enabled: Bool) {
        guard enabled, autoTileObservers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        let names: [NSNotification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didHideApplicationNotification,
            NSWorkspace.didUnhideApplicationNotification
        ]
        autoTileObservers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.scheduleAutoTiling() }
            }
        }
        // Re-flow once on startup so a freshly-launched manager tiles existing windows.
        scheduleAutoTiling()
    }

    private func removeAutoTiling() {
        autoTileTask?.cancel()
        autoTileTask = nil
        for obs in autoTileObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
        autoTileObservers.removeAll()
    }

    /// Debounces re-flow into the default layout so a burst of window events
    /// triggers a single arrangement.
    private func scheduleAutoTiling() {
        guard settings.autoTile, AXIsProcessTrusted() else { return }
        autoTileTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            guard let self, self.isRunning else { return }
            _ = self.applyDefaultLayout()
        }
        autoTileTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: task)
    }

    /// Computes a target CGRect plus moves the focused window there via AX.
    private func tile(_ action: TilingAction) -> Bool {
        guard let screen = NSScreen.main else { return false }
        let frame = LayoutEngine.half(halfEdge(action), in: screen.visibleFrame, gap: settings.gap)
        GhostTilingOverlay.shared.showGhosts(for: [frame])
        return apply(frame)
    }

    private func apply(_ frame: CGRect) -> Bool {
        do {
            try RealWindowMover.shared.moveFocusedWindow(to: frame)
            return true
        } catch {
            print("OmatilesEngine: tile to \(frame) failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Untile: raise the focused window to approximately its original position.
    /// We don't track original frames in this lightweight engine, so untile puts
    /// the window into the default (full visible frame minus gap) slot.
    private func restore() -> Bool {
        guard let screen = NSScreen.main else { return false }
        return apply(screen.visibleFrame.insetBy(dx: settings.gap, dy: settings.gap))
    }

    private func halfEdge(_ action: TilingAction) -> LayoutEngine.Half {
        switch action {
        case .left: return .left
        case .right: return .right
        case .top: return .top
        case .bottom: return .bottom
        case .untile: return .left // unused
        }
    }

    // MARK: - Accessibility

    /// True if the Accessibility permission is granted; otherwise prompts (once).
    /// The prompt is only shown when this app is frontmost, so launchd autostart
    /// never bothers the user on login.
    @discardableResult
    static func ensureAccessibility() -> Bool {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            let isFrontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier
                == ProcessInfo.processInfo.processIdentifier
            if isFrontmost {
                nsPromptForAccessibility()
            }
        }
        return AXIsProcessTrusted()
    }

    private static func nsPromptForAccessibility() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }

    // MARK: - Keyboard bindings (Carbon hotkeys — consumed, not leaked)

    private func installBindings() {
        guard hotKeyRefs.isEmpty else { return }

        // Install the C dispatcher exactly once per engine lifetime.
        Self.installHotKeyDispatcher(owner: self)

        _ = registerBinding(.left, keyCode: kVK_LeftArrow)
        _ = registerBinding(.right, keyCode: kVK_RightArrow)
        _ = registerBinding(.top, keyCode: kVK_UpArrow)
        _ = registerBinding(.bottom, keyCode: kVK_DownArrow)
        _ = registerBinding(.untile, keyCode: kVK_ANSI_Z)
        _ = registerBinding(.moveNext, keyCode: kVK_ANSI_RightBracket)
        _ = registerBinding(.movePrev, keyCode: kVK_ANSI_LeftBracket)
        _ = registerBinding(.focusNext, keyCode: kVK_PageDown)
        _ = registerBinding(.focusPrev, keyCode: kVK_PageUp)
    }

    private func registerBinding(_ binding: BindingID, keyCode: Int) -> Bool {
        let hotKeyID = EventHotKeyID(signature: OSType(0x4F4D4E58), id: UInt32(binding.rawValue)) // "OMNX"
        let modifiers = UInt32(cmdKey) | UInt32(optionKey) // ⌘⌥
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(keyCode), modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return false }
        hotKeyRefs[binding.rawValue] = ref
        return true
    }

    private func removeBindings() {
        for ref in hotKeyRefs.values {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        if let dispatcher = Self.hotKeyDispatcher {
            RemoveEventHandler(dispatcher)
            Self.hotKeyDispatcher = nil
        }
    }

    private func handleBinding(_ raw: Int) {
        guard isRunning else { return }
        guard let binding = BindingID(rawValue: raw) else { return }
        switch binding {
        case .left:   _ = tileLeft()
        case .right:  _ = tileRight()
        case .top:    _ = tileTop()
        case .bottom: _ = tileBottom()
        case .untile: _ = untile()
        case .moveNext: _ = moveFocusedWindow(forward: true)
        case .movePrev: _ = moveFocusedWindow(forward: false)
        case .focusNext: _ = focusNextWindow(forward: true)
        case .focusPrev: _ = focusNextWindow(forward: false)
        }
    }

    /// Routes an Omatiles ⌘⌥ binding id to its tiling action. This is the exact
    /// code path the Carbon hotkey dispatcher runs when a user presses ⌘⌥← etc.
    /// Exposed so the behavioral tests can drive the binding→action→AX-move
    /// chain deterministically without depending on Carbon event dispatch (which
    /// doesn't fire in a headless test process with no app run loop).
    @discardableResult
    func performBinding(_ raw: Int) -> Bool {
        guard isRunning else { return false }
        guard let binding = BindingID(rawValue: raw) else { return false }
        switch binding {
        case .left:   return tileLeft()
        case .right:  return tileRight()
        case .top:    return tileTop()
        case .bottom: return tileBottom()
        case .untile: return untile()
        case .moveNext: return moveFocusedWindow(forward: true)
        case .movePrev: return moveFocusedWindow(forward: false)
        case .focusNext: return focusNextWindow(forward: true)
        case .focusPrev: return focusNextWindow(forward: false)
        }
    }

    private static func installHotKeyDispatcher(owner: OmatilesEngine) {
        guard hotKeyDispatcher == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPointer = Unmanaged.passUnretained(owner).toOpaque()

        let handler: EventHandlerUPP = { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }

            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard status == noErr else { return OSStatus(eventNotHandledErr) }

            let engine = Unmanaged<OmatilesEngine>.fromOpaque(userData).takeUnretainedValue()
            Task { @MainActor in engine.handleBinding(Int(hotKeyID.id)) }
            return noErr
        }

        _ = InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            selfPointer,
            &hotKeyDispatcher
        )
    }
}