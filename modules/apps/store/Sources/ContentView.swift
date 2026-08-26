// modules/apps/store/Sources/ContentView.swift
// Omanix — main navigation
import SwiftUI

struct ContentView: View {
    @State private var searchText = ""
    @State private var selectedTab: SidebarTab = .packages
    @State private var selectedPackage: PackageItem?
    @ObservedObject var store: StoreViewModel
    @Environment(\.omanixTheme) var theme

    enum SidebarTab: String, CaseIterable {
        case packages = "Browse"
        case installed = "Installed"
        case widgets = "Widgets"
        case themes = "Themes"
        case settings = "Settings"
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .searchable(text: $searchText, prompt: "Search packages...")
        .background(theme.background)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Logo
            HStack(spacing: 8) {
                Image(systemName: "cube.transparent")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(theme.accent)
                Text("Omanix")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.text)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()
                .background(theme.border)
                .opacity(0.5)

            // Navigation
            List(SidebarTab.allCases, id: \.self, selection: $selectedTab) { tab in
                sidebarRow(tab)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            Spacer(minLength: 0)

            // Status
            Divider()
                .background(theme.border)
                .opacity(0.5)

            HStack(spacing: 6) {
                Circle()
                    .fill(theme.success)
                    .frame(width: 5, height: 5)
                Text("System OK")
                    .font(.system(size: 11))
                    .foregroundColor(theme.tertiaryText)
                Spacer()
                Text("v\(versionString)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(theme.tertiaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 220)
        .background(theme.surface)
    }

    private func sidebarRow(_ tab: SidebarTab) -> some View {
        HStack(spacing: 8) {
            Image(systemName: iconName(for: tab))
                .font(.system(size: 14, weight: selectedTab == tab ? .semibold : .regular))
                .foregroundColor(selectedTab == tab ? theme.accent : theme.tertiaryText)
                .frame(width: 20)

            Text(tab.rawValue)
                .font(.system(size: 13, weight: selectedTab == tab ? .medium : .regular))
                .foregroundColor(selectedTab == tab ? theme.text : theme.secondaryText)

            Spacer()

            if let badge = badgeText(for: tab) {
                Text(badge)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(theme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.accent.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
        .listRowSeparator(.hidden)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
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

    // MARK: - Helpers

    private var versionString: String {
        (try? String(contentsOfFile: FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".omanix/version").path, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "0.1.0"
    }

    func iconName(for tab: SidebarTab) -> String {
        switch tab {
        case .packages: return "square.grid.2x2"
        case .installed: return "checkmark.circle"
        case .widgets: return "rectangle.stack"
        case .themes: return "paintbrush"
        case .settings: return "gearshape"
        }
    }

    func badgeText(for tab: SidebarTab) -> String? {
        switch tab {
        case .installed:
            let count = store.installedPackages.count
            return count > 0 ? "\(count)" : nil
        default:
            return nil
        }
    }
}
