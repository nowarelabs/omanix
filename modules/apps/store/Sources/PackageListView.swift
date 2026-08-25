// modules/apps/store/Sources/PackageListView.swift
// Omanix — package browsing and installation
import SwiftUI

struct PackageListView: View {
    @ObservedObject var store: StoreViewModel
    @Binding var searchText: String
    @Binding var selectedPackage: PackageItem?
    @Environment(\.omanixTheme) var theme

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(theme.secondaryText)
                TextField("Search packages...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        store.packages = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(theme.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(theme.surface)
            .cornerRadius(8)
            .padding()
            .onChange(of: searchText) { _, newValue in
                store.search(query: newValue)
            }

            // Package list
            if store.isLoading {
                ProgressView("Searching...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.background)
            } else if store.packages.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "square.grid.3x3")
                        .font(.system(size: 48))
                        .foregroundColor(theme.secondaryText)
                    Text("Search for packages")
                        .font(.title2)
                        .foregroundColor(theme.secondaryText)
                    Text("Find packages from nixpkgs and Homebrew")
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.background)
            } else {
                List(store.packages, selection: $selectedPackage) { package in
                    PackageRow(package: package, store: store)
                        .listRowBackground(theme.surface)
                }
                .listStyle(.sidebar)
                .background(theme.background)
            }

            // Status bar
            HStack {
                if let error = store.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                } else if let success = store.successMessage {
                    Label(success, systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                } else {
                    Text("\(store.packages.count) packages found")
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
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
    }
}

struct PackageRow: View {
    let package: PackageItem
    @ObservedObject var store: StoreViewModel
    @Environment(\.omanixTheme) var theme

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(package.name)
                        .font(.headline)
                        .foregroundColor(theme.text)
                    SourceBadge(source: package.source)
                }
                Text(package.description)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                    .lineLimit(2)
            }

            Spacer()

            if package.isInstalled {
                Button(action: {
                    Task { await store.uninstallPackage(package) }
                }) {
                    Label("Installed", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                .buttonStyle(.borderless)
                .help("Click to uninstall")
            } else {
                Button(action: {
                    Task { await store.installPackage(package) }
                }) {
                    Label("Install", systemImage: "plus.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(theme.accent)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SourceBadge: View {
    let source: PackageItem.PackageSource

    var body: some View {
        Text(source.rawValue)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(source.badgeColor.opacity(0.2))
            .foregroundColor(source.badgeColor)
            .cornerRadius(4)
    }
}

#Preview {
    PackageListView(
        store: StoreViewModel(),
        searchText: .constant("ripgrep"),
        selectedPackage: .constant(nil)
    )
}
