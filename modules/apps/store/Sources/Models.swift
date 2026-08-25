// modules/apps/store/Sources/Models.swift
// Omanix Store — data models
import SwiftUI

struct PackageItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let description: String
    let source: PackageSource
    var isInstalled: Bool

    enum PackageSource: String, CaseIterable {
        case nixpkgs = "Nixpkgs"
        case nix = "Nix"
        case homebrewBrew = "Brew"
        case homebrewCask = "Cask"
        case custom = "Custom"

        var displayName: String {
            return rawValue
        }

        var badgeColor: Color {
            switch self {
            case .nixpkgs: return .blue
            case .nix: return .cyan
            case .homebrewBrew: return .orange
            case .homebrewCask: return .orange
            case .custom: return .purple
            }
        }
    }
}

struct WidgetItem: Identifiable {
    let id: String
    let name: String
    let icon: String
    var isEnabled: Bool
}

struct ThemeItem: Identifiable {
    let id: String
    let name: String
    let colors: [ColorRole: Color]

    enum ColorRole: String, CaseIterable {
        case background, surface, accent, text
    }
}
