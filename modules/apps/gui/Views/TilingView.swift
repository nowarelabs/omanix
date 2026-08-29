// Views/TilingView.swift
// "Tiling" page — control the Omanix window tiling manager (AeroSpace).
// Writes omanix.tiling.* in configuration.nix via the view model; rebuild to apply.

import SwiftUI

struct TilingView: View {
    @EnvironmentObject private var vm: OmanixViewModel

    private let layouts: [(value: String, label: String)] = [
        ("tiles", "Tiles"),
        ("accordion", "Accordion"),
        ("floating", "Floating"),
    ]

    @State private var searchLayout = "tiles"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                PageHeader(
                    breadcrumb: "Library / Desktop",
                    title: "Window Tiling",
                    subtitle: "Tile and manage windows i3-style with AeroSpace — split, move, fullscreen, and workspace shortcuts."
                ) {
                    if vm.needsRebuild {
                        FilledButton(title: "Rebuild", icon: "wrench.and.screwdriver.fill") { vm.rebuild() }
                    } else {
                        BorderedButton(title: "Manage", icon: "gearshape")
                    }
                }

                // Live layout preview
                TilingSection(title: "Preview", subtitle: "How windows sit inside a workspace at your current gaps.") {
                    CardBox {
                        LayoutPreview(layout: vm.tilingLayout, gapInner: vm.tilingGapInner, gapOuter: vm.tilingGapOuter)
                            .padding(16)
                    }
                }

                TilingSection(title: "Tiling", subtitle: "Behaviour of the window tiling manager.") {
                    CardBox {
                        ToggleRow(title: "Enable tiling", description: "Pass every window through the i3-like layout as it opens. Off restores native macOS window behaviour.", isOn: Binding(
                            get: { vm.tilingEnabled },
                            set: { vm.setTilingEnabled($0) }
                        ))
                        Divider().overlay(OC.divider)
                        SegmentRow(title: "Default layout", description: "Tiles strict-grid, accordion stacks in a row, floating ignores tiling.", options: layouts, selection: Binding(
                            get: { vm.tilingLayout },
                            set: { vm.setTilingLayout($0) }
                        ))
                        Divider().overlay(OC.divider)
                        SliderRow(title: "Inner gap", description: "Space between tiled windows.", value: Binding(
                            get: { Double(vm.tilingGapInner) },
                            set: { vm.setTilingGapInner(Int($0)) }
                        ), range: 0...24, step: 2, suffix: "px")
                        Divider().overlay(OC.divider)
                        SliderRow(title: "Outer gap", description: "Space between tiled windows and the screen edge.", value: Binding(
                            get: { Double(vm.tilingGapOuter) },
                            set: { vm.setTilingGapOuter(Int($0)) }
                        ), range: 0...32, step: 2, suffix: "px")
                    }
                }

                TilingSection(title: "Setup rules", subtitle: "Apps that stay pinned in place instead of tiling.") {
                    CardBox {
                        InfoRow(label: "3 floating apps", value: "Finder · Settings · Activity Monitor")
                        Divider().overlay(OC.divider)
                        InfoRow(label: "Terminals → workspace T", value: "Ghostty · Terminal")
                        Divider().overlay(OC.divider)
                        InfoRow(label: "Chrome → workspace B", value: "Browser pinned to B")
                        Divider().overlay(OC.divider)
                        InfoRow(label: "Messaging → workspace I", value: "Slack · Discord · Notes")
                    }
                }

                TilingSection(title: "Shortcuts", subtitle: "The vim-style keymap. Hold ⌥ (Option) and press…") {
                    CardBox {
                        ShortcutRow(keys: "⌥ H J K L", action: "Focus window left / down / up / right")
                        Divider().overlay(OC.divider)
                        ShortcutRow(keys: "⌥⇧ H J K L", action: "Move the focused window")
                        Divider().overlay(OC.divider)
                        ShortcutRow(keys: "⌥ 1 … 9, A–Z", action: "Jump to workspace")
                        Divider().overlay(OC.divider)
                        ShortcutRow(keys: "⌥⇧ 1 … 9", action: "Move window to workspace")
                        Divider().overlay(OC.divider)
                        ShortcutRow(keys: "⌥ F", action: "Toggle fullscreen")
                        Divider().overlay(OC.divider)
                        ShortcutRow(keys: "⌥ Space", action: "Open the Omanix Store")
                        Divider().overlay(OC.divider)
                        ShortcutRow(keys: "⌥ /", action: "Layout tiles / accordion")
                        Divider().overlay(OC.divider)
                        ShortcutRow(keys: "⌥ − / +", action: "Resize the focused window")
                    }
                }
            }
            .padding(24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            StatusBar(
                left: "Window Tiling · omanix.tiling",
                rightText: "\(vm.tilingGapInner)px / \(vm.tilingGapOuter)px gaps",
                rightDotColor: OC.green
            )
        }
    }
}

// MARK: - Layout preview (tiles / accordion / floating)

private struct LayoutPreview: View {
    let layout: String
    let gapInner: Int
    let gapOuter: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(OC.pageBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(OC.cyan.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        )

                    switch layout {
                    case "accordion":
                        pane(width: w - CGFloat(gapOuter) * 0 - 24, height: h - 20, label: "A", color: OC.cyan)
                            .offset(x: 12, y: 10)
                    case "floating":
                        pane(width: w * 0.42, height: h * 0.46, label: "1", color: OC.orange.opacity(0.55))
                            .offset(x: w * 0.30, y: 18)
                        pane(width: w * 0.42, height: h * 0.46, label: "2", color: OC.purple.opacity(0.55))
                            .offset(x: w * 0.34, y: 34)
                    default: // tiles
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: CGFloat(gapInner)), GridItem(.flexible(), spacing: CGFloat(gapInner))], spacing: CGFloat(gapInner)) {
                            pane(label: "1", color: OC.cyan)
                            pane(label: "2", color: OC.purple)
                            HStack(spacing: CGFloat(gapInner)) {
                                pane(label: "3", color: OC.orange)
                                pane(label: "4", color: OC.green)
                            }
                        }
                        .padding(CGFloat(gapOuter))
                    }
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
        pane(width: nil, height: nil, label: label, color: color)
    }

    private func pane(width: CGFloat?, height: CGFloat?, label: String, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(color)
            .frame(width: width, height: height)
            .overlay(
                Text(label)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            )
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

private struct TilingSection<Content: View>: View {
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
            .frame(width: 260)
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
    TilingView()
        .environmentObject(OmanixViewModel())
        .frame(width: 1100, height: 760)
}