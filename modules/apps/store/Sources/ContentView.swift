// modules/apps/store/Sources/ContentView.swift
// Omanix Store — SwiftUI app for browsing and installing packages
// Phase 06 stub — will be fleshed out with real nix search / brew search integration
import SwiftUI

struct ContentView: View {
    @State private var searchText = ""
    @State private var selectedTab: SidebarTab = .packages

    enum SidebarTab: String, CaseIterable {
        case packages = "Packages"
        case widgets = "Widgets"
        case themes = "Themes"
        case settings = "Settings"
    }

    var body: some View {
        NavigationSplitView {
            List(SidebarTab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: iconName(for: tab))
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            switch selectedTab {
            case .packages:
                PackagesView(searchText: $searchText)
            case .widgets:
                WidgetsView()
            case .themes:
                ThemesView()
            case .settings:
                SettingsView()
            }
        }
        .searchable(text: $searchText, prompt: "Search packages...")
    }

    func iconName(for tab: SidebarTab) -> String {
        switch tab {
        case .packages: return "square.grid.3x3"
        case .widgets: return "widget.rectangle"
        case .themes: return "paintbrush"
        case .settings: return "gear"
        }
    }
}

struct PackagesView: View {
    @Binding var searchText: String
    var body: some View {
        Text("Packages — search nixpkgs + brew")
            .foregroundStyle(.secondary)
    }
}

struct WidgetsView: View {
    var body: some View {
        Text("Widgets — omanix.widgets.* gallery")
            .foregroundStyle(.secondary)
    }
}

struct ThemesView: View {
    var body: some View {
        Text("Themes — omanix.theme picker with live preview")
            .foregroundStyle(.secondary)
    }
}

struct SettingsView: View {
    var body: some View {
        Text("Settings — system.defaults sliders")
            .foregroundStyle(.secondary)
    }
}

#Preview {
    ContentView()
}
