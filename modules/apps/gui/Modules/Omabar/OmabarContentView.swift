// Modules/Omabar/OmabarContentView.swift
// SwiftUI content of the Omabar panel. Stateless — it renders whatever the
// OmabarModel publishes plus the settings struct handed down by the manager.

import SwiftUI

struct OmabarContentView: View {
    @ObservedObject var model: OmabarModel
    let settings: RuntimeSettings.Omabar
    var onAppleClick: () -> Void

    private let accent = Color(red: 0.04, green: 0.49, blue: 1.0)

    private var textColor: Color {
        if settings.colorScheme == "dark" { return .white }
        if settings.transparent && !settings.blur { return .black.opacity(0.85) }
        return .white
    }

    private var barHeight: CGFloat { max(24, CGFloat(settings.height)) }

    private var pillFont: Font {
        .custom("JetBrainsMono Nerd Font", size: 11.5)
    }

    private var bodyFont: Font {
        .custom("JetBrainsMono Nerd Font", size: 12)
    }

    var body: some View {
        HStack(spacing: 10) {
            // App launcher → Omanix store
            Button(action: onAppleClick) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(accent)
                    .frame(width: 26, height: 26)
                    .background(barTint.opacity(0.35), in: RoundedRectangle(cornerRadius: 7))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Workspace/app pills
            ForEach(model.visibleApps.prefix(8), id: \.name) { app in
                workspacePill(app)
            }

            // Chevron + focused app
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(textColor.opacity(0.5))

            HStack(spacing: 6) {
                Image(nsImage: model.frontAppIcon)
                    .resizable()
                    .frame(width: 14, height: 14)
                Text(model.frontAppName)
                    .font(bodyFont.weight(.medium))
            }
            .frame(minWidth: 0, maxWidth: nil, alignment: .leading)
            .lineLimit(1)

            Spacer(minLength: 8)

            // Right cluster
            if settings.showVolume {
                volumeItem
            }
            if settings.showWifi {
                wifiItem
            }
            if settings.showBattery {
                batteryItem
            }
            if settings.showClock {
                clockItem
            }
        }
        .font(bodyFont)
        .foregroundColor(textColor)
        .padding(.leading, 14)
        .padding(.trailing, 16)
        .frame(maxWidth: .infinity, minHeight: barHeight, alignment: .center)
        .background(barBackground)
        .clipShape(RoundedRectangle(cornerRadius: barCorner))
        .preferredColorScheme(settings.colorScheme == "auto" ? nil : (settings.colorScheme == "dark" ? .dark : .light))
    }

    // MARK: - Pills

    private func workspacePill(_ app: (name: String, isFocused: Bool)) -> some View {
        Text(monogram(app.name))
            .font(pillFont.weight(app.isFocused ? .bold : .medium))
            .foregroundColor(app.isFocused ? .white : textColor.opacity(0.92))
            .frame(width: 24, height: pillHeight)
            .background(app.isFocused ? accent : pillTint, in: RoundedRectangle(cornerRadius: pillCorner))
            .help(app.name)
    }

    private func monogram(_ name: String) -> String {
        guard let first = name.first else { return "·" }
        return String(first).uppercased()
    }

    private var pillHeight: CGFloat { max(20, barHeight - 10) }

    private var pillCorner: CGFloat {
        settings.style == "modern" || settings.style == "glass" ? 8 : 5
    }

    // MARK: - Items

    private var clockItem: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock")
                .font(.system(size: 11))
            Text(model.timeString)
                .font(bodyFont.weight(.semibold))
        }
        .foregroundColor(textColor)
        .padding(.leading, 10)
    }

    private var batteryItem: some View {
        HStack(spacing: 5) {
            if model.charging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
            } else {
                Image(systemName: batteryIcon)
                    .font(.system(size: 13))
            }
            Text(model.batteryText)
                .font(bodyFont)
        }
        .foregroundColor(textColor)
    }

    private var batteryIcon: String {
        let pct = model.batteryText.replacingOccurrences(of: "%", with: "")
        guard let v = Int(pct) else { return "battery.0" }
        if v >= 100 { return "battery.100" }
        if v >= 75 { return "battery.75" }
        if v >= 50 { return "battery.50" }
        if v >= 25 { return "battery.25" }
        return "battery.0"
    }

    private var volumeItem: some View {
        Button(action: { model.toggleMute() }) {
            HStack(spacing: 5) {
                Image(systemName: model.muted ? "speaker.slash.fill" : (model.volume <= 33 ? "speaker.wave.1.fill" : (model.volume <= 66 ? "speaker.wave.2.fill" : "speaker.wave.3.fill")))
                    .font(.system(size: 12))
                Text("\(model.volume)%")
                    .font(bodyFont)
            }
            .foregroundColor(model.muted ? textColor.opacity(0.55) : textColor)
            .contentShape(Rectangle())
            .help("Click to toggle mute")
        }
        .buttonStyle(.plain)
    }

    private var wifiItem: some View {
        HStack(spacing: 5) {
            Image(systemName: model.wifiName.isEmpty ? "wifi.slash" : "wifi")
                .font(.system(size: 12))
            if !model.wifiName.isEmpty {
                Text(model.wifiName)
                    .font(bodyFont)
            }
        }
        .foregroundColor(model.wifiName.isEmpty ? textColor.opacity(0.5) : textColor)
    }

    // MARK: - Background

    private var barTint: Color {
        settings.transparent ? Color.black.opacity(0.12) : Color.black.opacity(0.5)
    }

    private var pillTint: Color {
        Color.white.opacity(settings.style == "minimal" ? 0.0 : 0.16)
    }

    @ViewBuilder
    private var barBackground: some View {
        switch settings.style {
        case "glass":
            RoundedRectangle(cornerRadius: 13).fill(.ultraThinMaterial)
        case "minimal":
            Color.clear
        default:
            ZStack {
                RoundedRectangle(cornerRadius: 0)
                    .fill(settings.blur ? Color.black.opacity(settings.transparent ? 0.05 : 0.38) : Color.black.opacity(settings.transparent ? 0.05 : 0.82))
                if settings.blur {
                    RoundedRectangle(cornerRadius: 0).fill(.ultraThinMaterial).opacity(0.55)
                }
            }
        }
    }

    private var barCorner: CGFloat { settings.style == "glass" ? 13 : 0 }
}