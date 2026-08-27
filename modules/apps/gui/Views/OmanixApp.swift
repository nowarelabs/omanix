// Views/OmanixApp.swift
// Omanix — main app entry point. Creates the ViewModel once and injects it.

import SwiftUI

@main
struct OmanixApp: App {
    @StateObject private var viewModel = OmanixViewModel()

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
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
