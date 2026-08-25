// modules/apps/store/Sources/ThemePickerView.swift
// Omanix Store — theme picker with live preview
import SwiftUI

struct ThemePickerView: View {
    @ObservedObject var store: StoreViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Theme Picker")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Select a theme for your desktop")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()

            // Theme grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 280, maximum: 400))
                ], spacing: 16) {
                    ForEach(store.themes) { theme in
                        ThemeCard(theme: theme, isSelected: store.currentTheme == theme.id) {
                            store.selectTheme(theme)
                        }
                    }
                }
                .padding()
            }

            // Status bar
            HStack {
                if let error = store.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                } else if let success = store.successMessage {
                    Label(success, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                } else {
                    Text("Current: \(store.currentTheme)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Rebuild System") {
                    Task { await store.rebuild() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()
            .background(.bar)
        }
    }
}

struct ThemeCard: View {
    let theme: ThemeItem
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                // Color preview
                HStack(spacing: 0) {
                    colorBlock(theme.colors[.background] ?? .gray, label: "BG")
                    colorBlock(theme.colors[.surface] ?? .gray, label: "Surface")
                    colorBlock(theme.colors[.accent] ?? .gray, label: "Accent")
                    colorBlock(theme.colors[.text] ?? .gray, label: "Text")
                }
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12))

                // Theme info
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(theme.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(theme.id)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                .padding()
            }
            .background(.quaternary.opacity(0.3))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    func colorBlock(_ color: Color, label: String) -> some View {
        VStack {
            Spacer()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .background(color)
    }
}

#Preview {
    ThemePickerView(store: StoreViewModel())
}
