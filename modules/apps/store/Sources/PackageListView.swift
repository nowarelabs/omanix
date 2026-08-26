// modules/apps/store/Sources/PackageListView.swift
// Omanix — package browsing and installation
import SwiftUI

struct PackageListView: View {
    @ObservedObject var store: StoreViewModel
    @Binding var searchText: String
    @Binding var selectedPackage: PackageItem?
    @Environment(\.omanixTheme) var theme
    @State private var hoveredPackageId: UUID?

    var body: some View {
        VStack(spacing: 0) {
            header
            searchBar
            sourceFilters
            rebuildBanner
            content
            statusBar
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Browse Packages")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(theme.text)
                Text("Search across nixpkgs, Homebrew, and custom sources")
                    .font(.caption)
                    .foregroundColor(theme.tertiaryText)
            }
            Spacer()
            if !store.packages.isEmpty {
                resultSummary
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var resultSummary: some View {
        HStack(spacing: 12) {
            ForEach(PackageItem.PackageSource.allCases, id: \.self) { source in
                let count = store.packages.filter { $0.source == source }.count
                if count > 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(source.badgeColor)
                            .frame(width: 6, height: 6)
                        Text("\(count)")
                            .font(.system(.caption2, weight: .medium))
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
                .font(.system(.body, design: .monospaced))
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
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.tertiarySurface)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(searchText.isEmpty ? theme.border : theme.accent.opacity(0.4), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
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
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 4)
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
        if store.needsRebuild {
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.warning)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rebuild required")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundColor(theme.text)
                    Text("Packages added — rebuild to apply changes")
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                }
                Spacer()
                Button(action: { Task { await store.rebuild() } }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11))
                        Text("Rebuild now")
                    }
                    .font(.system(.caption, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(theme.accent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(theme.warning.opacity(0.08))
            .overlay(alignment: .bottom) {
                Divider().background(theme.border)
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
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(theme.accent.opacity(0.08))
                    .frame(width: 100, height: 100)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(theme.accent.opacity(0.5))
            }
            VStack(spacing: 6) {
                Text("Search for packages")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundColor(theme.text)
                Text("Find packages from nixpkgs, Homebrew, and custom sources")
                    .font(.subheadline)
                    .foregroundColor(theme.tertiaryText)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text("Searching all sources...")
                .font(.subheadline)
                .foregroundColor(theme.tertiaryText)
            Spacer()
        }
    }

    private var noResults: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(theme.warning.opacity(0.08))
                    .frame(width: 100, height: 100)
                Image(systemName: "questionmark.folder")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(theme.warning.opacity(0.5))
            }
            VStack(spacing: 6) {
                Text("No packages found")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundColor(theme.text)
                Text("Try a different search term or check spelling")
                    .font(.subheadline)
                    .foregroundColor(theme.tertiaryText)
            }
            Spacer()
        }
    }

    private var packageList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(store.packages) { package in
                    PackageRow(
                        package: package,
                        store: store,
                        isHovered: hoveredPackageId == package.id
                    )
                    .onHover { hovering in
                        hoveredPackageId = hovering ? package.id : nil
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(theme.background)
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 8) {
            if store.isIndexingBrew {
                ProgressView()
                    .controlSize(.mini)
                Text("Indexing Homebrew...")
                    .font(.caption)
                    .foregroundColor(theme.tertiaryText)
            } else if let error = store.errorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(theme.error)
                Text(error)
                    .font(.caption)
                    .foregroundColor(theme.error)
                    .lineLimit(1)
            } else if let success = store.successMessage {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(theme.success)
                Text(success)
                    .font(.caption)
                    .foregroundColor(theme.success)
            } else {
                Circle()
                    .fill(theme.tertiaryText.opacity(0.4))
                    .frame(width: 4, height: 4)
                Text("\(store.packages.count) packages found")
                    .font(.caption)
                    .foregroundColor(theme.tertiaryText)
            }

            Spacer()

            if store.brewIndexReady {
                Button(action: { Task { await store.refreshBrewIndex() } }) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9))
                        Text("Update index")
                    }
                    .font(.system(.caption2, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(theme.tertiaryText)
                .help("Re-download Homebrew package index")
            }

            Button(action: { Task { await store.rebuild() } }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11))
                    Text("Rebuild")
                }
                .font(.system(.caption, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(theme.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(theme.surface)
        .overlay(alignment: .top) {
            Divider().background(theme.border)
        }
    }

    // MARK: - Helpers

    private func clearSearch() {
        searchText = ""
        store.packages = []
    }
}

// MARK: - Package Row

struct PackageRow: View {
    let package: PackageItem
    @ObservedObject var store: StoreViewModel
    let isHovered: Bool
    @Environment(\.omanixTheme) var theme
    @State private var isInstalling = false

    var body: some View {
        HStack(spacing: 12) {
            // Source icon
            Image(systemName: package.source.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(package.source.badgeColor)
                .frame(width: 28, height: 28)
                .background(package.source.badgeColor.opacity(0.1))
                .cornerRadius(6)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(package.name)
                        .font(.system(.body, design: .monospaced, weight: .medium))
                        .foregroundColor(theme.text)
                    if package.isInstalled {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(theme.success)
                    }
                }
                if !package.description.isEmpty {
                    Text(package.description)
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Action button
            actionButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? theme.tertiarySurface : .clear)
        )
        .animation(.easeInOut(duration: 0.1), value: isHovered)
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
                        .font(.system(size: 9, weight: .bold))
                    Text("Installed")
                }
                .font(.system(.caption, weight: .medium))
                .foregroundColor(theme.success)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(theme.success.opacity(0.1))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Click to uninstall")
        } else {
            Button(action: { install() }) {
                HStack(spacing: 3) {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                    Text("Install")
                }
                .font(.system(.caption, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    LinearGradient(
                        colors: [theme.accent, theme.accent.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(6)
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
        // Direct uninstall with confirmation handled by the row
        isInstalling = true
        Task {
            await store.uninstallPackage(package)
            isInstalling = false
        }
    }
}

// MARK: - Source Badge (reusable)

struct SourceBadge: View {
    let source: PackageItem.PackageSource

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: source.icon)
                .font(.system(size: 8))
            Text(source.rawValue)
        }
        .font(.system(.caption2, weight: .semibold))
        .foregroundColor(source.badgeColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(source.badgeColor.opacity(0.1))
        .cornerRadius(4)
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
                .font(.system(.caption2, weight: .medium))
            Text("\(count)")
                .font(.system(.caption2, weight: .bold))
                .foregroundColor(source.badgeColor)
        }
        .foregroundColor(source.badgeColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(source.badgeColor.opacity(0.08))
        .cornerRadius(6)
    }
}

#Preview {
    PackageListView(
        store: StoreViewModel(),
        searchText: .constant("ripgrep"),
        selectedPackage: .constant(nil)
    )
}
