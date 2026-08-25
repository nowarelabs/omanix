// modules/apps/store/Sources/ContentView.swift
// Omanix Store — main navigation
import SwiftUI

struct ContentView: View {
    @State private var searchText = ""
    @State private var selectedTab: SidebarTab = .packages
    @State private var selectedPackage: PackageItem?
    @StateObject private var store = StoreViewModel()

    enum SidebarTab: String, CaseIterable {
        case packages = "Packages"
        case installed = "Installed"
        case widgets = "Widgets"
        case themes = "Themes"
        case settings = "Settings"
    }

    var body: some View {
        NavigationSplitView {
            List(SidebarTab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: iconName(for: tab))
                    .badge(badgeCount(for: tab))
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            switch selectedTab {
            case .packages:
                PackageListView(store: store, searchText: $searchText, selectedPackage: $selectedPackage)
            case .installed:
                InstalledView(store: store)
            case .widgets:
                WidgetGalleryView(store: store)
            case .themes:
                ThemePickerView(store: store)
            case .settings:
                SettingsView(store: store)
            }
        }
        .searchable(text: $searchText, prompt: "Search packages...")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: { store.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh packages")
            }
        }
    }

    func iconName(for tab: SidebarTab) -> String {
        switch tab {
        case .packages: return "square.grid.3x3"
        case .installed: return "checkmark.square"
        case .widgets: return "rectangle.stack"
        case .themes: return "paintbrush"
        case .settings: return "gear"
        }
    }

    func badgeCount(for tab: SidebarTab) -> Int? {
        switch tab {
        case .installed:
            let count = store.installedPackages.count
            return count > 0 ? count : nil
        default:
            return nil
        }
    }
}
