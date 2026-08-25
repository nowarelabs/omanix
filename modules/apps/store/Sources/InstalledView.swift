// modules/apps/store/Sources/InstalledView.swift
// Omanix — view installed packages grouped by source
import SwiftUI

struct InstalledView: View {
    @ObservedObject var store: StoreViewModel
    @State private var selectedPackage: PackageItem?
    @Environment(\.omanixTheme) var theme
    @State private var expandedSources: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            header
            if store.declaredPackages.isEmpty {
                emptyState
            } else {
                content
            }
            statusBar
        }
        .onAppear {
            if expandedSources.isEmpty {
                expandedSources = Set(store.declaredPackages.map { $0.source.rawValue })
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Installed Packages")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(theme.text)
                HStack(spacing: 4) {
                    Text("\(store.declaredPackages.count) packages")
                        .font(.caption)
                        .foregroundColor(theme.tertiaryText)
                    Text("in")
                        .font(.caption)
                        .foregroundColor(theme.tertiaryText)
                    Text("\(sourceCount) sources")
                        .font(.caption)
                        .foregroundColor(theme.tertiaryText)
                }
            }
            Spacer()
            Button(action: { store.loadDeclaredPackages() }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                    Text("Refresh")
                }
                .font(.system(.caption, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(theme.accent)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(groupedPackages, id: \.source) { group in
                    SourceSection(
                        source: group.source,
                        packages: group.packages,
                        isExpanded: expandedSources.contains(group.source.rawValue),
                        onToggle: { toggleSource(group.source) },
                        store: store,
                        selectedPackage: $selectedPackage
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(theme.background)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(theme.accent.opacity(0.08))
                    .frame(width: 100, height: 100)
                Image(systemName: "tray")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(theme.accent.opacity(0.5))
            }
            VStack(spacing: 6) {
                Text("No packages declared")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundColor(theme.text)
                Text("Add packages with omanix add or edit configuration.nix")
                    .font(.subheadline)
                    .foregroundColor(theme.tertiaryText)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 8) {
            if let error = store.errorMessage {
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
                    .fill(theme.success)
                    .frame(width: 4, height: 4)
                Text("All packages from configuration.nix")
                    .font(.caption)
                    .foregroundColor(theme.tertiaryText)
            }

            Spacer()

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

    private var groupedPackages: [(source: PackageItem.PackageSource, packages: [PackageItem])] {
        var groups: [PackageItem.PackageSource: [PackageItem]] = [:]
        for pkg in store.declaredPackages {
            groups[pkg.source, default: []].append(pkg)
        }
        return groups
            .map { (source: $0.key, packages: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.source.rawValue < $1.source.rawValue }
    }

    private var sourceCount: Int {
        Set(store.declaredPackages.map { $0.source }).count
    }

    private func toggleSource(_ source: PackageItem.PackageSource) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedSources.contains(source.rawValue) {
                expandedSources.remove(source.rawValue)
            } else {
                expandedSources.insert(source.rawValue)
            }
        }
    }
}

// MARK: - Source Section

struct SourceSection: View {
    let source: PackageItem.PackageSource
    let packages: [PackageItem]
    let isExpanded: Bool
    let onToggle: () -> Void
    @ObservedObject var store: StoreViewModel
    @Binding var selectedPackage: PackageItem?
    @Environment(\.omanixTheme) var theme

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: onToggle) {
                HStack(spacing: 10) {
                    Image(systemName: source.icon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(source.badgeColor)
                        .frame(width: 26, height: 26)
                        .background(source.badgeColor.opacity(0.1))
                        .cornerRadius(6)

                    Text(source.sectionName)
                        .font(.system(.body, weight: .semibold))
                        .foregroundColor(theme.text)

                    Spacer()

                    Text("\(packages.count)")
                        .font(.system(.caption, weight: .bold))
                        .foregroundColor(source.badgeColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(source.badgeColor.opacity(0.1))
                        .cornerRadius(6)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(theme.tertiaryText)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 1) {
                    ForEach(packages) { package in
                        InstalledPackageRow(package: package, store: store)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Divider()
                .background(theme.border)
                .padding(.leading, 48)
        }
    }
}

// MARK: - Installed Package Row

struct InstalledPackageRow: View {
    let package: PackageItem
    @ObservedObject var store: StoreViewModel
    @Environment(\.omanixTheme) var theme
    @State private var isHovered = false
    @State private var isConfirming = false
    @State private var isRemoving = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13))
                .foregroundColor(theme.success)

            VStack(alignment: .leading, spacing: 1) {
                Text(package.name)
                    .font(.system(.body, design: .monospaced, weight: .medium))
                    .foregroundColor(theme.text)
                if !package.description.isEmpty {
                    Text(package.description)
                        .font(.caption)
                        .foregroundColor(theme.tertiaryText)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isRemoving {
                ProgressView()
                    .controlSize(.mini)
            } else {
                Button(action: { isConfirming = true }) {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 13))
                        .foregroundColor(theme.error.opacity(isHovered ? 1.0 : 0.5))
                }
                .buttonStyle(.plain)
                .help("Remove from configuration.nix")
                .opacity(isHovered ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.1), value: isHovered)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .padding(.leading, 36)
        .background(isHovered ? theme.tertiarySurface.opacity(0.5) : .clear)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
        .alert("Remove \(package.name)?", isPresented: $isConfirming) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                isRemoving = true
                Task {
                    await store.uninstallPackage(package)
                    isRemoving = false
                }
            }
        } message: {
            Text("This will remove \(package.name) from configuration.nix.\nRun \"omanix rebuild\" to apply.")
        }
    }
}

#Preview {
    InstalledView(store: StoreViewModel())
}
