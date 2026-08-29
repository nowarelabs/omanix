// Views/OmabarView.swift
// "Omabar" page — control the native Omanix menu bar module.
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
                    subtitle: "Native macOS menu bar replacement, built into Omanix as a SwiftUI module — no SketchyBar, no external process."
                ) {
                    if vm.needsRebuild {
                        FilledButton(title: "Rebuild", icon: "wrench.and.screwdriver.fill") { vm.rebuild() }
                    } else {
                        BorderedButton(title: "Manage", icon: "gearshape")
                    }
                }

                // Live preview, styled from the current settings
                OmabarSection(title: "Preview", subtitle: "How the bar will look, drawn from your current settings.") {
                    CardBox {
                        BarPreview(
                            position: vm.omabarPosition,
                            height: vm.omabarHeight,
                            transparent: vm.omabarTransparent,
                            blur: vm.omabarBlur,
                            style: vm.omabarStyle
                        )
                        .padding(16)
                    }
                }

                OmabarSection(title: "Bar", subtitle: "Visual style and placement of the Omanix menu bar.") {
                    CardBox {
                        ToggleRow(title: "Enable Omabar", description: "Draw the Omanix bar and hide the native macOS menu bar. Starts automatically at login.", isOn: Binding(
                            get: { vm.omabarEnabled },
                            set: { vm.setOmabarEnabled($0) }
                        ))
                        Divider().overlay(OC.divider)
                        SegmentRow(title: "Position", description: "Top flows around the MacBook notch.", options: [("top", "Top"), ("bottom", "Bottom")], selection: Binding(
                            get: { vm.omabarPosition },
                            set: { vm.setOmabarPosition($0) }
                        ))
                        Divider().overlay(OC.divider)
                        SegmentRow(title: "Style", description: "Glass is a floating rounded pill; modern rounds the workspace pills; minimal drops backgrounds.", options: [("default", "Default"), ("glass", "Glass"), ("modern", "Modern"), ("minimal", "Minimal")], selection: Binding(
                            get: { vm.omabarStyle },
                            set: { vm.setOmabarStyle($0) }
                        ))
                        Divider().overlay(OC.divider)
                        SegmentRow(title: "Appearance", description: "Auto follows the theme mode (light/dark).", options: [("auto", "Auto"), ("dark", "Dark"), ("light", "Light")], selection: Binding(
                            get: { vm.omabarColorScheme },
                            set: { vm.setOmabarColorScheme($0) }
                        ))
                        Divider().overlay(OC.divider)
                        SliderRow(title: "Height", description: "Bar height in points.", value: Binding(
                            get: { Double(vm.omabarHeight) },
                            set: { vm.setOmabarHeight(Int($0)) }
                        ), range: 24...48, step: 1, suffix: "pt")
                        Divider().overlay(OC.divider)
                        ToggleRow(title: "Transparent background", description: "Let the wallpaper show through the bar.", isOn: Binding(
                            get: { vm.omabarTransparent },
                            set: { _ in vm.toggleOmabarTransparent() }
                        ))
                        Divider().overlay(OC.divider)
                        ToggleRow(title: "Blur behind bar", description: "Frosted-glass blur over whatever is underneath.", isOn: Binding(
                            get: { vm.omabarBlur },
                            set: { _ in vm.toggleOmabarBlur() }
                        ))
                    }
                }

                OmabarSection(title: "Contents", subtitle: "What the bar shows, left to right.") {
                    CardBox {
                        ToggleRow(title: "Clock", description: "Day, month, and time on the right edge.", isOn: Binding(
                            get: { vm.omabarShowClock },
                            set: { _ in vm.toggleOmabarShowClock() }
                        ))
                        Divider().overlay(OC.divider)
                        ToggleRow(title: "Battery", description: "Charge level, showing a bolt while charging.", isOn: Binding(
                            get: { vm.omabarShowBattery },
                            set: { _ in vm.toggleOmabarShowBattery() }
                        ))
                        Divider().overlay(OC.divider)
                        ToggleRow(title: "Volume", description: "Volume level — click it to toggle mute.", isOn: Binding(
                            get: { vm.omabarShowVolume },
                            set: { _ in vm.toggleOmabarShowVolume() }
                        ))
                        Divider().overlay(OC.divider)
                        ToggleRow(title: "Wi-Fi", description: "Current network name, or a crossed-out icon when off.", isOn: Binding(
                            get: { vm.omabarShowWifi },
                            set: { _ in vm.toggleOmabarShowWifi() }
                        ))
                        Divider().overlay(OC.divider)
                        InfoRow(label: "Omanix launcher", value: "Click the box to open the Store")
                        Divider().overlay(OC.divider)
                        InfoRow(label: "App pills", value: "Visible apps, focused highlighted")
                    }
                }

                OmabarSection(title: "Run now", subtitle: "Try the bar without rebuilding — the running module obeys every setting above instantly.") {
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
                            Text("Starts automatically at login after rebuild.")
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

// MARK: - Live bar preview

private struct BarPreview: View {
    let position: String
    let height: Int
    let transparent: Bool
    let blur: Bool
    let style: String

    private var pillHeight: CGFloat { max(22, CGFloat(height) - 8) }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(OC.accentBlue)
                ForEach(["1", "2", "3", "4", "5"], id: \.self) { space in
                    let focused = space == "3"
                    Text(space)
                        .font(.system(size: 11, weight: focused ? .bold : .semibold))
                        .foregroundColor(focused ? .white : OC.textPrimary)
                        .frame(width: 22, height: pillHeight)
                        .background(focused ? OC.accentBlue : OC.subtleFill)
                        .clipShape(RoundedRectangle(cornerRadius: style == "modern" || style == "glass" ? 8 : 5))
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(OC.textTertiary)
                Text("Omanix Store")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(OC.textSecondary)
                Spacer()
                HStack(spacing: 10) {
                    Image(systemName: "speaker.wave.2.fill").font(.system(size: 11))
                    Image(systemName: "wifi").font(.system(size: 11))
                    Image(systemName: "battery.100").font(.system(size: 11))
                    Text("Sat 29 Aug 09:41").font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(OC.textPrimary)
            }
            .padding(.horizontal, 10)
            .frame(height: CGFloat(height))
            .frame(maxWidth: .infinity)
            .background(barFill)
            .overlay(
                RoundedRectangle(cornerRadius: barCorner)
                    .stroke(OC.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: barCorner))

            HStack(spacing: 6) {
                previewChip(text: "Position: \(position)")
                previewChip(text: "Style: \(style)")
                previewChip(text: "Height: \(height)pt")
                if transparent { previewChip(text: "Transparent") }
                if blur { previewChip(text: "Blur") }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var barCorner: CGFloat {
        style == "glass" ? 13 : 0
    }

    private var barFill: Color {
        if style == "glass" {
            return OC.cardBackground
        }
        if style == "minimal" {
            return Color.white.opacity(0.3)
        }
        if transparent {
            return Color.white.opacity(0.35)
        }
        return OC.cardBackground
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
    OmabarView()
        .environmentObject(OmanixViewModel())
        .frame(width: 1100, height: 760)
}