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

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 8) {
            if let error = store.errorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(theme.error)
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(theme.error)
                    .lineLimit(1)
            } else if let success = store.successMessage {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(theme.success)
                Text(success)
                    .font(.system(size: 11))
                    .foregroundColor(theme.success)
            } else {
                Circle()
                    .fill(theme.tertiaryText.opacity(0.3))
                    .frame(width: 4, height: 4)
                Text("Select a theme, then rebuild to apply")
                    .font(.system(size: 11))
                    .foregroundColor(theme.tertiaryText)
            }

            Spacer()

            Button(action: { Task { await store.rebuild() } }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10))
                    Text("Rebuild")
                }
                .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(theme.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(theme.surface)
        .overlay(alignment: .top) {
            Divider().background(theme.border).opacity(0.5)
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
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 10, topTrailingRadius: 10))

                // Info section
                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(theme.name)
                                .font(.system(size: 13, weight: .medium))
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
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(appTheme.success)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(appTheme.success.opacity(0.08))
                            .cornerRadius(4)
                        }
                    }

                    // Mini terminal preview
                    miniPreview
                }
                .padding(12)
            }
            .background(appTheme.surface)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
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
        .cornerRadius(4)
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
