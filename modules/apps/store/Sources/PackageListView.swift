// modules/apps/store/Sources/PackageListView.swift
// Omanix Store — package browsing and installation
import SwiftUI

struct PackageListView: View {
    @ObservedObject var store: StoreViewModel
    @Binding var searchText: String
    @Binding var selectedPackage: PackageItem?

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search packages...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        store.packages = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(.quaternary.opacity(0.3))
            .cornerRadius(8)
            .padding()
            .onChange(of: searchText) { _, newValue in
                store.search(query: newValue)
            }

            // Package list
            if store.isLoading {
                ProgressView("Searching...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.packages.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "square.grid.3x3")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Search for packages")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Find packages from nixpkgs and Homebrew")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(store.packages, selection: $selectedPackage) { package in
                    PackageRow(package: package, store: store)
                }
                .listStyle(.sidebar)
            }

            // Status bar
            HStack {
                if let error = store.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                } else if let success = store.successMessage {
                    Label(success, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                } else {
                    Text("\(store.packages.count) packages found")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Rebuild System") {
                    Task { await store.rebuild() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()
            .background(.bar)
        }
    }
}

struct PackageRow: View {
    let package: PackageItem
    @ObservedObject var store: StoreViewModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(package.name)
                        .font(.headline)
                    SourceBadge(source: package.source)
                }
                Text(package.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if package.isInstalled {
                Button(action: {
                    Task { await store.uninstallPackage(package) }
                }) {
                    Label("Installed", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
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
            .background(backgroundColor.opacity(0.2))
            .foregroundStyle(backgroundColor)
            .cornerRadius(4)
    }

    var backgroundColor: Color {
        switch source {
        case .nixpkgs: return .blue
        case .homebrew: return .orange
        case .custom: return .purple
        }
    }
}

#Preview {
    PackageListView(
        store: StoreViewModel(),
        searchText: .constant("ripgrep"),
        selectedPackage: .constant(nil)
    )
}
