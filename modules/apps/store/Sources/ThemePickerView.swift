// modules/apps/store/Sources/ThemePickerView.swift
// Omanix — theme picker with live preview
import SwiftUI

struct ThemePickerView: View {
    @ObservedObject var store: StoreViewModel
    @Environment(\.omanixTheme) var theme

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Theme Picker")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.text)
                    Text("Select a theme for your desktop")
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                }
                Spacer()
            }
            .padding()

            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 280, maximum: 400))
                ], spacing: 16) {
                    ForEach(store.themes) { t in
                        ThemeCard(theme: t, isSelected: store.currentTheme == t.id) {
                            store.selectTheme(t)
                        }
                    }
                }
                .padding()
            }
            .background(theme.background)

            HStack {
                if let error = store.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                } else if let success = store.successMessage {
                    Label(success, systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                } else {
                    Text("Current: \(store.currentTheme)")
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                }
                Spacer()
                Button("Rebuild System") {
                    Task { await store.rebuild() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(theme.accent)
            }
            .padding()
            .background(theme.surface)
        }
    }
}

struct ThemeCard: View {
    let theme: ThemeItem
    let isSelected: Bool
    let onSelect: () -> Void
    @Environment(\.omanixTheme) var appTheme

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    colorBlock(theme.colors[.background] ?? .gray, label: "BG")
                    colorBlock(theme.colors[.surface] ?? .gray, label: "Surface")
                    colorBlock(theme.colors[.accent] ?? .gray, label: "Accent")
                    colorBlock(theme.colors[.text] ?? .gray, label: "Text")
                }
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12))

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(theme.name)
                            .font(.headline)
                            .foregroundColor(appTheme.text)
                        Text(theme.id)
                            .font(.caption)
                            .foregroundColor(appTheme.secondaryText)
                    }
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                .padding()
            }
            .background(appTheme.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? appTheme.accent : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    func colorBlock(_ color: Color, label: String) -> some View {
        VStack {
            Spacer()
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .background(color)
    }
}

#Preview {
    ThemePickerView(store: StoreViewModel())
}
