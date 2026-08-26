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
            // Logo header
            HStack(spacing: 8) {
                Image(systemName: "cube.transparent.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.accent, theme.accent.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("Omanix")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundColor(theme.text)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()
                .background(theme.border)

            // Tab list
            List(SidebarTab.allCases, id: \.self, selection: $selectedTab) { tab in
                sidebarRow(tab)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            Spacer(minLength: 0)

            // Bottom info
            Divider()
                .background(theme.border)
            HStack {
                Circle()
                    .fill(theme.success)
                    .frame(width: 6, height: 6)
                Text("System OK")
                    .font(.caption2)
                    .foregroundColor(theme.tertiaryText)
                Spacer()
                Text("v\(versionString)")
                    .font(.caption2)
                    .foregroundColor(theme.tertiaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 240)
        .background(theme.surface)
    }

    private func sidebarRow(_ tab: SidebarTab) -> some View {
        Label {
            HStack {
                Text(tab.rawValue)
                    .font(.system(.body, weight: selectedTab == tab ? .semibold : .regular))
                Spacer()
                if let badge = badgeText(for: tab) {
                    Text(badge)
                        .font(.system(.caption2, weight: .medium))
                        .foregroundColor(theme.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.accent.opacity(0.12))
                        .cornerRadius(6)
                }
            }
        } icon: {
            Image(systemName: iconName(for: tab))
                .font(.system(size: 14, weight: selectedTab == tab ? .semibold : .regular))
        }
        .foregroundColor(selectedTab == tab ? theme.accent : theme.secondaryText)
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
