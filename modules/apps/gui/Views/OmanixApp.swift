// Views/OmanixApp.swift
// Omanix — main app entry point. Creates the ViewModel once and injects it.
// Also acts as the Omatiles module host: launchd starts this same binary with
// "--omatiles" (see modules/darwin/omatiles.nix), and normal launches start
// whichever modules are enabled in configuration. Spacebar is fully external
// (its own launchd agent via modules/darwin/spacebar.nix), so it is not hosted here.

import SwiftUI
import AppKit

@main
struct OmanixApp: App {
    @StateObject private var viewModel = OmanixViewModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// True when launched by a launchd agent with a "--omatiles" flag.
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
            if CommandLine.arguments.contains("--omatiles") {
                let tiles = RuntimeSettings.Omatiles.load()
                if tiles.enable { OmatilesEngine.shared.start(settings: tiles) }
                // Owin shares the omatiles launchd slot when enabled (Phase 4).
                if RuntimeSettings.Owin.load().enable { _ = WorkspaceManager.shared.start() }
            }
        } else {
            // Normal GUI launch: start the enabled desktop modules so the screen
            // matches configuration without needing a rebuild.
            let tiles = RuntimeSettings.Omatiles.load()
            if tiles.enable { OmatilesEngine.shared.start(settings: tiles) }

            if RuntimeSettings.Owin.load().enable { _ = WorkspaceManager.shared.start() }

            // Bring the live macOS WindowManager tiling prefs in line with the current
            // declarative config even if no rebuild has run yet (so ⌃⌥+arrow works now).
            // Goes through the Nix-owned `omanix state apply omatiles` path.
            try? Omanix().applyOmatilesLive()
        }
    }
}
