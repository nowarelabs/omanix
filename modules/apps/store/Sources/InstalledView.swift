// modules/apps/store/Sources/InstalledView.swift
// Omanix — view installed packages grouped by source
import SwiftUI

struct InstalledView: View {
    @ObservedObject var store: StoreViewModel
    @State private var selectedPackage: PackageItem?
    @Environment(\.omanixTheme) var theme
    @State private var expandedSources: Set<String> = []

    var body: some View {
        Group {
            if store.declaredPackages.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .onAppear {
            if expandedSources.isEmpty {
                expandedSources = Set(store.declaredPackages.map { $0.source.rawValue })
            }
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
            Button(action: onToggle) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(theme.tertiaryText)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))

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

            if isExpanded {
                Divider().background(theme.divider).padding(.leading, 48)
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
                .font(.system(size: 12))
                .foregroundColor(theme.success)
                .frame(width: 16, height: 16)

            PackageIcon(name: package.name, source: package.source, size: UIConstants.iconChipSmall)
                .frame(width: UIConstants.iconChipSmall, height: UIConstants.iconChipSmall)

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
        .frame(minHeight: 44)
        .background(
            RoundedRectangle(cornerRadius: UIConstants.cornerRow)
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
