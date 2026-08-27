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
            VStack(spacing: 0) {
                topBar
                Divider().background(theme.divider)
                detailContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider().background(theme.divider)
                StatusBarView(store: store, idleText: topBarIdleText) {
                    EmptyView()
                }
            }
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 6) {
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(theme.accent)
                    Text("Omanix")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.text)
                }
            }
        }
        .background(theme.background)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedTab.rawValue)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.text)
                Text(topBarSubtitle)
                    .font(.system(size: 12))
                    .foregroundColor(theme.tertiaryText)
            }
            Spacer()
            topBarActions
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .background(theme.background)
    }

    private var topBarSubtitle: String {
        switch selectedTab {
        case .packages:
            return "Search across nixpkgs, Homebrew, and custom sources"
        case .installed:
            let count = store.declaredPackages.count
            let sources = Set(store.declaredPackages.map { $0.source }).count
            return "\(count) packages in \(sources) sources"
        case .widgets:
            let enabled = store.widgets.filter(\.isEnabled).count
            return "\(enabled) of \(store.widgets.count) enabled"
        case .themes:
            return "Current: \(store.currentTheme)"
        case .settings:
            return "Configure your Omanix system"
        }
    }

    @ViewBuilder
    private var topBarActions: some View {
        switch selectedTab {
        case .packages:
            if store.brewIndexReady {
                Button(action: { Task { await store.refreshBrewIndex() } }) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                        Text("Update index")
                    }
                    .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(theme.accent)
            }
        case .installed:
            Button(action: { store.loadDeclaredPackages() }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                    Text("Refresh")
                }
                .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(theme.accent)
        default:
            EmptyView()
        }
    }

    private var topBarIdleText: String {
        switch selectedTab {
        case .packages:
            return "\(store.packages.count) packages"
        case .installed:
            return "All packages from configuration.nix"
        case .widgets:
            return "Toggle widgets, then rebuild"
        case .themes:
            return "Select a theme, then rebuild to apply"
        case .settings:
            return ""
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
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

            Divider().background(theme.divider)

            VStack(spacing: 2) {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    sidebarRow(tab)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)

            Spacer(minLength: 0)

            Divider().background(theme.divider)

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
        let isSelected = selectedTab == tab
        return Button(action: { selectedTab = tab }) {
            HStack(spacing: 8) {
                Image(systemName: iconName(for: tab))
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? theme.accent : theme.tertiaryText)
                    .frame(width: UIConstants.iconChipSmall, height: UIConstants.iconChipSmall)
                    .background(isSelected ? theme.accent.opacity(0.12) : Color.clear)
                    .cornerRadius(UIConstants.cornerRow)

                Text(tab.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? theme.text : theme.secondaryText)

                Spacer()

                if let badge = badgeText(for: tab) {
                    Text(badge)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(theme.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.accent.opacity(0.1))
                        .cornerRadius(UIConstants.cornerRow)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: UIConstants.cornerRow)
                    .fill(isSelected ? Color.white.opacity(0.06) : .clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailContent: some View {
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
