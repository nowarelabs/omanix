// Modules/Omabar/OmabarManager.swift
// Owns the Omabar panel: a borderless, full-width NSPanel pinned to the top or bottom
// screen edge above every window — the native SwiftUI stand-in for the old SketchyBar.
// Clicking it must not steal focus from the frontmost app, so it is non-activating.

import AppKit
import SwiftUI

/// Borderless panel that can become key (so its SwiftUI buttons work) without
/// activating the Omanix app.
final class OmabarPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class OmabarManager {

    static let shared = OmabarManager()

    private(set) var isRunning = false
    private var panel: OmabarPanel?
    private let model = OmabarModel()
    private var screenObserver: NSObjectProtocol?

    private init() {}

    var isVisible: Bool { panel != nil && panel?.isVisible == true }

    // MARK: - Lifecycle

    /// Creates and shows the bar. No-op when already running.
    @discardableResult
    func start(settings: RuntimeSettings.Omabar = RuntimeSettings.Omabar.load()) -> Bool {
        guard !isRunning else { return true }
        model.start()
        let bar = buildPanel(settings: settings)
        guard bar != nil else {
            model.stop()
            return false
        }
        panel = bar
        isRunning = true
        installScreenObserver()
        return true
    }

    /// Re-renders a running bar from new declarative settings (no rebuild needed).
    func apply(settings: RuntimeSettings.Omabar) {
        guard isRunning, let panel else { return }
        positionPanel(panel, settings: settings)
        panel.contentView = makeContentView(settings: settings)
    }

    func stop() {
        model.stop()
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            self.screenObserver = nil
        }
        panel?.close()
        panel = nil
        isRunning = false
    }

    func refresh() {
        let settings = RuntimeSettings.Omabar.load()
        if isRunning { apply(settings: settings) } else { _ = start(settings: settings) }
    }

    // MARK: - Panel construction

    private func buildPanel(settings: RuntimeSettings.Omabar) -> OmabarPanel? {
        guard let screen = NSScreen.main else { model.stop(); return nil }

        let panel = OmabarPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.acceptsMouseMovedEvents = true
        positionPanel(panel, settings: settings, screen: screen)
        panel.contentView = makeContentView(settings: settings)
        panel.orderFrontRegardless()
        return panel
    }

    private func positionPanel(_ panel: OmabarPanel, settings: RuntimeSettings.Omabar, screen: NSScreen? = nil) {
        guard let screen = screen ?? NSScreen.main else { return }
        let h = CGFloat(settings.height)
        let y = settings.position == "bottom" ? screen.frame.minY : screen.frame.maxY - h
        panel.setFrame(NSRect(x: screen.frame.minX, y: y, width: screen.frame.width, height: h), display: true)
    }

    private func makeContentView(settings: RuntimeSettings.Omabar) -> NSHostingView<OmabarContentView> {
        NSHostingView(
            rootView: OmabarContentView(
                model: model,
                settings: settings,
                onAppleClick: {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Omanix.app"))
                }
            )
        )
    }

    private func installScreenObserver() {
        guard screenObserver == nil else { return }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.reposition() }
        }
    }

    private func reposition() {
        guard isRunning, let panel else { return }
        let settings = RuntimeSettings.Omabar.load()
        positionPanel(panel, settings: settings)
        panel.contentView = makeContentView(settings: settings)
    }
}