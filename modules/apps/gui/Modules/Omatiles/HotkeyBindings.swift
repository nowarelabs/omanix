// Modules/Omatiles/HotkeyBindings.swift
// Strategy — Carbon global-hotkey registration and dispatch for Omatiles.
//
// Extracted from OmatilesEngine (see WindowTiler's header for the rationale).
// This type owns the Carbon pieces: registering the ⌘⌥ event hotkeys, receiving
// the C dispatch callback, and routing a binding id out through a closure. It
// knows nothing about what an action does — the owner maps a binding id to the
// actual tiling/navigation action. Keeping the C interop in one place isolates
// the unsafe Carbon code from the rest of the engine.

import Foundation
import AppKit
import Carbon.HIToolbox

final class HotkeyBindings {

    /// Routes a pressed binding id (1 = ⌘⌥←, 2 = ⌘⌥→, 3 = ⌘⌥↑, 4 = ⌘⌥↓, 5 = ⌘⌥Z,
    /// 6/7 = move next/prev, 8/9 = focus next/prev) to its action.
    private let onBinding: (Int) -> Void

    /// One registered ref per binding id.
    private var refs: [Int: EventHotKeyRef] = [:]
    private static var dispatcher: EventHandlerRef?

    init(onBinding: @escaping (Int) -> Void) {
        self.onBinding = onBinding
    }

    var isInstalled: Bool { !refs.isEmpty }

    /// Installs the global ⌘⌥ hot keys. No-op when already installed.
    func install() {
        guard refs.isEmpty else { return }
        // Install the C dispatcher exactly once per engine lifetime.
        Self.installDispatcher(owner: self)

        _ = register(1, keyCode: kVK_LeftArrow)          // ⌘⌥← tile left
        _ = register(2, keyCode: kVK_RightArrow)         // ⌘⌥→ tile right
        _ = register(3, keyCode: kVK_UpArrow)            // ⌘⌥↑ tile top
        _ = register(4, keyCode: kVK_DownArrow)          // ⌘⌥↓ tile bottom
        _ = register(5, keyCode: kVK_ANSI_Z)             // ⌘⌥Z untile
        _ = register(6, keyCode: kVK_ANSI_RightBracket)  // ⌘⌥] move next
        _ = register(7, keyCode: kVK_ANSI_LeftBracket)   // ⌘⌥[ move prev
        _ = register(8, keyCode: kVK_PageDown)           // ⌘⌥PageDn focus next
        _ = register(9, keyCode: kVK_PageUp)             // ⌘⌥PageUp focus prev
    }

    /// Removes every registered hot key and the shared dispatcher.
    func remove() {
        for ref in refs.values {
            UnregisterEventHotKey(ref)
        }
        refs.removeAll()
        if let dispatcher = Self.dispatcher {
            RemoveEventHandler(dispatcher)
            Self.dispatcher = nil
        }
    }

    /// Registers one ⌘⌥ hot key, storing its ref by binding id.
    private func register(_ id: Int, keyCode: Int) -> Bool {
        let hotKeyID = EventHotKeyID(signature: OSType(0x4F4D4E58), id: UInt32(id)) // "OMNX"
        let modifiers = UInt32(cmdKey) | UInt32(optionKey) // ⌘⌥
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(keyCode), modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return false }
        refs[id] = ref
        return true
    }

    /// Invoked by the Carbon dispatcher (on the main run loop) with a binding id.
    private func handle(_ raw: Int) {
        onBinding(raw)
    }

    /// Installs the single C event handler that turns a pressed hot key into a
    /// binding-id callback. Retains `owner` unretained, exactly like the original.
    private static func installDispatcher(owner: HotkeyBindings) {
        guard dispatcher == nil else { return }

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

            let bindings = Unmanaged<HotkeyBindings>.fromOpaque(userData).takeUnretainedValue()
            Task { @MainActor in bindings.handle(Int(hotKeyID.id)) }
            return noErr
        }

        _ = InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            selfPointer,
            &dispatcher
        )
    }
}
