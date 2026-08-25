// modules/apps/store/Sources/InstalledView.swift
// Omanix Store — view installed packages
import SwiftUI

struct InstalledView: View {
    @ObservedObject var store: StoreViewModel
    @State private var selectedPackage: PackageItem?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Installed Packages")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("\(store.installedPackages.count) packages installed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: { store.loadInstalledPackages() }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()

            // Package list
            if store.installedPackages.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.square")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No packages installed")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Use the Packages tab to install packages")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(store.packages.filter { store.installedPackages.contains($0.name) },
                     selection: $selectedPackage) { package in
                    InstalledPackageRow(package: package, store: store)
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

struct InstalledPackageRow: View {
    let package: PackageItem
    @ObservedObject var store: StoreViewModel
    @State private var isConfirming = false

    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(package.name)
                        .font(.headline)
                    SourceBadge(source: package.source)
                }
                Text(package.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: { isConfirming = true }) {
                Label("Remove", systemImage: "minus.circle")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .help("Click to uninstall")
            .alert("Uninstall Package", isPresented: $isConfirming) {
                Button("Cancel", role: .cancel) { }
                Button("Uninstall", role: .destructive) {
                    Task { await store.uninstallPackage(package) }
                }
            } message: {
                Text("Are you sure you want to uninstall \(package.name)?")
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    InstalledView(store: StoreViewModel())
}
