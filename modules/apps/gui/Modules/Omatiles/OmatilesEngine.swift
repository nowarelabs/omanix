// Modules/Omatiles/OmatilesEngine.swift
// Omatiles — a thin bridge onto macOS Sequoia's BUILT-IN window tiling.
//
// This type is now a FACADE: it owns lifecycle + the ⌘⌥ key bindings + the
// auto-tiling schedule, and delegates the actual arrangement work to focused
// collaborators, so each type has a single responsibility:
//   - WindowTiler      — single-window tile + whole-workspace layout actions
//   - WindowNavigator  — move/focus cycling between tiled windows
//   - WindowArranger   — the shared frames→AX pipeline (also used by Owin)
//   - HotkeyBindings   — Carbon global-hotkey registration & dispatch
// The public API (start/apply/stop, tileLeft…, applyLayout, moveFocusedWindow,
// performBinding, ensureAccessibility) is unchanged, so the GUI and the
// behavioral tests drive it exactly as before.
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

    private let tiler = WindowTiler.shared
    private let navigator = WindowNavigator.shared
    private var hotkeys: HotkeyBindings!

    /// Auto-tile observers (re-flow on window/app activity). Kept so we can remove.
    private var autoTileObservers: [NSObjectProtocol] = []
    private var autoTileTask: DispatchWorkItem?

    private enum BindingID: Int {
        case left = 1, right = 2, top = 3, bottom = 4, untile = 5
        case moveNext = 6, movePrev = 7, focusNext = 8, focusPrev = 9
    }

    private init() {
        hotkeys = HotkeyBindings { [weak self] raw in self?.handleBinding(raw) }
    }

    // MARK: - Lifecycle

    /// Starts the engine: registers the global ⌘⌥ bindings when enabled.
    func start(settings: RuntimeSettings.Omatiles = RuntimeSettings.Omatiles.load()) {
        self.settings = settings
        isRunning = true
        if settings.bindings { hotkeys.install() }
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
            hotkeys.remove()
            if settings.bindings { hotkeys.install() }
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
        hotkeys.remove()
        removeAutoTiling()
    }

    // MARK: - Real tiling actions (AX window moves; public, used by GUI + tests)

    /// Tiles the focused window into the left half. `@discardableResult` so the
    /// GUI can ignore success but tests can verify the window actually moved.
    @discardableResult
    func tileLeft() -> Bool { tiler.tileQuarter(.left, gap: settings.gap) }
    @discardableResult
    func tileRight() -> Bool { tiler.tileQuarter(.right, gap: settings.gap) }
    @discardableResult
    func tileTop() -> Bool { tiler.tileQuarter(.top, gap: settings.gap) }
    @discardableResult
    func tileBottom() -> Bool { tiler.tileQuarter(.bottom, gap: settings.gap) }
    @discardableResult
    func untile() -> Bool { tiler.untile(gap: settings.gap) }

    /// Tiles the focused window into one of the layout engine's grid slots
    /// (2x2, row-major: 0 = top-left, 1 = top-right, 2 = bottom-left, 3 = bottom-right).
    @discardableResult
    func tileQuadrant(_ index: Int) -> Bool {
        tiler.tileQuadrant(index, gap: settings.gap)
    }

    /// Tiles the focused window full-visible-frame (monocle slot). Returns false
    /// if the move didn't happen.
    @discardableResult
    func tileMonocle() -> Bool {
        tiler.tileMonocle(gap: settings.gap)
    }

    /// Moves the focused window to an explicit CGRect via AX. Returns false if
    /// the move didn't happen (no trust, no focused window, AX failure).
    @discardableResult
    func moveFocusedWindow(to frame: CGRect) -> Bool {
        tiler.moveFocused(to: frame)
    }

    /// Arranges every visible window on the main screen into the given layout's
    /// slots (BSP / Grid / Monocle / Stack / Spiral). The slots act as persistent
    /// "parking spots": each window is moved and resized to fill its slot, and the
    /// ghost overlay is left showing the spots so the user can park further windows
    /// there via the ⌘⌥ hotkeys. Returns how many windows were actually moved.
    @discardableResult
    func applyLayout(_ layout: OwinLayout, gap: CGFloat? = nil) -> Int {
        tiler.applyLayout(layout, gap: gap ?? settings.gap)
    }

    /// Applies the persisted default layout to all visible windows. Used by
    /// auto-tiling (window/focus changes) and by the Window Manager "Apply".
    @discardableResult
    func applyDefaultLayout(gap: CGFloat? = nil) -> Int {
        tiler.applyDefaultLayout(layoutName: settings.defaultLayout, gap: gap ?? settings.gap)
    }

    // MARK: - Movement / focus (⌘⌥, Aerospace-style)
    // Binds set:
    //   ⌘⌥←/→/↑/↓  tile focused window to that screen region
    //   ⌘⌥]        move focused window to the next slot
    //   ⌘⌥[        move focused window to the previous slot
    //   ⌘⌥PageDn/PageUp  focus the next / previous window
    @discardableResult
    func moveFocusedWindow(forward: Bool) -> Bool {
        guard isRunning else { return false }
        return navigator.moveFocusedWindow(forward: forward, defaultLayout: settings.defaultLayout, gap: settings.gap)
    }

    /// Puts keyboard focus on the next/previous visible window by raising and
    /// activating the owning application (and its window). Returns true on success.
    @discardableResult
    func focusNextWindow(forward: Bool) -> Bool {
        guard isRunning else { return false }
        return navigator.focusNextWindow(forward: forward, defaultLayout: settings.defaultLayout, gap: settings.gap)
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

    // MARK: - Binding routing (⌘⌥ hotkeys → actions)

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

    /// Dispatch entry point called by HotkeyBindings for a pressed ⌘⌥ hot key.
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
}
