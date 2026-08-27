// Views/ThemesView.swift
// "Themes" page: appearance picker grid with mini window previews.
// Appearance-only — not written to configuration.nix.

import SwiftUI

struct ThemesView: View {
    @State private var selectedID: UUID = ThemePreviewOption.all[0].id

    private let columns = [GridItem(.adaptive(minimum: 260, maximum: 300), spacing: 20)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    breadcrumb: "Appearance / Library",
                    title: "Themes",
                    subtitle: "Choose an appearance for your Omanix workspace"
                )

                LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                    ForEach(ThemePreviewOption.all) { theme in
                        ThemeCard(theme: theme, isSelected: selectedID == theme.id) {
                            selectedID = theme.id
                        }
                    }
                }
            }
            .padding(24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            StatusBar(left: "\(ThemePreviewOption.all.count) appearance themes available")
        }
    }
}

// MARK: - Local presentation type for the light appearance picker

struct ThemePreviewOption: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let mode: String
    let style: ThemePreviewStyle

    enum ThemePreviewStyle {
        case systemDefault, pureLight, highContrast, graphite, rose
    }

    static let all: [ThemePreviewOption] = [
        .init(name: "System Default", description: "Follows your device appearance", mode: "Automatic", style: .systemDefault),
        .init(name: "Pure Light", description: "Clean, bright, and spacious", mode: "Light", style: .pureLight),
        .init(name: "High Contrast", description: "Maximum clarity for every detail", mode: "Light", style: .highContrast),
        .init(name: "Graphite", description: "A calm, focused dark appearance", mode: "Dark", style: .graphite),
        .init(name: "Rose", description: "A warm accent for your workspace", mode: "Light", style: .rose),
    ]
}

private struct ThemeCard: View {
    let theme: ThemePreviewOption
    let isSelected: Bool
    var onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ThemePreview(style: theme.style)
                .frame(height: 176)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(OC.border, lineWidth: 1))

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(theme.name).font(.system(size: 15, weight: .bold)).foregroundColor(OC.textPrimary)
                    Text("\(theme.description) · \(theme.mode)")
                        .font(.system(size: 12))
                        .foregroundColor(OC.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button(action: onSelect) {
                    HStack(spacing: 4) {
                        if isSelected {
                            Image(systemName: "checkmark").font(.system(size: 11, weight: .bold))
                        }
                        Text(isSelected ? "Selected" : "Select")
                            .font(.system(size: 12.5, weight: .semibold))
                    }
                    .foregroundColor(isSelected ? .white : OC.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(isSelected ? OC.accentBlue : OC.subtleFill)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(OC.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: OMetrics.cardCorner)
                .stroke(isSelected ? OC.accentBlue : OC.border, lineWidth: isSelected ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: OMetrics.cardCorner))
    }
}

private struct ThemePreview: View {
    let style: ThemePreviewOption.ThemePreviewStyle

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                Circle().fill(Color(hex: "FF5F57")).frame(width: 7, height: 7)
                Circle().fill(Color(hex: "FEBC2E")).frame(width: 7, height: 7)
                Circle().fill(Color(hex: "28C840")).frame(width: 7, height: 7)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(titleBarColor)

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Capsule().fill(accentColor).frame(width: 46, height: 5)
                    Capsule().fill(sidebarLineColor).frame(width: 40, height: 5)
                    Capsule().fill(sidebarLineColor).frame(width: 40, height: 5)
                    Spacer()
                }
                .padding(10)
                .frame(width: 78, alignment: .topLeading)
                .frame(maxHeight: .infinity)
                .background(sidebarBackground)

                VStack(alignment: .leading, spacing: 8) {
                    Capsule().fill(contentLineColor).frame(height: 6)
                    Capsule().fill(contentLineColor).frame(width: 90, height: 6)
                    Spacer(minLength: 6)
                    Capsule().fill(accentBarColor).frame(width: 70, height: 8)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .frame(maxHeight: .infinity)
                .background(contentBackground)
            }
        }
    }

    private var titleBarColor: Color {
        switch style {
        case .highContrast, .graphite: return Color(hex: "0B0B0D")
        default: return Color(hex: "F5F5F6")
        }
    }
    private var sidebarBackground: Color {
        switch style {
        case .systemDefault, .pureLight: return Color(hex: "F2F2F4")
        case .highContrast: return Color.black
        case .graphite: return Color(hex: "1C1C1F")
        case .rose: return Color(hex: "FBE6EA")
        }
    }
    private var contentBackground: Color {
        switch style {
        case .systemDefault, .pureLight: return Color(hex: "FAFAFB")
        case .highContrast: return Color.white
        case .graphite: return Color(hex: "111113")
        case .rose: return Color(hex: "FFF4F6")
        }
    }
    private var sidebarLineColor: Color {
        switch style {
        case .highContrast, .graphite: return Color.white.opacity(0.3)
        default: return Color.black.opacity(0.15)
        }
    }
    private var contentLineColor: Color {
        switch style {
        case .highContrast: return Color.black.opacity(0.85)
        case .graphite: return Color.white.opacity(0.7)
        case .rose: return Color(hex: "C9738A")
        default: return Color.black.opacity(0.12)
        }
    }
    private var accentColor: Color {
        switch style {
        case .rose: return Color(hex: "B23A55")
        default: return OC.accentBlue
        }
    }
    private var accentBarColor: Color {
        switch style {
        case .highContrast: return Color(hex: "FBBF24")
        case .rose: return Color(hex: "8E1F3B")
        default: return OC.accentBlue
        }
    }
}
