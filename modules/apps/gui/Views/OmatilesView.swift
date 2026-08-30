// Views/OmatilesView.swift
// "Omatiles" page — the Omanix bridge onto macOS' built-in window tiling.
// Redesigned to match the reference "Window Manager" screen: a two-column panel with
// Tiling / Layout / Spacing settings on the left and a live BSP desktop preview on the right,
// plus an Apply footer.
//
// The tiling switches mirror omanix.omatiles.* in configuration.nix (enable, enableEdgeDrag,
// enableKeyboardShortcuts, enableMargins, bindings). Layout (BSP/Grid/Monocle/Float) and
// Spacing values are presented for parity with the design and held session-locally — macOS
// Sequoia does the real tiling, and those controls are not yet declared options.

import SwiftUI
import ApplicationServices

struct OmatilesView: View {
    @EnvironmentObject private var vm: OmanixViewModel

    @State private var gap: Double = 8
    @State private var padding: Double = 4
    @State private var layout: TilingLayout = .bsp
    @State private var floatEnabled = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    HStack(alignment: .top, spacing: 20) {
                        VStack(alignment: .leading, spacing: 28) {
                            tilingSection
                            layoutSection
                            spacingSection
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        previewColumn
                    }
                }
                .padding(24)
            }

            footer
        }
    }

    // MARK: Header — eyebrow (blue, lightning icon) / title / subtitle

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(OC.accentBlue)
                    Text("SYSTEM UTILITY")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.5)
                        .foregroundColor(OC.accentBlue)
                }
                Text("Window Manager")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(OC.textPrimary)
                Text("Tiling & layout preferences")
                    .font(.system(size: 13))
                    .foregroundColor(OC.textSecondary)
            }
            Spacer()
        }
    }

    // MARK: Left column — Tiling

    private var tilingSection: some View {
        SectionHeader(title: "Tiling", caption: "BEHAVIOR") {
            CardBox {
                ToggleRow(
                    title: "Enable auto-tiling",
                    description: "Arrange new windows automatically",
                    isOn: Binding(get: { vm.omatilesEnabled }, set: { vm.setOmatilesEnabled($0) })
                )
                Divider().overlay(OC.divider)
                ToggleRow(
                    title: "Snap to screen edges",
                    description: "Keep windows aligned to the display",
                    isOn: Binding(get: { vm.omatilesEdgeDrag }, set: { vm.setOmatilesEdgeDrag($0) })
                )
                Divider().overlay(OC.divider)
                ToggleRow(
                    title: "Float new windows",
                    description: "Open new windows above the layout",
                    isOn: $floatEnabled
                )
            }
        }
    }

    // MARK: Left column — Layout

    private var layoutSection: some View {
        SectionHeader(title: "Layout", caption: "STRUCTURE") {
            VStack(alignment: .leading, spacing: 12) {
                // Dropdown-style selector (visual: shows the selected layout)
                Button(action: {}) {
                    HStack {
                        Text(layout.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(OC.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(OC.textTertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(OC.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(OC.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // 4 selectable layout tiles
                HStack(spacing: 10) {
                    ForEach(TilingLayout.allCases) { option in
                        LayoutTile(
                            layout: option,
                            selected: layout == option
                        ) {
                            withAnimation(.easeInOut(duration: 0.15)) { layout = option }
                        }
                    }
                }
            }
        }
    }

    // MARK: Left column — Spacing

    private var spacingSection: some View {
        SectionHeader(title: "Spacing", caption: nil, trailingIcon: "slider.horizontal.3") {
            CardBox {
                SliderRow(label: "Window gap", value: $gap, range: 0...24, unit: "px")
                Divider().overlay(OC.divider)
                SliderRow(label: "Inner padding", value: $padding, range: 0...24, unit: "px")
            }
        }
    }

    // MARK: Right column — Live preview

    private var previewColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Desktop preview")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(OC.textPrimary)
                    Text(layout.title)
                        .font(.system(size: 12))
                        .foregroundColor(OC.textSecondary)
                }
                Spacer()
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(OC.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)

            DesktopPreview(layout: layout, gap: gap, padding: padding)

            Text("Preview updates live")
                .font(.system(size: 11))
                .foregroundColor(OC.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .frame(width: 320)
        .background(OC.cardBackground)
        .overlay(RoundedRectangle(cornerRadius: OMetrics.cardCorner).stroke(OC.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: OMetrics.cardCorner))
    }

    // MARK: Footer — Apply bar

    private var footer: some View {
        HStack {
            Text("Changes are saved for this device")
                .font(.system(size: 12))
                .foregroundColor(OC.textSecondary)
            Spacer()
            FilledButton(title: "Apply", icon: "checkmark") { apply() }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(OC.toolBarBackground)
        .overlay(Rectangle().fill(OC.divider).frame(height: 1), alignment: .top)
    }

    private func apply() {
        // Persisted tiling switches already write + mark the system for rebuild on change;
        // Apply reconciles the running engine and posts a tiling sanity check when possible.
        if vm.omatilesEnabled {
            vm.launchOmatiles()
        } else {
            vm.stopOmatiles()
        }
    }
}

// MARK: - Layout options (session-local; macOS Sequoia does the real tiling)

private enum TilingLayout: String, CaseIterable, Identifiable {
    case bsp, grid, monocle, float
    var id: String { rawValue }

    var title: String {
        switch self {
        case .bsp:      return "BSP"
        case .grid:     return "Grid"
        case .monocle:  return "Monocle"
        case .float:    return "Float"
        }
    }

    var icon: String {
        switch self {
        case .bsp:      return "square.dashed"
        case .grid:     return "square.grid.2x2"
        case .monocle:  return "square.fill"
        case .float:    return "rectangle"
        }
    }
}

// MARK: - Section header (title left, caption/icon right)

private struct SectionHeader<Content: View>: View {
    let title: String
    let caption: String?
    var trailingIcon: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(OC.textPrimary)
                Spacer()
                if let trailingIcon {
                    Image(systemName: trailingIcon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(OC.textTertiary)
                } else if let caption {
                    Text(caption)
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.5)
                        .foregroundColor(OC.textTertiary)
                }
            }
            content()
        }
    }
}

// MARK: - Toggle row

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
                .tint(OC.accentBlue)
        }
        .padding(16)
    }
}

// MARK: - Selectable layout tile

private struct LayoutTile: View {
    let layout: TilingLayout
    let selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: layout.icon)
                    .font(.system(size: 20, weight: .medium))
                Text(layout.title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(selected ? OC.accentBlue : OC.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(selected ? OC.lightBlueFill : Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(selected ? OC.accentBlue : OC.border, lineWidth: selected ? 1.5 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Slider row

private struct SliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(label).font(.system(size: 13.5, weight: .semibold)).foregroundColor(OC.textPrimary)
                Spacer()
                Text("\(Int(value))\(unit)")
                    .font(OFont.mono(12, weight: .semibold))
                    .foregroundColor(OC.accentBlue)
            }
            Slider(value: $value, in: range, step: 1)
                .tint(OC.accentBlue)
        }
        .padding(16)
    }
}

// MARK: - Desktop preview

private struct DesktopPreview: View {
    let layout: TilingLayout
    let gap: Double
    let padding: Double

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10)
                .fill(OC.subtleFill)
            RoundedRectangle(cornerRadius: 10)
                .stroke(OC.border, lineWidth: 1)

            HStack(spacing: CGFloat(gap)) {
                previewPane(fill: OC.lightBlueFill, titleBar: OC.accentBlue)
                VStack(spacing: CGFloat(gap)) {
                    previewPane(fill: Color.white, titleBar: OC.textTertiary)
                    previewPane(fill: OC.lightBlueFill, titleBar: OC.accentBlue)
                }
            }
            .padding(CGFloat(padding))
        }
        .frame(height: 300)
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    private func previewPane(fill: Color, titleBar: Color) -> some View {
        VStack(spacing: 0) {
            Rectangle().fill(titleBar).frame(height: 10)
            Rectangle().fill(fill)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(OC.border, lineWidth: 1))
        .opacity(layout == .float ? 0.45 : 1)
    }
}

#Preview {
    OmatilesView()
        .environmentObject(OmanixViewModel())
        .frame(width: 1100, height: 760)
}
