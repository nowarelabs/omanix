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

// MARK: - App Icon Mapping

struct AppIcons {
    static func icon(for name: String) -> String {
        let lower = name.lowercased()
        switch lower {
        // Browsers
        case "google-chrome", "chromium", "firefox", "safari", "arc", "brave-browser":
            return "globe"
        // Editors
        case "visual-studio-code", "vscode", "zed", "sublime-text", "neovim", "vim":
            return "chevron.left.forwardslash.chevron.right"
        // Terminals
        case "iterm2", "kitty", "alacritty", "wezterm", "ghostty":
            return "terminal"
        // Communication
        case "slack", "discord", "telegram", "whatsapp", "signal", "teams":
            return "bubble.left.and.bubble.right"
        // Media
        case "vlc", "iina", "mpv", "spotify", "obsidian":
            return "play.rectangle"
        // Dev tools
        case "docker", "orbstack", "postman", "github", "visual-studio":
            return "hammer"
        // Databases
        case "mongodb-compass", "postico", "dbvisualizer", "tableplus":
            return "cylinder"
        // Utils
        case "alfred", "raycast", "1password", "rectangle", "stats":
            return "square.grid.2x2"
        // Cloud
        case "aws", "gcloud", "azure":
            return "cloud"
        // Design
        case "figma", "sketch", "blender":
            return "paintbrush"
        // Default
        default:
            return "app"
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
