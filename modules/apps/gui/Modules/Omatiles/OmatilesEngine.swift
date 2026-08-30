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

    // MARK: - Native tiling actions (public, also used by the GUI "try it" button)

    func tileLeft() { pressSystemTiling(.left) }
    func tileRight() { pressSystemTiling(.right) }
    func tileTop() { pressSystemTiling(.top) }
    func tileBottom() { pressSystemTiling(.bottom) }
    func untile() { pressSystemTiling(.untile) }

    /// Synthesizes the macOS tiling shortcut (⌃⌥ + arrow/Z) that the OS handles
    /// natively. Requires Accessibility trust to post synthetic HID events.
    private func pressSystemTiling(_ action: TilingAction) {
        guard AXIsProcessTrusted() else { return }
        let key: CGKeyCode
        switch action {
        case .left:   key = CGKeyCode(kVK_LeftArrow)
        case .right:  key = CGKeyCode(kVK_RightArrow)
        case .top:    key = CGKeyCode(kVK_UpArrow)
        case .bottom: key = CGKeyCode(kVK_DownArrow)
        case .untile: key = CGKeyCode(kVK_ANSI_Z)
        }
        let flags: CGEventFlags = [.maskControl, .maskAlternate]
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: true) else { return }
        down.flags = flags
        down.post(tap: .cghidEventTap)
        let up = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: false)
        up?.flags = flags
        up?.post(tap: .cghidEventTap)
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
        case .left:   tileLeft()
        case .right:  tileRight()
        case .top:    tileTop()
        case .bottom: tileBottom()
        case .untile: untile()
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