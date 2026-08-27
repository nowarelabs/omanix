// Theme.swift
// Color palette + shared visual constants, matched to the reference screenshots.

import SwiftUI

extension Color {
    init(hex: String) {
        var hexValue = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexValue = hexValue.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexValue).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

extension OColor {
    /// Bridge from the data-layer color (Foundation-only) into SwiftUI.
    var toColor: Color { Color(red: red, green: green, blue: blue) }
}

/// Maps a package source to its brand color and SF Symbol for list rows.
enum PackageSourceStyle {
    static func color(for source: PackageSource) -> Color {
        switch source {
        case .nixpkgs:      return OC.accentBlue
        case .nix:          return OC.cyan
        case .homebrewBrew: return OC.orange
        case .homebrewCask: return OC.amber
        case .custom:       return OC.purple
        }
    }

    static func icon(for source: PackageSource) -> String {
        switch source {
        case .nixpkgs:      return "flame"
        case .nix:          return "cube"
        case .homebrewBrew: return "mug"
        case .homebrewCask: return "archivebox"
        case .custom:       return "wrench.and.screwdriver"
        }
    }
}

/// Omanix Colors — the light appearance shown in the reference screenshots.
enum OC {
    static let titleBarBackground   = Color.white
    static let toolBarBackground    = Color(hex: "FAFAFB")
    static let sidebarBackground    = Color(hex: "F6F6F7")
    static let pageBackground       = Color(hex: "FBFBFC")
    static let cardBackground       = Color.white

    static let border               = Color(hex: "E6E6EA")
    static let divider              = Color(hex: "EDEDF0")

    static let textPrimary          = Color(hex: "1D1D1F")
    static let textSecondary        = Color(hex: "86868B")
    static let textTertiary         = Color(hex: "AEAEB4")

    static let accentBlue           = Color(hex: "0A7CFF")
    static let selectedFill         = Color(hex: "0A7CFF")
    static let lightBlueFill        = Color(hex: "EAF3FF")

    static let green                = Color(hex: "34C759")
    static let orange               = Color(hex: "F49D34")
    static let amber                = Color(hex: "E7B22E")
    static let purple               = Color(hex: "9E86E8")
    static let red                  = Color(hex: "FF3B30")
    static let cyan                 = Color(hex: "22B8CE")
    static let pink                 = Color(hex: "E8536F")

    static let subtleFill           = Color(hex: "F2F2F4")
}

enum OFont {
    static func mono(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

enum OMetrics {
    static let sidebarWidth: CGFloat = 260
    static let cardCorner: CGFloat = 12
    static let rowCorner: CGFloat = 8
    static let pillCorner: CGFloat = 999
}

/// A simple bordered card container matching the white rounded-rect cards
/// used throughout Settings / Sources / Widgets etc.
struct CardBox<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .background(OC.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: OMetrics.cardCorner)
                    .stroke(OC.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: OMetrics.cardCorner))
    }
}
