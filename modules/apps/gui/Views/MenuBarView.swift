// Views/MenuBarView.swift
// "Menu Bar" page — control the Omanix SketchyBar (macOS menu bar replacement).
// Writes omanix.bar.* in configuration.nix via the view model; rebuild to apply.

import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var vm: OmanixViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                PageHeader(
                    breadcrumb: "Library / Desktop",
                    title: "Menu Bar",
                    subtitle: "Replace the native macOS menu bar with the Omanix SketchyBar — theme-aware and event-driven."
                ) {
                    if vm.needsRebuild {
                        FilledButton(title: "Rebuild", icon: "wrench.and.screwdriver.fill") { vm.rebuild() }
                    } else {
                        BorderedButton(title: "Manage", icon: "gearshape")
                    }
                }

                // Live preview, styled from the current settings
                MenuSection(title: "Preview", subtitle: "How the bar will look after rebuild.") {
                    CardBox {
                        BarPreview(
                            position: vm.barPosition,
                            height: vm.barHeight,
                            transparent: vm.barTransparent,
                            style: vm.barStyle
                        )
                        .padding(16)
                    }
                }

                MenuSection(title: "Bar", subtitle: "Visual style and placement of the Omanix menu bar.") {
                    CardBox {
                        ToggleRow(title: "Enable menu bar", description: "Draw the Omanix bar and hide the native macOS menu bar.", isOn: Binding(
                            get: { vm.barEnabled },
                            set: { vm.setBarEnabled($0) }
                        ))
                        Divider().overlay(OC.divider)
                        SegmentRow(title: "Position", description: "Top flows around the MacBook notch.", options: [("top", "Top"), ("bottom", "Bottom")], selection: Binding(
                            get: { vm.barPosition },
                            set: { vm.setBarPosition($0) }
                        ))
                        Divider().overlay(OC.divider)
                        SegmentRow(title: "Style", description: "Glass forces transparency; modern rounds the workspace pills.", options: [("default", "Default"), ("glass", "Glass"), ("modern", "Modern"), ("minimal", "Minimal")], selection: Binding(
                            get: { vm.barStyle },
                            set: { vm.setBarStyle($0) }
                        ))
                        Divider().overlay(OC.divider)
                        SliderRow(title: "Height", description: "Bar height in points.", value: Binding(
                            get: { Double(vm.barHeight) },
                            set: { vm.setBarHeight(Int($0)) }
                        ), range: 24...48, step: 1, suffix: "pt")
                        Divider().overlay(OC.divider)
                        ToggleRow(title: "Transparent background", description: "Let the wallpaper show through the bar.", isOn: Binding(
                            get: { vm.barTransparent },
                            set: { _ in vm.toggleBarTransparent() }
                        ))
                        Divider().overlay(OC.divider)
                        ToggleRow(title: "Blur behind bar", description: "Frosted-glass blur over whatever is underneath.", isOn: Binding(
                            get: { vm.barBlur },
                            set: { _ in vm.toggleBarBlur() }
                        ))
                    }
                }

                MenuSection(title: "Contents", subtitle: "What items the bar shows, left to right.") {
                    CardBox {
                        InfoRow(label: "Omanix launcher", value: "Click the apple to open the Store")
                        Divider().overlay(OC.divider)
                        InfoRow(label: "Workspace pills", value: vm.barEnabled ? "1 2 3 4 5 6 7 8 9 T B I M N W" : "—")
                        Divider().overlay(OC.divider)
                        InfoRow(label: "Front app", value: "Focused app name + icon")
                        Divider().overlay(OC.divider)
                        InfoRow(label: "Right cluster", value: "Clock · Battery · Volume · Wi-Fi")
                    }
                }
            }
            .padding(24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            StatusBar(
                left: "Menu Bar · omanix.bar",
                rightText: vm.barEnabled ? "Enabled" : "Disabled",
                rightDotColor: vm.barEnabled ? OC.green : OC.red
            )
        }
    }
}

// MARK: - Live bar preview

private struct BarPreview: View {
    let position: String
    let height: Int
    let transparent: Bool
    let style: String

    private var pillHeight: CGFloat { max(22, CGFloat(height) - 8) }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(OC.accentBlue)
                ForEach(["1", "2", "3", "4", "I", "T"], id: \.self) { space in
                    let focused = space == "2"
                    Text(space)
                        .font(.system(size: 11, weight: focused ? .bold : .semibold))
                        .foregroundColor(focused ? .white : OC.textPrimary)
                        .frame(width: 22, height: pillHeight)
                        .background(focused ? OC.accentBlue : OC.subtleFill)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                Text("Omanix Store")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(OC.textSecondary)
                Spacer()
                HStack(spacing: 10) {
                    Image(systemName: "clock").font(.system(size: 11))
                    Text("Sat 29 Aug 09:41").font(.system(size: 11, weight: .semibold))
                    Image(systemName: "battery.100").font(.system(size: 11))
                    Image(systemName: "speaker.wave.2.fill").font(.system(size: 11))
                    Image(systemName: "wifi").font(.system(size: 11))
                }
                .foregroundColor(OC.textPrimary)
            }
            .padding(.horizontal, 10)
            .frame(height: CGFloat(height))
            .frame(maxWidth: .infinity)
            .background(barFill)
            .overlay(
                RoundedRectangle(cornerRadius: corner)
                    .stroke(OC.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: corner))

                HStack(spacing: 6) {
                    previewChip(text: "Position: \(position)")
                    previewChip(text: "Style: \(style)")
                    previewChip(text: "Height: \(height)pt")
                    if transparent { previewChip(text: "Transparent") }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var corner: CGFloat {
        style == "glass" ? 8 : style == "modern" ? 6 : 0
    }

    private var barFill: Color {
        transparent ? Color.white.opacity(0.35) : OC.cardBackground
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

private struct MenuSection<Content: View>: View {
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
            .frame(width: 240)
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

#Preview {
    MenuBarView()
        .environmentObject(OmanixViewModel())
        .frame(width: 1100, height: 760)
}