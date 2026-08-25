// modules/apps/store/Sources/ThemePickerView.swift
// Omanix — theme picker with live preview
import SwiftUI

struct ThemePickerView: View {
    @ObservedObject var store: StoreViewModel
    @Environment(\.omanixTheme) var theme

    var body: some View {
        VStack(spacing: 0) {
            header
            content
            statusBar
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Themes")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(theme.text)
                HStack(spacing: 4) {
                    Text("Current:")
                        .font(.caption)
                        .foregroundColor(theme.tertiaryText)
                    Text(store.currentTheme)
                        .font(.system(.caption, weight: .semibold))
                        .foregroundColor(theme.accent)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 300, maximum: 480), spacing: 16)
            ], spacing: 16) {
                ForEach(store.themes) { t in
                    ThemeCard(theme: t, isSelected: store.currentTheme == t.id) {
                        store.selectTheme(t)
                    }
                }
            }
            .padding(20)
        }
        .background(theme.background)
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 8) {
            if let error = store.errorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(theme.error)
                Text(error)
                    .font(.caption)
                    .foregroundColor(theme.error)
                    .lineLimit(1)
            } else if let success = store.successMessage {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(theme.success)
                Text(success)
                    .font(.caption)
                    .foregroundColor(theme.success)
            } else {
                Circle()
                    .fill(theme.tertiaryText.opacity(0.4))
                    .frame(width: 4, height: 4)
                Text("Select a theme, then rebuild to apply")
                    .font(.caption)
                    .foregroundColor(theme.tertiaryText)
            }

            Spacer()

            Button(action: { Task { await store.rebuild() } }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11))
                    Text("Rebuild")
                }
                .font(.system(.caption, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(theme.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(theme.surface)
        .overlay(alignment: .top) {
            Divider().background(theme.border)
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

    private let cardHeight: CGFloat = 160

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
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14))

                // Info section
                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(theme.name)
                                .font(.system(.headline, weight: .semibold))
                                .foregroundColor(appTheme.text)
                            Text(theme.id)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(appTheme.tertiaryText)
                        }
                        Spacer()
                        if isSelected {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                Text("Active")
                                    .font(.system(.caption, weight: .medium))
                            }
                            .foregroundColor(appTheme.success)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(appTheme.success.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }

                    // Mini terminal preview
                    miniPreview
                }
                .padding(14)
            }
            .background(appTheme.surface)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected
                            ? appTheme.accent
                            : (isHovered ? appTheme.border : .clear),
                        lineWidth: isSelected ? 2 : 1
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

    // Mini terminal-style preview showing the theme colors
    private var miniPreview: some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                Circle().fill(Color.red.opacity(0.8)).frame(width: 7, height: 7)
                Circle().fill(Color.yellow.opacity(0.8)).frame(width: 7, height: 7)
                Circle().fill(Color.green.opacity(0.8)).frame(width: 7, height: 7)
            }
            .padding(.horizontal, 8)

            Text("$ omanix rebuild")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(theme.colors[.text] ?? .white)
                .padding(.horizontal, 6)

            Spacer()
        }
        .frame(height: 22)
        .background(theme.colors[.background] ?? .black)
        .cornerRadius(6)
    }

    func colorBlock(_ color: Color, label: String) -> some View {
        VStack {
            Spacer()
            Text(label)
                .font(.system(.caption2, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(color)
    }
}

#Preview {
    ThemePickerView(store: StoreViewModel())
}
