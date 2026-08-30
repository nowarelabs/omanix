// Views/ThemesView.swift
// "Themes" page: 12 Omanix themes (colors.toml) with live preview and Store wiring.
// Writes omanix.theme via OmanixStore.setTheme -> configuration.nix, rebuild to apply.

import SwiftUI

struct ThemesView: View {
    @EnvironmentObject private var vm: OmanixViewModel

    private let columns = [GridItem(.adaptive(minimum: 260, maximum: 300), spacing: 20)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    breadcrumb: "Appearance / Library",
                    title: "Themes",
                    subtitle: "Choose an appearance for your Omanix workspace — themes flow into Ghostty and the whole desktop"
                ) {
                    if vm.needsRebuild {
                        FilledButton(title: "Rebuild", icon: "wrench.and.screwdriver.fill") { vm.rebuild() }
                    } else {
                        BorderedButton(title: "\(vm.themes.count) themes", icon: "paintpalette")
                    }
                }

                LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                    ForEach(vm.themes) { theme in
                        ThemeCard(theme: theme, isSelected: vm.currentTheme == theme.id) {
                            vm.selectTheme(theme)
                        }
                    }
                }
            }
            .padding(24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            StatusBar(
                left: vm.needsRebuild ? "Theme change pending — rebuild to apply" : "\(vm.themes.count) themes · \(vm.currentTheme) active",
                rightText: vm.needsRebuild ? "Rebuild required" : "Omanix themes",
                rightDotColor: vm.needsRebuild ? OC.orange : OC.green
            )
        }
    }
}

private struct ThemeCard: View {
    let theme: ThemeItem
    let isSelected: Bool
    var onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ThemePreview(theme: theme)
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
                    Text(theme.id).font(OFont.mono(10)).foregroundColor(OC.textTertiary)
                }
                Spacer()
                Button(action: onSelect) {
                    HStack(spacing: 4) {
                        if isSelected { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)) }
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
    let theme: ThemeItem

    private func color(_ role: ThemeColorRole, fallback: Color) -> Color {
        theme.colors[role]?.toColor ?? fallback
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                Circle().fill(Color(hex: "FF5F57")).frame(width: 7, height: 7)
                Circle().fill(Color(hex: "FEBC2E")).frame(width: 7, height: 7)
                Circle().fill(Color(hex: "28C840")).frame(width: 7, height: 7)
                Spacer()
                Circle().fill(color(.accent, fallback: OC.accentBlue)).frame(width: 6, height: 6)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(color(.darkBackground, fallback: Color(hex: "1C1C1F")))

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Capsule().fill(color(.accent, fallback: OC.accentBlue)).frame(width: 46, height: 5)
                    Capsule().fill(color(.muted, fallback: Color.white.opacity(0.3))).frame(width: 40, height: 5)
                    Capsule().fill(color(.muted, fallback: Color.white.opacity(0.3))).frame(width: 40, height: 5)
                    Spacer()
                    Capsule().fill(color(.selection, fallback: Color.white.opacity(0.15))).frame(height: 14).overlay(
                        Text("bar").font(.system(size: 7, weight: .bold)).foregroundColor(color(.text, fallback: .white))
                    )
                }
                .padding(10)
                .frame(width: 78, alignment: .topLeading)
                .frame(maxHeight: .infinity)
                .background(color(.background, fallback: Color(hex: "1C1C1F")))

                VStack(alignment: .leading, spacing: 8) {
                    Capsule().fill(color(.text, fallback: Color.white.opacity(0.7))).frame(height: 6)
                    Capsule().fill(color(.text, fallback: Color.white.opacity(0.7)).opacity(0.6)).frame(width: 90, height: 6)
                    Capsule().fill(color(.muted, fallback: Color.gray)).frame(width: 70, height: 4)
                    Spacer(minLength: 6)
                    Capsule().fill(color(.accent, fallback: OC.accentBlue)).frame(width: 70, height: 8)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .frame(maxHeight: .infinity)
                .background(color(.surface, fallback: Color(hex: "111113")))
            }
        }
    }
}
