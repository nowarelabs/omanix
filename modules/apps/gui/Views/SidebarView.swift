// SidebarView.swift
// Left navigation column: logo, library list, and pinned footer (Homebrew / sources).

import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarItem
    let installedCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Logo
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color.black)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                    )
                Text("Omanix")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(OC.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 22)

            Text("LIBRARY")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
                .foregroundColor(OC.textTertiary)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

            VStack(spacing: 2) {
                ForEach(SidebarItem.allCases) { item in
                    SidebarRow(
                        item: item,
                        isSelected: selection == item,
                        trailingCount: item == .installed ? installedCount : nil
                    ) {
                        selection = item
                    }
                }
            }
            .padding(.horizontal, 12)

            Spacer()

            VStack(alignment: .leading, spacing: 0) {
                Divider().overlay(OC.divider)
                FooterRow(icon: "bolt.fill", title: "3 sources", showChevron: false)
            }
        }
        .frame(width: OMetrics.sidebarWidth)
        .background(OC.sidebarBackground)
    }
}

private struct SidebarRow: View {
    let item: SidebarItem
    let isSelected: Bool
    let trailingCount: Int?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: item.icon)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 18)
                Text(item.title)
                    .font(.system(size: 13.5, weight: isSelected ? .semibold : .regular))
                Spacer()
                if let trailingCount {
                    Text("\(trailingCount)")
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .foregroundColor(isSelected ? .white : OC.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? OC.selectedFill : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

private struct FooterRow: View {
    let icon: String
    let title: String
    let showChevron: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(OC.textSecondary)
                .frame(width: 18)
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(OC.textSecondary)
            Spacer()
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(OC.textTertiary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}
