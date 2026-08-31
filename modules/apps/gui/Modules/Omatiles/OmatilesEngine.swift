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

    private enum BindingID: Int {
        case left = 1, right = 2, top = 3, bottom = 4, untile = 5
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
    }

    /// Applies new declarative settings to a running engine (no rebuild needed).
    func apply(settings: RuntimeSettings.Omatiles) {
        let bindingsChanged = settings.bindings != self.settings.bindings
        self.settings = settings
        if bindingsChanged {
            removeBindings()
            if settings.bindings { installBindings() }
        }
    }

    func stop() {
        isRunning = false
        removeBindings()
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
        guard AXIsProcessTrusted(), let screen = NSScreen.main else { return 0 }
        // Ghost the slots first so the parking spots are visible immediately.
        let slots = LayoutEngine.gridSlots(in: screen.visibleFrame, gap: g)
        GhostTilingOverlay.shared.showGhosts(for: slots)

        let windows = RealWindowMover.shared.allVisibleWindows()
        guard !windows.isEmpty else { return 0 }

        let frames = LayoutEngine.frames(count: windows.count, in: screen.visibleFrame, layout: layout, gap: g)
        guard !frames.isEmpty else { return 0 }

        var moved = 0
        for (window, frame) in zip(windows, frames) {
            if (try? RealWindowMover.shared.apply(frame, to: window)) != nil {
                moved += 1
            }
        }
        print("OmatilesEngine: applied layout=\(layout.rawValue) to \(moved)/\(windows.count) windows")
        return moved
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