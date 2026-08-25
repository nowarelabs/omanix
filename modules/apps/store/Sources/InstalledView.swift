// modules/apps/store/Sources/InstalledView.swift
// Omanix — view installed packages
import SwiftUI

struct InstalledView: View {
    @ObservedObject var store: StoreViewModel
    @State private var selectedPackage: PackageItem?
    @Environment(\.omanixTheme) var theme

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Installed Packages")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.text)
                    Text("\(store.installedPackages.count) packages installed")
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                }
                Spacer()
                Button(action: { store.loadInstalledPackages() }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(theme.accent)
            }
            .padding()

            if store.installedPackages.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.square")
                        .font(.system(size: 48))
                        .foregroundColor(theme.secondaryText)
                    Text("No packages installed")
                        .font(.title2)
                        .foregroundColor(theme.secondaryText)
                    Text("Use the Packages tab to install packages")
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.background)
            } else {
                List(store.packages.filter { store.installedPackages.contains($0.name) },
                     selection: $selectedPackage) { package in
                    InstalledPackageRow(package: package, store: store)
                        .listRowBackground(theme.surface)
                }
                .listStyle(.sidebar)
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
                    .lineLimit(1)
            }

            Spacer()

            Button(action: { isConfirming = true }) {
                Label("Remove", systemImage: "minus.circle")
                    .foregroundColor(.red)
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
