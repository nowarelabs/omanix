// modules/apps/store/Sources/InstalledView.swift
// Omanix — view installed packages grouped by source
import SwiftUI

struct InstalledView: View {
    @ObservedObject var store: StoreViewModel
    @State private var selectedPackage: PackageItem?
    @Environment(\.omanixTheme) var theme
    @State private var expandedSources: Set<String> = []
    @State private var refreshed = false

    var body: some View {
        Group {
            if store.declaredPackages.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    contentHeading
                    listHeader
                    packageList
                }
                .background(theme.background)
            }
        }
        .onAppear {
            if expandedSources.isEmpty {
                expandedSources = Set(store.declaredPackages.map { $0.source.rawValue })
            }
        }
    }

    // MARK: - Content Heading

    private var contentHeading: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("INSTALLED PACKAGES")
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
            LazyVStack(spacing: 0) {
                ForEach(groupedPackages, id: \.source) { group in
                    // Source section header
                    HStack(spacing: 8) {
                        Image(systemName: group.source.icon)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(group.source.badgeColor)
                        Text(group.source.sectionName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(theme.text)
                        Text("\(group.packages.count)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(group.source.badgeColor)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(theme.surface.opacity(0.5))

                    ForEach(group.packages) { package in
                        InstalledPackageRow(package: package, store: store)
                        if package.id != group.packages.last?.id {
                            Divider().background(theme.border).padding(.leading, 56)
                        }
                    }

                    Divider().background(theme.border)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 60)
            Image(systemName: "tray")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(theme.tertiaryText.opacity(0.4))
            VStack(spacing: 4) {
                Text("No packages declared")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.text)
                Text("Add packages with omanix add or edit configuration.nix")
                    .font(.system(size: 12))
                    .foregroundColor(theme.tertiaryText)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
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
            // Status check
            Image(systemName: "checkmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(theme.text)
                .frame(width: 16, height: 16)
                .background(theme.accent)
                .cornerRadius(UIConstants.cornerPill)

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

            // Row actions
            HStack(spacing: 8) {
                if isHovered {
                    Button(action: { isConfirming = true }) {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 16))
                            .foregroundColor(theme.error)
                    }
                    .buttonStyle(.plain)
                    .help("Remove \(package.name)")
                }

                if isRemoving {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Text("Installed")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.success)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 7)
        .frame(minHeight: 40)
        .background(
            isHovered ? Color.white.opacity(0.03) : Color.clear
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
