// Views/SettingsView.swift
// "Settings" page: system info + actions (rebuild / rollback / update).
// Appearance toggles are local UI state; system actions go through the VM.

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var vm: OmanixViewModel
    @State private var launchAtLogin = true
    @State private var checkFrequency = "Daily"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                PageHeader(
                    breadcrumb: "Omanix / Preferences",
                    title: "Settings",
                    subtitle: "Tune Omanix to fit the way you work."
                ) {
                    BorderedButton(title: "Save changes", icon: "checkmark")
                }

                // General
                SettingsSection(title: "General", subtitle: "How Omanix starts and stays within reach.") {
                    CardBox {
                        ToggleRow(title: "Launch at login", description: "Open Omanix automatically when you sign in.", isOn: $launchAtLogin)
                        Divider().overlay(OC.divider)
                        ToggleRow(title: "Save appearance locally", description: "Remember your Selected theme on this Mac.", isOn: .constant(true))
                    }
                }

                // System
                SettingsSection(title: "System", subtitle: "Live details about this Omanix machine.") {
                    CardBox {
                        InfoRow(label: "Hostname", value: vm.systemHost)
                        Divider().overlay(OC.divider)
                        InfoRow(label: "User", value: vm.systemUser)
                        Divider().overlay(OC.divider)
                        InfoRow(label: "Installed", value: "\(vm.installedCount) packages")
                        Divider().overlay(OC.divider)
                        InfoRow(label: "Sources", value: "\(vm.sourceCount)")
                        Divider().overlay(OC.divider)
                        InfoRow(label: "Configuration", value: "~/.omanix/configuration.nix")
                    }
                }

                // Actions
                SettingsSection(title: "Actions", subtitle: "Apply or roll back system changes.") {
                    CardBox {
                        ActionRow(title: "Rebuild System", subtitle: "Apply all configuration changes.", icon: "wrench.and.screwdriver.fill", color: OC.accentBlue) {
                            vm.rebuild()
                        }
                        Divider().overlay(OC.divider)
                        ActionRow(title: "Rollback", subtitle: "Revert to the previous generation.", icon: "arrow.uturn.backward", color: OC.orange) {
                            vm.rollback()
                        }
                        Divider().overlay(OC.divider)
                        ActionRow(title: "Update Flake Inputs", subtitle: "Pull latest nixpkgs and rebuild.", icon: "arrow.down.circle.fill", color: OC.green) {
                            vm.updateFlake()
                        }
                    }
                }
            }
            .padding(24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            StatusBar(
                left: "Omanix · version 2.4.0",
                rightText: "\(vm.sourceCount) active sources",
                rightDotColor: OC.green
            )
        }
    }
}

// MARK: - Section

private struct SettingsSection<Content: View, Accessory: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var accessory: () -> Accessory
    @ViewBuilder var content: () -> Content

    init(title: String, subtitle: String,
         @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() },
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 18, weight: .bold)).foregroundColor(OC.textPrimary)
                    if !subtitle.isEmpty {
                        Text(subtitle).font(.system(size: 13)).foregroundColor(OC.textSecondary)
                    }
                }
                Spacer()
                accessory()
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
            Text(label)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundColor(OC.textPrimary)
            Spacer()
            Text(value)
                .font(OFont.mono(12.5, weight: .regular))
                .foregroundColor(OC.textSecondary)
        }
        .padding(16)
    }
}

private struct ActionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                IconSquare(systemName: icon, color: color, size: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 13.5, weight: .semibold)).foregroundColor(OC.textPrimary)
                    Text(subtitle).font(.system(size: 12)).foregroundColor(OC.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(OC.textTertiary)
            }
            .padding(16)
        }
        .buttonStyle(.plain)
    }
}
