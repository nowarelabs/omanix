// modules/apps/store/Sources/PackageListView.swift
// Omanix — package browsing and installation
import SwiftUI

struct PackageListView: View {
    @ObservedObject var store: StoreViewModel
    @Binding var searchText: String
    @Binding var selectedPackage: PackageItem?
    @Environment(\.omanixTheme) var theme
    @State private var hoveredPackageId: UUID?
    @State private var inspectorPackage: PackageItem?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                header
                searchBar
                sourceFilters
                rebuildBanner
                content
                StatusBarView(store: store, idleText: "\(store.packages.count) packages") {
                    if store.brewIndexReady {
                        Button(action: { Task { await store.refreshBrewIndex() } }) {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 9))
                                Text("Update index")
                            }
                            .font(.system(size: 10, weight: .medium))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(theme.tertiaryText)
                        .help("Re-download Homebrew package index")
                    }
                }
            }

            // Floating inspector panel
            if let pkg = inspectorPackage {
                InspectorPanel(package: pkg) {
                    withAnimation(.easeInOut(duration: 0.2)) { inspectorPackage = nil }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .padding(16)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Browse")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.text)
                Text("Search across nixpkgs, Homebrew, and custom sources")
                    .font(.system(size: 12))
                    .foregroundColor(theme.tertiaryText)
            }
            Spacer()
            if !store.packages.isEmpty {
                resultSummary
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .background(theme.background)
        .overlay(alignment: .bottom) {
            Divider().background(theme.divider)
        }
    }

    private var resultSummary: some View {
        HStack(spacing: 12) {
            ForEach(PackageItem.PackageSource.allCases, id: \.self) { source in
                let count = store.packages.filter { $0.source == source }.count
                if count > 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(source.badgeColor)
                            .frame(width: 5, height: 5)
                        Text("\(count)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(theme.secondaryText)
                    }
                }
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(store.isLoading ? theme.accent : theme.tertiaryText)

            if store.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.7)
            }

            TextField("Search packages...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .monospaced))
                .onChange(of: searchText) { _, newValue in
                    store.search(query: newValue)
                }

            if !searchText.isEmpty {
                Button(action: clearSearch) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(theme.tertiaryText)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(theme.tertiarySurface)
        .cornerRadius(UIConstants.cornerInput)
        .overlay(
            RoundedRectangle(cornerRadius: UIConstants.cornerInput)
                .stroke(searchText.isEmpty ? theme.border : theme.accent.opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .animation(.easeInOut(duration: 0.15), value: searchText.isEmpty)
    }

    // MARK: - Source Filters

    private var sourceFilters: some View {
        Group {
            if !store.packages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(activeSources, id: \.self) { source in
                            SourceFilterChip(
                                source: source,
                                count: store.packages.filter { $0.source == source }.count
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 8)
            }
        }
    }

    private var activeSources: [PackageItem.PackageSource] {
        PackageItem.PackageSource.allCases.filter { source in
            store.packages.contains { $0.source == source }
        }
    }

    // MARK: - Rebuild Banner

    @ViewBuilder
    private var rebuildBanner: some View {
        if store.isLoading && store.needsRebuild {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Rebuilding system...")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.text)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(theme.accent.opacity(0.06))
                .overlay(alignment: .bottom) {
                    Divider().background(theme.divider)
                }

                if !store.rebuildLog.isEmpty {
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(store.rebuildLog.enumerated()), id: \.offset) { _, line in
                                    Text(line)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(line.contains("error") || line.contains("ERROR")
                                            ? theme.error : theme.tertiaryText)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .id(store.rebuildLog.firstIndex(of: line))
                                }
                            }
                            .padding(12)
                        }
                        .frame(maxHeight: 160)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(UIConstants.cornerRow)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .onChange(of: store.rebuildLog.count) { _, _ in
                            withAnimation { proxy.scrollTo(store.rebuildLog.count - 1, anchor: .bottom) }
                        }
                    }
                }
            }
        } else if store.needsRebuild {
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.warning)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rebuild required")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.text)
                    Text("Packages added — rebuild to apply changes")
                        .font(.system(size: 11))
                        .foregroundColor(theme.secondaryText)
                }
                Spacer()
                Button(action: { Task { await store.rebuild() } }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10))
                        Text("Rebuild")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(theme.accent)
                    .cornerRadius(UIConstants.cornerRow)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(theme.warning.opacity(0.06))
            .overlay(alignment: .bottom) {
                Divider().background(theme.divider)
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.25), value: store.needsRebuild)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if searchText.isEmpty && store.packages.isEmpty {
            emptyState
        } else if store.isLoading && store.packages.isEmpty {
            loadingState
        } else if store.packages.isEmpty && !searchText.isEmpty {
            noResults
        } else {
            packageList
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(theme.tertiaryText.opacity(0.4))
            VStack(spacing: 4) {
                Text("Search for packages")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(theme.text)
                Text("Find packages from nixpkgs, Homebrew, and custom sources")
                    .font(.system(size: 12))
                    .foregroundColor(theme.tertiaryText)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text("Searching...")
                .font(.system(size: 12))
                .foregroundColor(theme.tertiaryText)
            Spacer()
        }
    }

    private var noResults: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(theme.tertiaryText.opacity(0.4))
            VStack(spacing: 4) {
                Text("No packages match")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(theme.text)
                Text("'\(searchText)' — try a different search term")
                    .font(.system(size: 12))
                    .foregroundColor(theme.tertiaryText)
            }
            Spacer()
        }
    }

    private var packageList: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(groupedBySource, id: \.source) { group in
                    SourceCard(
                        source: group.source,
                        packages: group.packages,
                        hoveredPackageId: $hoveredPackageId,
                        inspectorPackage: $inspectorPackage,
                        store: store
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(theme.background)
    }

    private var groupedBySource: [(source: PackageItem.PackageSource, packages: [PackageItem])] {
        var groups: [PackageItem.PackageSource: [PackageItem]] = [:]
        for pkg in store.packages {
            groups[pkg.source, default: []].append(pkg)
        }
        return groups
            .map { (source: $0.key, packages: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.source.rawValue < $1.source.rawValue }
    }

    // MARK: - Helpers

    private func clearSearch() {
        searchText = ""
        store.packages = []
    }
}

// MARK: - Source Card

struct SourceCard: View {
    let source: PackageItem.PackageSource
    let packages: [PackageItem]
    @Binding var hoveredPackageId: UUID?
    @Binding var inspectorPackage: PackageItem?
    @ObservedObject var store: StoreViewModel
    @Environment(\.omanixTheme) var theme

    var body: some View {
        VStack(spacing: 0) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: source.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(source.badgeColor)
                    .frame(width: UIConstants.iconChipMedium, height: UIConstants.iconChipMedium)
                    .background(source.badgeColor.opacity(0.12))
                    .cornerRadius(UIConstants.cornerRow)

                Text(source.sectionName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.text)

                Spacer()

                Text("\(packages.count)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(source.badgeColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(source.badgeColor.opacity(0.1))
                    .cornerRadius(UIConstants.cornerPill)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().background(theme.divider).padding(.leading, 48)

            // Rows
            VStack(spacing: 1) {
                ForEach(packages) { package in
                    PackageRow(
                        package: package,
                        store: store,
                        isHovered: hoveredPackageId == package.id,
                        onSelect: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                inspectorPackage = package
                            }
                        }
                    )
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            hoveredPackageId = hovering ? package.id : nil
                        }
                    }
                }
            }
        }
        .background(theme.surface)
        .cornerRadius(UIConstants.cornerCard)
        .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: UIConstants.cornerCard)
                .stroke(theme.border, lineWidth: 1)
        )
    }
}

// MARK: - Package Row

struct PackageRow: View {
    let package: PackageItem
    @ObservedObject var store: StoreViewModel
    let isHovered: Bool
    let onSelect: () -> Void
    @Environment(\.omanixTheme) var theme
    @State private var isInstalling = false

    var body: some View {
        HStack(spacing: 10) {
            PackageIcon(name: package.name, source: package.source, size: UIConstants.iconChipLarge)
                .frame(width: UIConstants.iconChipLarge, height: UIConstants.iconChipLarge)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(package.name)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(theme.text)
                    if package.isInstalled {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(theme.success)
                    }
                }
                if !package.description.isEmpty {
                    Text(package.description)
                        .font(.system(size: 11))
                        .foregroundColor(theme.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Source badge
            Text(package.source.displayName)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(package.source.badgeColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(package.source.badgeColor.opacity(0.08))
                .cornerRadius(UIConstants.cornerRow)

            // Info button (hover-only) — opens inspector
            Button(action: onSelect) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundColor(theme.tertiaryText)
            }
            .buttonStyle(.plain)
            .help("Show package info")
            .opacity(isHovered ? 1 : 0)
            .animation(.easeInOut(duration: 0.1), value: isHovered)

            // Action button
            actionButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 44)
        .background(
            RoundedRectangle(cornerRadius: UIConstants.cornerRow)
                .fill(isHovered ? Color.white.opacity(0.04) : .clear)
        )
    }

    @ViewBuilder
    private var actionButton: some View {
        if isInstalling {
            ProgressView()
                .controlSize(.small)
        } else if package.isInstalled {
            Button(action: { confirmUninstall() }) {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                    Text("Installed")
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(theme.success)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(theme.success.opacity(0.1))
                .cornerRadius(UIConstants.cornerRow)
            }
            .buttonStyle(.plain)
            .help("Click to uninstall")
        } else {
            Button(action: { install() }) {
                HStack(spacing: 3) {
                    Image(systemName: "plus")
                        .font(.system(size: 8, weight: .bold))
                    Text("Install")
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(theme.accent)
                .cornerRadius(UIConstants.cornerRow)
            }
            .buttonStyle(.plain)
        }
    }

    private func install() {
        isInstalling = true
        Task {
            await store.installPackage(package)
            isInstalling = false
        }
    }

    private func confirmUninstall() {
        isInstalling = true
        Task {
            await store.uninstallPackage(package)
            isInstalling = false
        }
    }
}

// MARK: - Inspector Panel

struct InspectorPanel: View {
    let package: PackageItem
    let onClose: () -> Void
    @Environment(\.omanixTheme) var theme

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text(package.name)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(theme.text)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(theme.tertiaryText)
                        .frame(width: 20, height: 20)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(UIConstants.cornerPill)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().background(theme.divider)

            // Info rows
            VStack(spacing: 0) {
                infoRow("Name", package.name)
                Divider().background(theme.divider).padding(.leading, 16)
                infoRow("Source", package.source.displayName)
                Divider().background(theme.divider).padding(.leading, 16)
                infoRow("Installed", package.isInstalled ? "Yes" : "No")
                Divider().background(theme.divider).padding(.leading, 16)
                infoRow("Icon", AppIcons.icon(for: package.name))
                if !package.description.isEmpty {
                    Divider().background(theme.divider).padding(.leading, 16)
                    infoRow("Description", package.description)
                }
            }
            .padding(.vertical, 8)
        }
        .frame(width: 280)
        .background(theme.floating)
        .cornerRadius(UIConstants.cornerCard)
        .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: UIConstants.cornerCard)
                .stroke(theme.border, lineWidth: 1)
        )
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(theme.tertiaryText)
            Spacer()
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(theme.text)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}

// MARK: - Source Filter Chip

struct SourceFilterChip: View {
    let source: PackageItem.PackageSource
    let count: Int
    @Environment(\.omanixTheme) var theme

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: source.icon)
                .font(.system(size: 9))
            Text(source.displayName)
                .font(.system(size: 10, weight: .medium))
            Text("\(count)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(source.badgeColor)
        }
        .foregroundColor(source.badgeColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(source.badgeColor.opacity(0.06))
        .cornerRadius(UIConstants.cornerRow)
    }
}

#Preview {
    PackageListView(
        store: StoreViewModel(),
        searchText: .constant("ripgrep"),
        selectedPackage: .constant(nil)
    )
}
