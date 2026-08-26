// modules/apps/store/Sources/ThemePickerView.swift
// Omanix — theme picker with live preview
import SwiftUI

struct ThemePickerView: View {
    @ObservedObject var store: StoreViewModel
    @Environment(\.omanixTheme) var theme

    var body: some View {
        VStack(spacing: 0) {
            header
            if store.themes.isEmpty {
                emptyState
            } else {
                content
            }
            StatusBarView(store: store, idleText: "Select a theme, then rebuild to apply") { EmptyView() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Themes")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.text)
                HStack(spacing: 4) {
                    Text("Current:")
                        .font(.system(size: 12))
                        .foregroundColor(theme.tertiaryText)
                    Text(store.currentTheme)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(theme.accent)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .background(theme.background)
        .overlay(alignment: .bottom) {
            Divider().background(theme.divider)
        }
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 300, maximum: 480), spacing: 14)
            ], spacing: 14) {
                ForEach(store.themes) { t in
                    ThemeCard(theme: t, isSelected: store.currentTheme == t.id) {
                        store.selectTheme(t)
                    }
                }
            }
            .padding(24)
        }
        .background(theme.background)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "paintbrush")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(theme.tertiaryText.opacity(0.4))
            VStack(spacing: 4) {
                Text("No themes available")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(theme.text)
                Text("Themes will appear here once configured")
                    .font(.system(size: 12))
                    .foregroundColor(theme.tertiaryText)
            }
            Spacer()
        }
    }
}

// MARK: - Theme Card

struct ThemeCard: View {
    let theme: ThemeItem
    let isSelected: Bool
    let onSelect: () -> Void
    @Environment(\.omanixTheme) var appTheme
    @State private var isHovered = false

    private let cardHeight: CGFloat = 140

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                // Color preview bar
                HStack(spacing: 0) {
                    colorBlock(theme.colors[.background] ?? .gray, label: "BG")
                    colorBlock(theme.colors[.surface] ?? .gray, label: "Surface")
                    colorBlock(theme.colors[.accent] ?? .gray, label: "Accent")
                    colorBlock(theme.colors[.text] ?? .gray, label: "Text")
                }
                .frame(height: cardHeight)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: UIConstants.cornerCard, topTrailingRadius: UIConstants.cornerCard))

                // Info section
                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(theme.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(appTheme.text)
                            Text(theme.id)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(appTheme.tertiaryText)
                        }
                        Spacer()
                        if isSelected {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                Text("Active")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(appTheme.success)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(appTheme.success.opacity(0.08))
                            .cornerRadius(UIConstants.cornerRow)
                        }
                    }

                    // Mini terminal preview
                    miniPreview
                }
                .padding(12)
            }
            .background(appTheme.surface)
            .cornerRadius(UIConstants.cornerCard)
            .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
            .overlay(
                RoundedRectangle(cornerRadius: UIConstants.cornerCard)
                    .stroke(
                        isSelected
                            ? appTheme.accent
                            : (isHovered ? appTheme.border : .clear),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private var miniPreview: some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                Circle().fill(Color.red.opacity(0.8)).frame(width: 6, height: 6)
                Circle().fill(Color.yellow.opacity(0.8)).frame(width: 6, height: 6)
                Circle().fill(Color.green.opacity(0.8)).frame(width: 6, height: 6)
            }
            .padding(.horizontal, 8)

            Text("$ omanix rebuild")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(theme.colors[.text] ?? .white)
                .padding(.horizontal, 6)

            Spacer()
        }
        .frame(height: 20)
        .background(theme.colors[.background] ?? .black)
        .cornerRadius(UIConstants.cornerRow)
    }

    func colorBlock(_ color: Color, label: String) -> some View {
        VStack {
            Spacer()
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(color)
    }
}

#Preview {
    ThemePickerView(store: StoreViewModel())
}
