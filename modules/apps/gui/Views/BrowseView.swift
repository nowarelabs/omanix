// Views/BrowseView.swift
// "Browse" page. An empty query shows the Discover / trending feed.
// Typing searches nixpkgs + Homebrew + installed packages.

import SwiftUI

struct BrowseView: View {
    @EnvironmentObject private var vm: OmanixViewModel
    @State private var selectedFilter = "All"
    @State private var installingID: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                PageHeader(
                    breadcrumb: "Package Library / Discover",
                    title: vm.searchQuery.isEmpty ? "Discover" : "Results",
                    subtitle: subtitle
                ) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(resultCountText)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(OC.textPrimary)
                        Text("packages available")
                            .font(.system(size: 12))
                            .foregroundColor(OC.textSecondary)
                    }
                }

                if vm.searchQuery.isEmpty {
                    discoverContent
                } else {
                    searchResultsContent
                }
            }
            .padding(24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            StatusBar(left: statusLeft, rightText: brewStatusText, rightDotColor: OC.green)
        }
    }

    private var subtitle: String {
        vm.searchQuery.isEmpty
            ? "Curated tools for your next great build."
            : "Showing matches for \"\(vm.searchQuery)\""
    }

    private var resultCountText: String {
        vm.searchResults.isEmpty ? "0" : "\(vm.searchResults.count)"
    }

    private var statusLeft: String {
        vm.searchQuery.isEmpty
            ? "\(vm.installedCount) packages in \(vm.sourceCount) sources"
            : "\(vm.searchResults.count) results"
    }

    private var brewStatusText: String {
        if vm.isIndexingBrew { return "Updating index…" }
        return vm.brewIndexReady ? "Registry synced just now" : "Index not loaded"
    }

    // MARK: - Discover (empty state)

    private var discoverContent: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(spacing: 10) {
                ForEach(["All", "Developer", "Productivity", "Utilities"], id: \.self) { filter in
                    FilterPill(title: filter, selected: filter == selectedFilter) {
                        selectedFilter = filter
                    }
                }
            }

            Divider().overlay(OC.divider)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Trending").font(.system(size: 18, weight: .bold))
                    Text("Popular this week").font(.system(size: 13)).foregroundColor(OC.textSecondary)
                }
                HStack(alignment: .top, spacing: 16) {
                    ForEach(SampleDiscover.trending) { pkg in
                        TrendingCard(pkg: pkg)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Recently Added").font(.system(size: 18, weight: .bold))
                    Text("Fresh from the registry").font(.system(size: 13)).foregroundColor(OC.textSecondary)
                }
                CardBox {
                    VStack(spacing: 0) {
                        ForEach(Array(SampleDiscover.recentlyAdded.enumerated()), id: \.element.id) { i, pkg in
                            if i > 0 { Divider().overlay(OC.divider) }
                            RecentRow(pkg: pkg)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Search results

    private var searchResultsContent: some View {
        VStack(spacing: 0) {
            if vm.isSearching {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Searching…").font(.system(size: 13)).foregroundColor(OC.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if vm.searchResults.isEmpty {
                VStack(spacing: 12) {
                    Spacer().frame(height: 40)
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(OC.textTertiary)
                    Text("No packages match \"\(vm.searchQuery)\"")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(OC.textPrimary)
                    Text("Try a different search term.")
                        .font(.system(size: 12))
                        .foregroundColor(OC.textSecondary)
                    Spacer()
                }
            } else {
                CardBox {
                    VStack(spacing: 0) {
                        ForEach(Array(vm.searchResults.enumerated()), id: \.element.id) { i, pkg in
                            if i > 0 { Divider().overlay(OC.divider) }
                            SearchResultRow(
                                package: pkg,
                                isInstalling: installingID == pkg.id,
                                onInstall: {
                                    installingID = pkg.id
                                    Task { await vm.install(pkg); installingID = nil }
                                }
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Ready-only discover sample data

private enum SampleDiscover {
    static let trending: [DiscoverPackage] = [
        .init(name: "Docker Desktop", version: nil, description: "Build, share, and run containerized applications.",
              iconSystemName: "shippingbox.fill", iconColor: .init(hex: "0A7CFF"), installs: "12.4k installs"),
        .init(name: "Visual Studio Code", version: nil, description: "Lightweight but powerful source code editor.",
              iconSystemName: "chevron.left.forwardslash.chevron.right", iconColor: .init(hex: "0A7CFF"), installs: "9.8k installs"),
        .init(name: "Node.js", version: nil, description: "JavaScript runtime built on Chrome's V8 engine.",
              iconSystemName: "greaterthan.square.fill", iconColor: .init(hex: "34C759"), installs: "8.2k installs"),
    ]

    static let recentlyAdded: [DiscoverPackage] = [
        .init(name: "Raycast", version: "1.92.0", description: "A blazingly fast, delightful productivity launcher.",
              iconSystemName: "square.stack.3d.up.fill", iconColor: .init(hex: "E8536F"), installs: nil),
        .init(name: "uv", version: "0.6.14", description: "An extremely fast Python package and project manager.",
              iconSystemName: "arrow.down.circle.fill", iconColor: .init(hex: "9E86E8"), installs: nil),
        .init(name: "OrbStack", version: "1.9.1", description: "Fast, light Linux machines and containers for macOS.",
              iconSystemName: "internaldrive.fill", iconColor: .init(hex: "0A7CFF"), installs: nil),
    ]
}

private struct TrendingCard: View {
    let pkg: DiscoverPackage

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                IconSquare(systemName: pkg.iconSystemName, color: pkg.iconColor.toColor, size: 46)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill").font(.system(size: 9))
                    Text("Trending").font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(Color(hex: "9A7B1E"))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color(hex: "FCEFCB"))
                .clipShape(Capsule())
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(pkg.name).font(.system(size: 15, weight: .bold)).foregroundColor(OC.textPrimary)
                Text(pkg.description)
                    .font(.system(size: 12.5))
                    .foregroundColor(OC.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            HStack {
                if let installs = pkg.installs {
                    Text(installs).font(.system(size: 11.5)).foregroundColor(OC.textTertiary)
                }
                Spacer()
                FilledButton(title: "Install")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 168)
        .background(OC.cardBackground)
        .overlay(RoundedRectangle(cornerRadius: OMetrics.cardCorner).stroke(OC.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: OMetrics.cardCorner))
    }
}

private struct RecentRow: View {
    let pkg: DiscoverPackage

    var body: some View {
        HStack(spacing: 14) {
            IconSquare(systemName: pkg.iconSystemName, color: pkg.iconColor.toColor, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(pkg.name).font(.system(size: 13.5, weight: .bold)).foregroundColor(OC.textPrimary)
                    if let version = pkg.version {
                        Text(version).font(OFont.mono(11.5, weight: .regular)).foregroundColor(OC.textTertiary)
                    }
                }
                Text(pkg.description).font(.system(size: 12.5)).foregroundColor(OC.textSecondary)
            }
            Spacer()
            SoftFilledButton(title: "Install")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct SearchResultRow: View {
    let package: PackageItem
    let isInstalling: Bool
    let onInstall: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            IconSquare(
                systemName: PackageSourceStyle.icon(for: package.source),
                color: PackageSourceStyle.color(for: package.source),
                size: 36
            )
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(package.name).font(.system(size: 13.5, weight: .bold)).foregroundColor(OC.textPrimary)
                    Text(package.source.displayName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(PackageSourceStyle.color(for: package.source))
                }
                if !package.description.isEmpty {
                    Text(package.description)
                        .font(.system(size: 12.5))
                        .foregroundColor(OC.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if package.isInstalled {
                Label("Installed", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(OC.green)
            } else if isInstalling {
                ProgressView().controlSize(.small)
            } else {
                FilledButton(title: "Install", action: onInstall)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
