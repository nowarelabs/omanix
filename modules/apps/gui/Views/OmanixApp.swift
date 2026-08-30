// Views/OmanixApp.swift
// Omanix — main app entry point. Creates the ViewModel once and injects it.
// Also acts as the Omabar / Omatiles module host: launchd starts this same binary
// with "--omabar" or "--omatiles" (see modules/darwin/omabar.nix, omatiles.nix),
// and normal launches start whichever modules are enabled in configuration.

import SwiftUI
import AppKit

@main
struct OmanixApp: App {
    @StateObject private var viewModel = OmanixViewModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// True when launched by a launchd agent with a "--omabar" / "--omatiles" flag.
    static let moduleMode = CommandLine.arguments.contains { $0.hasPrefix("--") }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 1100, minHeight: 740)
                .preferredColorScheme(.light)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1280, height: 840)
        .defaultLaunchBehavior(Self.moduleMode ? .suppressed : .automatic)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        if OmanixApp.moduleMode {
            // Launchd module run: no Dock icon, no window. Start only the requested module.
            NSApp.setActivationPolicy(.accessory)
            let args = CommandLine.arguments
            if args.contains("--omabar") {
                let bar = RuntimeSettings.Omabar.load()
                if bar.enable { _ = OmabarManager.shared.start(settings: bar) }
            }
            if args.contains("--omatiles") {
                let tiles = RuntimeSettings.Omatiles.load()
                if tiles.enable { OmatilesEngine.shared.start(settings: tiles) }
                // Owin shares the omatiles launchd slot when enabled (Phase 4).
                if RuntimeSettings.Owin.load().enable { _ = WorkspaceManager.shared.start() }
            }
        } else {
            // Normal GUI launch: start the enabled desktop modules so the screen
            // matches configuration without needing a rebuild.
            let bar = RuntimeSettings.Omabar.load()
            if bar.enable { _ = OmabarManager.shared.start(settings: bar) }

            let tiles = RuntimeSettings.Omatiles.load()
            if tiles.enable { OmatilesEngine.shared.start(settings: tiles) }

            if RuntimeSettings.Owin.load().enable { _ = WorkspaceManager.shared.start() }

            // Bring the live macOS WindowManager tiling prefs in line with the current
            // declarative config even if no rebuild has run yet (so ⌃⌥+arrow works now).
            // Goes through the Nix-owned `omanix state apply omatiles` path.
            try? OmanixStore().applyOmatilesLive()
        }
    }
}
