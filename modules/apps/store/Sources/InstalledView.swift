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
            HStack {
                VStack(alignment: .leading) {
                    Text("Installed Packages")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.text)
                    Text("\(store.declaredPackages.count) packages across \(sourceCount) sources")
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                }
                Spacer()
                Button(action: { store.loadDeclaredPackages() }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(theme.accent)
            }
            .padding()

            if store.declaredPackages.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.square")
                        .font(.system(size: 48))
                        .foregroundColor(theme.secondaryText)
                    Text("No packages declared")
                        .font(.title2)
                        .foregroundColor(theme.secondaryText)
                    Text("Add packages with 'omanix add' or edit configuration.nix")
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.background)
            } else {
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
                }
                .background(theme.background)
            }

            HStack {
                if let error = store.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                } else if let success = store.successMessage {
                    Label(success, systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
                Spacer()
                Button("Rebuild System") {
                    Task { await store.rebuild() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(theme.accent)
            }
            .padding()
            .background(theme.surface)
        }
        .onAppear {
            // Expand all sources by default
            expandedSources = Set(store.declaredPackages.map { $0.source.rawValue })
        }
    }

    private var groupedPackages: [(source: PackageItem.PackageSource, packages: [PackageItem])] {
        var groups: [PackageItem.PackageSource: [PackageItem]] = [:]
        for pkg in store.declaredPackages {
            groups[pkg.source, default: []].append(pkg)
        }
        return groups.map { (source: $0.key, packages: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.source.rawValue < $1.source.rawValue }
    }

    private var sourceCount: Int {
        Set(store.declaredPackages.map { $0.source }).count
    }

    private func toggleSource(_ source: PackageItem.PackageSource) {
        if expandedSources.contains(source.rawValue) {
            expandedSources.remove(source.rawValue)
        } else {
            expandedSources.insert(source.rawValue)
        }
    }
}

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
            // Source header
            Button(action: onToggle) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                        .frame(width: 12)

                    SourceBadge(source: source)

                    Text(sourceName)
                        .font(.headline)
                        .foregroundColor(theme.text)

                    Spacer()

                    Text("\(packages.count)")
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(theme.background)
                        .cornerRadius(4)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                    .background(theme.background)

                ForEach(packages) { package in
                    InstalledPackageRow(package: package, store: store)
                        .listRowSeparator(.hidden)
                }
            }

            Divider()
                .background(theme.background)
        }
    }

    private var sourceName: String {
        switch source {
        case .nixpkgs: return "Nixpkgs"
        case .nix: return "Nix (system)"
        case .homebrewBrew: return "Homebrew"
        case .homebrewCask: return "Homebrew Casks"
        case .custom: return "Custom Apps"
        }
    }
}

struct InstalledPackageRow: View {
    let package: PackageItem
    @ObservedObject var store: StoreViewModel
    @Environment(\.omanixTheme) var theme
    @State private var isConfirming = false

    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(package.name)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(theme.text)
                if !package.description.isEmpty {
                    Text(package.description)
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button(action: { isConfirming = true }) {
                Label("Remove", systemImage: "minus.circle")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("Remove from configuration.nix")
            .alert("Remove Package", isPresented: $isConfirming) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive) {
                    Task { await store.uninstallPackage(package) }
                }
            } message: {
                Text("Remove \(package.name) from configuration.nix? Run 'omanix rebuild' to apply.")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}

#Preview {
    InstalledView(store: StoreViewModel())
}
