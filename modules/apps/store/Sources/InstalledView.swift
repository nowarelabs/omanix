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
            VStack(alignment: .leading, spacing: 4) {
                Text("Installed")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.text)
                HStack(spacing: 4) {
                    Text("\(store.declaredPackages.count) packages")
                        .font(.system(size: 12))
                        .foregroundColor(theme.tertiaryText)
                    Text("in")
                        .font(.system(size: 12))
                        .foregroundColor(theme.tertiaryText)
                    Text("\(sourceCount) sources")
                        .font(.system(size: 12))
                        .foregroundColor(theme.tertiaryText)
                }
            }
            Spacer()
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
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .background(theme.background)
        .overlay(alignment: .bottom) {
            Divider().background(theme.divider)
        }
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(groupedPackages, id: \.source) { group in
                    InstalledSourceCard(
                        source: group.source,
                        packages: group.packages,
                        isExpanded: expandedSources.contains(group.source.rawValue),
                        onToggle: { toggleSource(group.source) },
                        store: store,
                        selectedPackage: $selectedPackage
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(theme.background)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(theme.tertiaryText.opacity(0.4))
            VStack(spacing: 4) {
                Text("No packages declared")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(theme.text)
                Text("Add packages with omanix add or edit configuration.nix")
                    .font(.system(size: 12))
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
                    .font(.system(size: 10))
                    .foregroundColor(theme.error)
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(theme.error)
                    .lineLimit(1)
            } else if let success = store.successMessage {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(theme.success)
                Text(success)
                    .font(.system(size: 11))
                    .foregroundColor(theme.success)
            } else {
                Circle()
                    .fill(theme.success)
                    .frame(width: 4, height: 4)
                Text("All packages from configuration.nix")
                    .font(.system(size: 11))
                    .foregroundColor(theme.tertiaryText)
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
                .padding(.vertical, 5)
                .background(theme.accent)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(theme.surface)
        .overlay(alignment: .top) {
            Divider().background(theme.divider)
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
        withAnimation(.easeInOut(duration: 0.15)) {
            if expandedSources.contains(source.rawValue) {
                expandedSources.remove(source.rawValue)
            } else {
                expandedSources.insert(source.rawValue)
            }
        }
    }
}

// MARK: - Installed Source Card

struct InstalledSourceCard: View {
    let source: PackageItem.PackageSource
    let packages: [PackageItem]
    let isExpanded: Bool
    let onToggle: () -> Void
    @ObservedObject var store: StoreViewModel
    @Binding var selectedPackage: PackageItem?
    @Environment(\.omanixTheme) var theme

    var body: some View {
        VStack(spacing: 0) {
            // Disclosure header
            Button(action: onToggle) {
                HStack(spacing: 8) {
                    // Rotating chevron
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(theme.tertiaryText)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))

                    Image(systemName: source.icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(source.badgeColor)
                        .frame(width: 24, height: 24)
                        .background(source.badgeColor.opacity(0.12))
                        .cornerRadius(6)

                    Text(source.sectionName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.text)

                    Spacer()

                    // Pill badge
                    Text("\(packages.count)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(source.badgeColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(source.badgeColor.opacity(0.1))
                        .cornerRadius(999)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            // Expanded rows
            if isExpanded {
                VStack(spacing: 1) {
                    ForEach(packages) { package in
                        InstalledPackageRow(package: package, store: store)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if isExpanded {
                Divider().background(theme.divider).padding(.leading, 48)
            }
        }
        .background(theme.surface)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.border, lineWidth: 1)
        )
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
            // Checkmark
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(theme.success)

            // Consistent icon
            PackageIcon(name: package.name, source: package.source, size: 22)

            // Package info
            VStack(alignment: .leading, spacing: 1) {
                Text(package.name)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(theme.text)
                if !package.description.isEmpty {
                    Text(package.description)
                        .font(.system(size: 10))
                        .foregroundColor(theme.secondaryText)
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
                        .font(.system(size: 12))
                        .foregroundColor(theme.error.opacity(isHovered ? 1.0 : 0.4))
                }
                .buttonStyle(.plain)
                .help("Remove from configuration.nix")
                .opacity(isHovered ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.1), value: isHovered)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .padding(.leading, 20)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.white.opacity(0.04) : .clear)
        )
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
