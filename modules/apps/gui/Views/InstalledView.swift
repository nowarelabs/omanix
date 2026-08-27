// Views/InstalledView.swift
// "Installed" page: live list of declared packages from configuration.nix.

import SwiftUI

struct InstalledView: View {
    @EnvironmentObject private var vm: OmanixViewModel
    @State private var hoveredID: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    breadcrumb: "Package Library / Home",
                    title: "Installed",
                    subtitle: "\(vm.installedCount) packages in \(vm.sourceCount) sources"
                ) {
                    HStack(spacing: 10) {
                        BorderedButton(title: "Refresh", icon: "arrow.triangle.2.circlepath") {
                            vm.refreshDeclared()
                        }
                        if vm.needsRebuild {
                            FilledButton(title: "Rebuild", icon: "wrench.and.screwdriver.fill") {
                                vm.rebuild()
                            }
                        }
                    }
                }

                VStack(spacing: 0) {
                    HStack {
                        Text("PACKAGE")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(OC.textTertiary)
                        Spacer()
                        Text("STATUS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(OC.textTertiary)
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 12)

                    Divider().overlay(OC.divider)

                    if vm.declaredPackages.isEmpty {
                        emptyList
                    } else {
                        ForEach(vm.declaredPackages) { pkg in
                            InstalledRow(pkg: pkg, isHovered: hoveredID == pkg.id) {
                                Task { await vm.uninstall(pkg) }
                            }
                            .onHover { hovering in
                                hoveredID = hovering ? pkg.id : nil
                            }
                            Divider().overlay(OC.divider)
                        }
                    }
                }
            }
            .padding(24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            StatusBar(
                left: "\(vm.declaredPackages.count) of \(vm.installedCount) packages installed",
                trailingView: AnyView(
                    Button(action: { vm.rebuild() }) {
                        HStack(spacing: 6) {
                            if vm.isRebuilding {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "wrench.and.screwdriver.fill")
                            }
                            Text(vm.isRebuilding ? "Rebuilding…" : "Rebuild")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(OC.accentBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                )
            )
        }
    }

    private var emptyList: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 40)
            Image(systemName: "tray")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(OC.textTertiary)
            Text("No packages declared")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(OC.textPrimary)
            Text("Add packages with omanix add, or browse from the search bar.")
                .font(.system(size: 12))
                .foregroundColor(OC.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct InstalledRow: View {
    let pkg: PackageItem
    let isHovered: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(OC.green)

            RoundedRectangle(cornerRadius: 4)
                .stroke(OC.border, lineWidth: 1.4)
                .frame(width: 16, height: 16)

            IconSquare(
                systemName: PackageSourceStyle.icon(for: pkg.source),
                color: PackageSourceStyle.color(for: pkg.source),
                size: 28
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(pkg.name)
                    .font(OFont.mono(13.5))
                    .foregroundColor(OC.textPrimary)
                if !pkg.description.isEmpty {
                    Text(pkg.description)
                        .font(.system(size: 12))
                        .foregroundColor(OC.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                if isHovered {
                    Button(action: onRemove) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(OC.red)
                    }
                    .buttonStyle(.plain)
                }
                Text(pkg.source.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(PackageSourceStyle.color(for: pkg.source))
                Text("Installed")
                    .font(.system(size: 12.5))
                    .foregroundColor(OC.textSecondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .background(isHovered ? OC.lightBlueFill.opacity(0.6) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
