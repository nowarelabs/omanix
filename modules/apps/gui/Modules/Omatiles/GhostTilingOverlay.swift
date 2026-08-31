// Modules/Omatiles/GhostTilingOverlay.swift
// On-screen translucent "ghost" drop boxes that show exactly where a tiled
// window will land before/while the user tiles it.
//
// Before Omatiles moves the focused window, the engine calls `showGhosts(for:)`
// with the target slot frame(s). A borderless, mouse-transparent overlay window
// drawn above the desktop paints translucent rounded rectangles at those slots
// so the user sees precisely where the window will go. The overlay auto-hides
// after a short duration so it never blocks interaction.

import AppKit
import CoreGraphics

final class GhostTilingOverlay {

    static let shared = GhostTilingOverlay()

    private var windows: [NSWindow] = []
    private var hideWorkItem: DispatchWorkItem?

    private init() {}

    /// Shows translucent ghost boxes for the given screen-space frames, then
    /// hides them after `duration` seconds. Frames are in Cocoa (bottom-left
    /// origin) coordinates. Any previously shown ghosts are replaced.
    func showGhosts(for frames: [CGRect], duration: TimeInterval = 0.7) {
        hide()

        guard !frames.isEmpty, AXIsProcessTrusted() else { return }

        // Group frames by the screen they fall on (main screen for now), so each
        // overlay window is positioned on the right display.
        for screen in NSScreen.screens {
            let onScreen = frames.filter { screen.frame.intersects($0) }
            guard !onScreen.isEmpty else { continue }
            let overlay = makeOverlayWindow(on: screen, slots: onScreen)
            overlay.orderFrontRegardless()
            windows.append(overlay)
        }

        let item = DispatchWorkItem { [weak self] in self?.hide() }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: item)
    }

    /// Immediately removes any visible ghost overlay.
    func hide() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        for w in windows { w.orderOut(nil) }
        windows.removeAll()
    }

    private func makeOverlayWindow(on screen: NSScreen, slots: [CGRect]) -> NSWindow {
        let frame = screen.frame
        let overlayView = GhostView(frame: NSRect(origin: .zero, size: frame.size), slots: slots, baseOrigin: frame.origin)

        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .screenSaver
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        window.contentView = overlayView
        return window
    }

    /// Draws the translucent ghost rectangles.
    private final class GhostView: NSView {
        let slots: [CGRect]
        let baseOrigin: CGPoint

        init(frame: NSRect, slots: [CGRect], baseOrigin: CGPoint) {
            self.slots = slots
            self.baseOrigin = baseOrigin
            super.init(frame: frame)
            wantsLayer = true
        }

        required init?(coder: NSCoder) { nil }

        override func draw(_ dirtyRect: NSRect) {
            let fill = NSColor.systemBlue.withAlphaComponent(0.22)
            let stroke = NSColor.systemBlue.withAlphaComponent(0.9)
            for slot in slots {
                // Convert from global Cocoa (bottom-left) coords to the view's
                // (also bottom-left) local coords.
                let local = NSRect(x: slot.minX - baseOrigin.x,
                                   y: slot.minY - baseOrigin.y,
                                   width: slot.width,
                                   height: slot.height)
                let path = NSBezierPath(roundedRect: local.insetBy(dx: 2, dy: 2), xRadius: 8, yRadius: 8)
                fill.setFill()
                path.fill()
                stroke.setStroke()
                path.lineWidth = 2
                path.stroke()
            }
        }
    }
}
