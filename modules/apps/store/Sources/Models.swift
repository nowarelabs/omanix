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

        var displayName: String { rawValue }

        var icon: String {
            switch self {
            case .nixpkgs: return "flake"
            case .nix: return "cube.transparent"
            case .homebrewBrew: return "mug"
            case .homebrewCask: return "archivebox"
            case .custom: return "wrench.and.screwdriver"
            }
        }

        var badgeColor: Color {
            switch self {
            case .nixpkgs: return Color(red: 0.345, green: 0.596, blue: 0.878)
            case .nix: return Color(red: 0.220, green: 0.737, blue: 0.800)
            case .homebrewBrew: return Color(red: 0.933, green: 0.655, blue: 0.271)
            case .homebrewCask: return Color(red: 0.851, green: 0.545, blue: 0.235)
            case .custom: return Color(red: 0.678, green: 0.502, blue: 0.890)
            }
        }

        var sectionName: String {
            switch self {
            case .nixpkgs: return "Nixpkgs"
            case .nix: return "Nix (System)"
            case .homebrewBrew: return "Homebrew"
            case .homebrewCask: return "Homebrew Casks"
            case .custom: return "Custom Apps"
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
