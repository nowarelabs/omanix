// Views/OmatilesView.swift
// "Omatiles" page — control the native Omanix window tiling engine.
// Writes omanix.omatiles.* in configuration.nix via the view model; applies live.

import SwiftUI
import ApplicationServices

struct OmatilesView: View {
    @EnvironmentObject private var vm: OmanixViewModel

    private let layouts: [(value: String, label: String)] = [
        ("tiles", "Tiles"),
        ("columns", "Columns"),
        ("rows", "Rows"),
        ("accordion", "Accordion"),
    ]

    @State private var floatingText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                PageHeader(
                    breadcrumb: "Library / Desktop",
                    title: "Omatiles",
                    subtitle: "Native window tiling, built into Omanix — no external window manager. Tile on demand, cycle layouts, or watch windows automatically."
                ) {
                    if vm.needsRebuild {
                        FilledButton(title: "Rebuild", icon: "wrench.and.screwdriver.fill") { vm.rebuild() }
                    } else {
                        BorderedButton(title: "Manage", icon: "gearshape")
                    }
                }

                // Live layout preview
                OmatilesSection(title: "Preview", subtitle: "How windows sit inside the screen at your current gaps.") {
                    CardBox {
                        LayoutPreview(layout: vm.omatilesLayout, gapInner: vm.omatilesGapInner, gapOuter: vm.omatilesGapOuter)
                            .padding(16)
                    }
                }

                OmatilesSection(title: "Tiling", subtitle: "Behaviour of the tiling engine.") {
                    CardBox {
                        ToggleRow(title: "Enable tiling", description: "Start Omatiles at login and keep windows in the layout. Off restores native macOS window behaviour.", isOn: Binding(
                            get: { vm.omatilesEnabled },
                            set: { vm.setOmatilesEnabled($0) }
                        ))
                        Divider().overlay(OC.divider)
                        SegmentRow(title: "Default layout", description: "Tiles strict-grid, columns vertical splits, rows horizontal stacks, accordion one master + stack.", options: layouts, selection: Binding(
                            get: { vm.omatilesLayout },
                            set: { vm.setOmatilesLayout($0) }
                        ))
                        Divider().overlay(OC.divider)
                        SliderRow(title: "Inner gap", description: "Space between tiled windows.", value: Binding(
                            get: { Double(vm.omatilesGapInner) },
                            set: { vm.setOmatilesGapInner(Int($0)) }
                        ), range: 0...24, step: 2, suffix: "px")
                        Divider().overlay(OC.divider)
                        SliderRow(title: "Outer gap", description: "Space between tiled windows and the screen edge (plus the Omabar on its edge).", value: Binding(
                            get: { Double(vm.omatilesGapOuter) },
                            set: { vm.setOmatilesGapOuter(Int($0)) }
                        ), range: 0...32, step: 2, suffix: "px")
                        Divider().overlay(OC.divider)
                        ToggleRow(title: "Key bindings", description: "Global ⌘⌥ shortcuts for tiling and focus (see below).", isOn: Binding(
                            get: { vm.omatilesBindings },
                            set: { _ in vm.toggleOmatilesBindings() }
                        ))
                        Divider().overlay(OC.divider)
                        ToggleRow(title: "Watch windows", description: "Automatically re-apply the layout when the set of windows on screen changes.", isOn: Binding(
                            get: { vm.omatilesWatch },
                            set: { _ in vm.toggleOmatilesWatch() }
                        ))
                    }
                }

                OmatilesSection(title: "Floating apps", subtitle: "Bundle IDs whose windows are never tiled (dialogs, system panels, overlays). One per line.") {
                    CardBox {
                        TextEditor(text: $floatingText)
                            .font(OFont.mono(12, weight: .regular))
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 110)
                            .padding(12)
                        Divider().overlay(OC.divider)
                        HStack {
                            BorderedButton(title: "Reload", icon: "arrow.clockwise") { loadFloatingText() }
                            Spacer()
                            SoftFilledButton(title: "Save floating apps") { saveFloatingText() }
                        }
                        .padding(14)
                    }
                }
                .onAppear { loadFloatingText() }

                OmatilesSection(title: "Shortcuts", subtitle: "Global bindings. Press…") {
                    CardBox {
                        ShortcutRow(keys: "⌘⌥ T", action: "Tile every window now")
                        Divider().overlay(OC.divider)
                        ShortcutRow(keys: "⌘⌥ J", action: "Focus the previous window")
                        Divider().overlay(OC.divider)
                        ShortcutRow(keys: "⌘⌥ K", action: "Focus the next window")
                        Divider().overlay(OC.divider)
                        ShortcutRow(keys: "⌘⌥ L", action: "Cycle layout: tiles → columns → rows → accordion")
                    }
                }

                OmatilesSection(title: "Get started", subtitle: "Tiling repositions windows through the Accessibility API, so Omanix needs your permission (granted once).") {
                    CardBox {
                        InfoRow(label: "Accessibility permission", value: accessibilityGranted ? "Granted" : "Not granted")
                        Divider().overlay(OC.divider)
                        HStack {
                            BorderedButton(title: accessibilityGranted ? "Re-check" : "Grant Access", icon: accessibilityGranted ? "checkmark.shield" : "lock.shield") {
                                _ = OmatilesEngine.ensureAccessibility()
                            }
                            SoftFilledButton(title: "Tile now") { vm.tileNow() }
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
                rightText: vm.omatilesRunning ? "\(vm.omatilesTiledCount) windows tiled" : "Stopped",
                rightDotColor: vm.omatilesRunning ? OC.green : (vm.omatilesEnabled ? OC.orange : OC.red)
            )
        }
    }

    private var accessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    private func loadFloatingText() {
        floatingText = vm.omatilesFloatingApps.joined(separator: "\n")
    }

    private func saveFloatingText() {
        let lines = floatingText.components(separatedBy: .newlines)
        vm.setOmatilesFloatingApps(lines)
        loadFloatingText()
    }
}

// MARK: - Layout preview (tiles / columns / rows / accordion)

private struct LayoutPreview: View {
    let layout: String
    let gapInner: Int
    let gapOuter: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(OC.pageBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(OC.cyan.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        )

                    VStack(spacing: CGFloat(gapInner)) {
                        switch layout {
                        case "columns":
                            HStack(spacing: CGFloat(gapInner)) {
                                pane(label: "1", color: OC.cyan)
                                pane(label: "2", color: OC.purple)
                                pane(label: "3", color: OC.orange)
                            }
                        case "rows":
                            pane(label: "1", color: OC.cyan)
                            pane(label: "2", color: OC.purple)
                            pane(label: "3", color: OC.orange)
                        case "accordion":
                            HStack(spacing: CGFloat(gapInner)) {
                                pane(label: "A", color: OC.cyan)
                                VStack(spacing: CGFloat(gapInner)) {
                                    pane(label: "B", color: OC.purple)
                                    pane(label: "C", color: OC.orange)
                                }
                            }
                        default: // tiles
                            VStack(spacing: CGFloat(gapInner)) {
                                HStack(spacing: CGFloat(gapInner)) {
                                    pane(label: "1", color: OC.cyan)
                                    pane(label: "2", color: OC.purple)
                                }
                                HStack(spacing: CGFloat(gapInner)) {
                                    pane(label: "3", color: OC.orange)
                                    pane(label: "4", color: OC.green)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(CGFloat(gapOuter))
                }
            }
            .frame(height: 190)

            HStack(spacing: 6) {
                previewChip(text: "Layout: \(layout)")
                previewChip(text: "Inner: \(gapInner)px")
                previewChip(text: "Outer: \(gapOuter)px")
            }
        }
    }

    private func pane(label: String, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(color)
            .overlay(
                Text(label)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func previewChip(text: String) -> some View {
        Text(text)
            .font(OFont.mono(10.5, weight: .regular))
            .foregroundColor(OC.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(OC.subtleFill)
            .clipShape(RoundedRectangle(cornerRadius: 5))
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

private struct SegmentRow: View {
    let title: String
    let description: String
    let options: [(value: String, label: String)]
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13.5, weight: .semibold)).foregroundColor(OC.textPrimary)
                Text(description).font(.system(size: 12)).foregroundColor(OC.textSecondary)
            }
            Spacer()
            Picker(title, selection: $selection) {
                ForEach(options, id: \.value) { option in
                    Text(option.label).tag(option.value)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 280)
        }
        .padding(16)
    }
}

private struct SliderRow: View {
    let title: String
    let description: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let suffix: String

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13.5, weight: .semibold)).foregroundColor(OC.textPrimary)
                Text(description).font(.system(size: 12)).foregroundColor(OC.textSecondary)
            }
            Spacer()
            Slider(value: $value, in: range, step: step) {
                Text(title)
            } minimumValueLabel: {
                Text("\(Int(range.lowerBound))")
            } maximumValueLabel: {
                Text("\(Int(range.upperBound))")
            }
            .frame(width: 180)
            Text("\(Int(value))\(suffix)")
                .font(OFont.mono(12.5, weight: .semibold))
                .foregroundColor(OC.textPrimary)
                .frame(width: 46, alignment: .trailing)
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
                .frame(minWidth: 120, alignment: .leading)
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