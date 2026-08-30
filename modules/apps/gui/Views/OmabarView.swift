// Views/OmabarView.swift
// "Omabar" page — control the Omanix status items that live inside the native macOS menu bar.
// Writes omanix.omabar.* in configuration.nix via the view model; applies live.

import SwiftUI

struct OmabarView: View {
    @EnvironmentObject private var vm: OmanixViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                PageHeader(
                    breadcrumb: "Library / Desktop",
                    title: "Omabar",
                    subtitle: "Status items inside the native macOS menu bar — Omanix draws no bar of its own, so it always matches the system look."
                ) {
                    if vm.needsRebuild {
                        FilledButton(title: "Rebuild", icon: "wrench.and.screwdriver.fill") { vm.rebuild() }
                    } else {
                        BorderedButton(title: "Manage", icon: "gearshape")
                    }
                }

                OmabarSection(title: "Contents", subtitle: "Which status items appear in the menu bar, left to right. A native Control Center item is hidden when Omanix shows the same thing, so nothing is duplicated.") {
                    CardBox {
                        ToggleRow(title: "Enable Omabar", description: "Show the Omanix status items at login. The macOS menu bar stays exactly as-is.", isOn: Binding(
                            get: { vm.omabarEnabled },
                            set: { vm.setOmabarEnabled($0) }
                        ))
                        Divider().overlay(OC.divider)
                        ToggleRow(title: "Clock", description: "Time and date — left-click opens Calendar, right-click the Date & Time settings.", isOn: Binding(
                            get: { vm.omabarShowClock },
                            set: { _ in vm.toggleOmabarShowClock() }
                        ))
                        Divider().overlay(OC.divider)
                        ToggleRow(title: "Battery", description: "Charge level, showing a bolt while charging — click opens the battery details menu.", isOn: Binding(
                            get: { vm.omabarShowBattery },
                            set: { _ in vm.toggleOmabarShowBattery() }
                        ))
                        Divider().overlay(OC.divider)
                        ToggleRow(title: "Volume", description: "Volume level — click it to mute or unmute.", isOn: Binding(
                            get: { vm.omabarShowVolume },
                            set: { _ in vm.toggleOmabarShowVolume() }
                        ))
                        Divider().overlay(OC.divider)
                        ToggleRow(title: "Wi-Fi", description: "Current network name in the menu, or a crossed-out icon when off.", isOn: Binding(
                            get: { vm.omabarShowWifi },
                            set: { _ in vm.toggleOmabarShowWifi() }
                        ))
                        Divider().overlay(OC.divider)
                        ToggleRow(title: "Running apps", description: "A menu of the apps you have open — click one to bring it to the front.", isOn: Binding(
                            get: { vm.omabarShowApps },
                            set: { _ in vm.toggleOmabarShowApps() }
                        ))
                    }
                }

                OmabarSection(title: "How it works", subtitle: "Why this module replaces nothing.") {
                    CardBox {
                        InfoRow(label: "Bar", value: "Native macOS menu bar, untouched")
                        Divider().overlay(OC.divider)
                        InfoRow(label: "Items", value: "NSStatusItem in Apple's bar")
                        Divider().overlay(OC.divider)
                        InfoRow(label: "Navigation", value: "1-finger swipes navigate between workspaces and groups stay separated (set activation)")
                        Divider().overlay(OC.divider)
                        InfoRow(label: "Omanix launcher", value: "Click the box to open the Store")
                    }
                }

                OmabarSection(title: "Run now", subtitle: "Try it without rebuilding — the running module obeys every setting above instantly.") {
                    CardBox {
                        HStack {
                            BorderedButton(title: "Restart bar", icon: "arrow.clockwise") {
                                vm.stopOmabar()
                                vm.launchOmabar()
                            }
                            if !vm.omabarRunning {
                                SoftFilledButton(title: "Launch Omabar now") { vm.launchOmabar() }
                            } else {
                                BorderedButton(title: "Stop bar", icon: "stop.fill") { vm.stopOmabar() }
                            }
                            Spacer()
                            Text("Also hides any native Control Center items this module replaces (after rebuild).")
                                .font(.system(size: 12))
                                .foregroundColor(OC.textSecondary)
                        }
                        .padding(14)
                    }
                }
            }
            .padding(24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            StatusBar(
                left: "Omabar · omanix.omabar",
                rightText: vm.omabarRunning ? "Running" : (vm.omabarEnabled ? "Configured" : "Disabled"),
                rightDotColor: vm.omabarRunning ? OC.green : (vm.omabarEnabled ? OC.orange : OC.red)
            )
        }
    }
}

// MARK: - Layout helpers (local to this page)

private struct OmabarSection<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 18, weight: .bold)).foregroundColor(OC.textPrimary)
                if !subtitle.isEmpty {
                    Text(subtitle).font(.system(size: 13)).foregroundColor(OC.textSecondary)
                }
            }
            content()
        }
    }
}

private struct ToggleRow: View {
    let title: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13.5, weight: .semibold)).foregroundColor(OC.textPrimary)
                Text(description).font(.system(size: 12)).foregroundColor(OC.textSecondary)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(OC.green)
        }
        .padding(16)
    }
}

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).font(.system(size: 13.5, weight: .semibold)).foregroundColor(OC.textPrimary)
            Spacer()
            Text(value)
                .font(OFont.mono(12, weight: .regular))
                .foregroundColor(OC.textSecondary)
        }
        .padding(16)
    }
}

#Preview {
    OmabarView()
        .environmentObject(OmanixViewModel())
        .frame(width: 1100, height: 760)
}