// modules/apps/store/Sources/OmanixStoreApp.swift
// Omanix Store — main app entry point
import SwiftUI

@main
struct OmanixStoreApp: App {
    @StateObject private var store = StoreViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1000, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
