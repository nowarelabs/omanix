// Views/OmatilesView.swift
// "Omatiles" page — the Omanix bridge onto macOS' built-in window tiling.
// Writes omanix.omatiles.* in configuration.nix via the view model; applies live.

import SwiftUI
import ApplicationServices

struct OmatilesView: View {
    @EnvironmentObject private var vm: OmanixViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                PageHeader(
                    breadcrumb: "Library / Desktop",
                    title: "Omatiles",
                    subtitle: "The macOS Sequoia tiling system, configured and shortcut-driven by Omanix — the Operating System does the actual tiling."
                ) {
                    if vm.needsRebuild {
                        FilledButton(title: "Rebuild", icon: "wrench.and.screwdriver.fill") { vm.rebuild() }
                    } else {
                        BorderedButton(title: "Manage", icon: "gearshape")
                    }
                }

                OmatilesSection(title: "Tiling", subtitle: "macOS Sequoia window management, switched on from Omanix. These set the same System Settings → Desktop & Dock → Window Management switches at activation time.") {
                    CardBox {
                        ToggleRow(title: "Enable tiling", description: "Turn on the macOS tiling system. Off restores the default window behaviour.", isOn: Binding(
                            get: { vm.omatilesEnabled },
                            set: { vm.setOmatilesEnabled($0) }
                        ))
                        Divider().overlay(OC.divider)
                        ToggleRow(title: "Edge drag", description: "Drag a window against a screen edge to tile it. Requires macOS Sequoia.", isOn: Binding(
                            get: { vm.omatilesEdgeDrag },
                            set: { vm.setOmatilesEdgeDrag($0) }
                        ))
                        Divider().overlay(OC.divider)
                        ToggleRow(title: "Keyboard shortcuts", description: "The system ⌃⌥ + arrow tiling shortcuts, plus our ⌘⌥ mapping on top.", isOn: Binding(
                            get: { vm.omatilesKeyboardShortcuts },
                            set: { vm.setOmatilesKeyboardShortcuts($0) }
                        ))
                        Divider().overlay(OC.divider)
                        ToggleRow(title: "Gaps between tiled windows", description: "Show a gap between windows when one is tiled next to another by the operating system.", isOn: Binding(
                            get: { vm.omatilesMargins },
                            set: { vm.setOmatilesMargins($0) }
                        ))
                        Divider().overlay(OC.divider)
                        ToggleRow(title: "Omatiles bindings", description: "⌘⌥ arrows and ⌘⌥ Z, which forward to the system's own tiling shortcuts.", isOn: Binding(
                            get: { vm.omatilesBindings },
                            set: { _ in vm.toggleOmatilesBindings() }
                        ))
                    }
                }

                OmatilesSection(title: "Shortcuts", subtitle: "Each ⌘⌥ binding posts the operating system's own ⌃⌥ shortcut, so tiling behaves exactly like native macOS.") {
                    CardBox {
                        ShortcutRow(keys: "⌘⌥ ←", action: "Tile on the left half")
                        Divider().overlay(OC.divider)
                        ShortcutRow(keys: "⌘⌥ →", action: "Tile on the right half")
                        Divider().overlay(OC.divider)
                        ShortcutRow(keys: "⌘⌥ ↑", action: "Tile on the top half")
                        Divider().overlay(OC.divider)
                        ShortcutRow(keys: "⌘⌥ ↓", action: "Tile on the bottom half")
                        Divider().overlay(OC.divider)
                        ShortcutRow(keys: "⌘⌥ Z", action: "Untile the focused window")
                    }
                }

                OmatilesSection(title: "Get started", subtitle: "Forwarding the shortcuts posts CGEvents, so Omanix needs Accessibility permission (granted once) plus macOS Sequoia's window management enabled.") {
                    CardBox {
                        InfoRow(label: "Accessibility permission", value: accessibilityGranted ? "Granted" : "Not granted")
                        Divider().overlay(OC.divider)
                        HStack {
                            BorderedButton(title: accessibilityGranted ? "Re-check" : "Grant Access", icon: accessibilityGranted ? "checkmark.shield" : "lock.shield") {
                                _ = OmatilesEngine.ensureAccessibility()
                            }
                            SoftFilledButton(title: "Try: tile left half") { vm.tileLeftHalf() }
                            Spacer()
                            if vm.omatilesRunning {
                                BorderedButton(title: "Stop module", icon: "stop.fill") { vm.stopOmatiles() }
                            } else {
                                BorderedButton(title: "Launch module", icon: "play.fill") { vm.launchOmatiles() }
                            }
                        }
                        .padding(14)
                    }
                }
            }
            .padding(24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            StatusBar(
                left: "Omatiles · omanix.omatiles",
                rightText: vm.omatilesRunning ? "Shortcuts active" : "Stopped",
                rightDotColor: vm.omatilesRunning ? OC.green : (vm.omatilesEnabled ? OC.orange : OC.red)
            )
        }
    }

    private var accessibilityGranted: Bool {
        AXIsProcessTrusted()
    }
}

// MARK: - Layout helpers (local to this page)

private struct OmatilesSection<Content: View>: View {
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

private struct ShortcutRow: View {
    let keys: String
    let action: String

    var body: some View {
        HStack(spacing: 14) {
            Text(keys)
                .font(OFont.mono(12, weight: .semibold))
                .foregroundColor(OC.accentBlue)
                .frame(minWidth: 90, alignment: .leading)
            Text(action)
                .font(.system(size: 13))
                .foregroundColor(OC.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }
}

#Preview {
    OmatilesView()
        .environmentObject(OmanixViewModel())
        .frame(width: 1100, height: 760)
}