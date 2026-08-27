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
    @State private var refreshed = false

    var body: some View {
        VStack(spacing: 0) {
            contentHeading
            listHeader
            packageList
        }
        .background(theme.background)
        .overlay(alignment: .bottomTrailing) {
            if let pkg = inspectorPackage {
                InspectorPanel(package: pkg) {
                    withAnimation(.easeInOut(duration: 0.2)) { inspectorPackage = nil }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .padding(16)
            }
        }
    }

    // MARK: - Content Heading (breadcrumb + title + subheading + refresh)

    private var contentHeading: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("PACKAGE LIBRARY / HOME")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(theme.tertiaryText)
                    .tracking(0.5)
                Text("Installed")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(theme.text)
                Text(subheading)
                    .font(.system(size: 12))
                    .foregroundColor(theme.tertiaryText)
            }
            Spacer()
            Button(action: {
                refreshed = true
                store.loadDeclaredPackages()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { refreshed = false }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .rotationEffect(.degrees(refreshed ? 360 : 0))
                        .animation(refreshed ? .easeInOut(duration: 0.6) : .default, value: refreshed)
                    Text(refreshed ? "Updated" : "Refresh")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(refreshed ? theme.success : theme.text)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(theme.surface)
                .cornerRadius(UIConstants.cornerRow)
                .overlay(
                    RoundedRectangle(cornerRadius: UIConstants.cornerRow)
                        .stroke(theme.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var subheading: String {
        let count = store.declaredPackages.count
        let sources = Set(store.declaredPackages.map { $0.source }).count
        return "\(count) packages in \(sources) sources"
    }

    // MARK: - List Header

    private var listHeader: some View {
        HStack(spacing: 0) {
            Text("PACKAGE")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(theme.tertiaryText)
                .tracking(0.5)
            Spacer()
            Text("STATUS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(theme.tertiaryText)
                .tracking(0.5)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .background(theme.surface)
        .overlay(alignment: .bottom) {
            Divider().background(theme.border)
        }
    }

    // MARK: - Package List

    private var packageList: some View {
        ScrollView {
            if searchText.isEmpty && store.packages.isEmpty && !store.isLoading {
                emptyState
            } else if store.isLoading && store.packages.isEmpty {
                loadingState
            } else if store.packages.isEmpty && !searchText.isEmpty {
                noResults
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(store.packages) { package in
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

                        if package.id != store.packages.last?.id {
                            Divider().background(theme.border).padding(.leading, 56)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty / Loading / No Results

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 60)
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(theme.tertiaryText.opacity(0.4))
            VStack(spacing: 4) {
                Text("Search for packages")
                    .font(.system(size: 14, weight: .medium))
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
            Spacer().frame(height: 60)
            ProgressView()
                .controlSize(.large)
            Text("Searching...")
                .font(.system(size: 12))
                .foregroundColor(theme.tertiaryText)
            Spacer()
        }
    }

    private var noResults: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 60)
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(theme.tertiaryText.opacity(0.4))
            VStack(spacing: 4) {
                Text("No packages match")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.text)
                Text("'\(searchText)' — try a different search term")
                    .font(.system(size: 12))
                    .foregroundColor(theme.tertiaryText)
            }
            Spacer()
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
    let onSelect: () -> Void
    @Environment(\.omanixTheme) var theme
    @State private var isInstalling = false
    @State private var isRemoved = false

    var body: some View {
        if isRemoved { EmptyView() } else {
            HStack(spacing: 10) {
                // Status check
                if package.isInstalled {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(theme.text)
                        .frame(width: 16, height: 16)
                        .background(theme.accent)
                        .cornerRadius(UIConstants.cornerPill)
                } else {
                    Circle()
                        .stroke(theme.border, lineWidth: 1.5)
                        .frame(width: 16, height: 16)
                }

                // Checkbox
                Button(action: {}) {
                    Image(systemName: "square")
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(theme.secondaryText)
                }
                .buttonStyle(.plain)

                // Package name + description
                VStack(alignment: .leading, spacing: 1) {
                    Text(package.name)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(theme.text)
                    if !package.description.isEmpty {
                        Text(package.description)
                            .font(.system(size: 11))
                            .foregroundColor(theme.secondaryText)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Row actions (hover)
                HStack(spacing: 8) {
                    if isHovered && package.isInstalled {
                        Button(action: { isRemoved = true }) {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 16))
                                .foregroundColor(theme.error)
                        }
                        .buttonStyle(.plain)
                        .help("Remove \(package.name)")
                    }

                    if package.isInstalled {
                        Text("Installed")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(theme.success)
                    } else {
                        Button(action: { install() }) {
                            if isInstalling {
                                ProgressView()
                                    .controlSize(.mini)
                            } else {
                                Text("Install")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(theme.accent)
                                    .cornerRadius(UIConstants.cornerRow)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 7)
            .frame(minHeight: 40)
            .background(
                isHovered ? Color.white.opacity(0.03) : Color.clear
            )
        }
    }

    private func install() {
        isInstalling = true
        Task {
            await store.installPackage(package)
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

            Divider().background(theme.border)

            VStack(spacing: 0) {
                infoRow("Name", package.name)
                Divider().background(theme.border).padding(.leading, 16)
                infoRow("Source", package.source.displayName)
                Divider().background(theme.border).padding(.leading, 16)
                infoRow("Installed", package.isInstalled ? "Yes" : "No")
                Divider().background(theme.border).padding(.leading, 16)
                infoRow("Icon", AppIcons.icon(for: package.name))
                if !package.description.isEmpty {
                    Divider().background(theme.border).padding(.leading, 16)
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
        searchText: .constant(""),
        selectedPackage: .constant(nil)
    )
}
