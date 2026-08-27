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
                toolbar
                Divider().background(theme.border)
                detailContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("")
        .background(theme.background)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 0) {
            Spacer()
            toolbarButton("square.grid.2x2", "View", isActive: selectedTab == .packages)
            toolbarButton("sliders.horizontal", "Group", isActive: false)
            toolbarButton("square.and.arrow.up", "Share", isActive: false)
            toolbarButton("ellipsis", "Action", isActive: false)
            toolbarButton("magnifyingglass", "Search", isActive: false)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(theme.surface)
    }

    private func toolbarButton(_ icon: String, _ label: String, isActive: Bool) -> some View {
        Button(action: {}) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(isActive ? theme.text : theme.secondaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isActive ? Color.white.opacity(0.06) : Color.clear)
            .cornerRadius(UIConstants.cornerRow)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Brand
            HStack(spacing: 8) {
                Image(systemName: "cube.transparent")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(theme.accent)
                Text("Omanix")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.text)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)

            // Nav heading
            Text("Library")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(theme.tertiaryText)
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)

            // Nav items
            VStack(spacing: 1) {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    sidebarRow(tab)
                }
            }
            .padding(.horizontal, 8)

            Spacer(minLength: 0)

            Divider().background(theme.border)

            // Footer
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "externaldrive.connected.to.line.below")
                        .font(.system(size: 13))
                        .foregroundColor(theme.secondaryText)
                    Text("Homebrew")
                        .font(.system(size: 12))
                        .foregroundColor(theme.secondaryText)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(theme.tertiaryText)
                }
                HStack(spacing: 6) {
                    Image(systemName: "bolt")
                        .font(.system(size: 13))
                        .foregroundColor(theme.tertiaryText)
                    Text("\(activeSourceCount) sources")
                        .font(.system(size: 12))
                        .foregroundColor(theme.tertiaryText)
                    Spacer()
                }
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
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? theme.text : theme.secondaryText)
                    .frame(width: 18, alignment: .center)

                Text(tab.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? theme.text : theme.secondaryText)

                Spacer()

                if let badge = badgeText(for: tab) {
                    Text(badge)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(theme.secondaryText)
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

    private var activeSourceCount: Int {
        Set(store.packages.map { $0.source }).count
    }

    func iconName(for tab: SidebarTab) -> String {
        switch tab {
        case .packages: return "square.grid.2x2"
        case .installed: return "checkmark"
        case .widgets: return "archivebox"
        case .themes: return "tag"
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
