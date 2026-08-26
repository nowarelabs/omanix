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
            case .nixpkgs: return Color(red: 0.231, green: 0.510, blue: 0.965)
            case .nix: return Color(red: 0.160, green: 0.720, blue: 0.800)
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

    static func iconColor(for name: String, source: PackageItem.PackageSource) -> Color {
        // Use source brand color for default icon, specific colors for known apps
        let lower = name.lowercased()
        switch lower {
        case "google-chrome", "chromium": return Color(red: 0.34, green: 0.68, blue: 0.92)
        case "firefox": return Color(red: 0.96, green: 0.49, blue: 0.20)
        case "slack": return Color(red: 0.53, green: 0.24, blue: 0.63)
        case "discord": return Color(red: 0.35, green: 0.40, blue: 0.85)
        case "spotify": return Color(red: 0.12, green: 0.84, blue: 0.38)
        case "docker", "orbstack": return Color(red: 0.12, green: 0.56, blue: 0.90)
        case "github": return Color(red: 0.86, green: 0.86, blue: 0.88)
        case "postico": return Color(red: 0.35, green: 0.62, blue: 0.85)
        case "mongodb-compass": return Color(red: 0.14, green: 0.68, blue: 0.36)
        case "visual-studio-code", "vscode": return Color(red: 0.22, green: 0.47, blue: 0.86)
        case "sublime-text": return Color(red: 0.90, green: 0.50, blue: 0.18)
        case "figma": return Color(red: 0.63, green: 0.32, blue: 1.0)
        case "caffeine": return Color(red: 0.30, green: 0.78, blue: 0.38)
        case "zoom": return Color(red: 0.18, green: 0.52, blue: 1.0)
        default: return source.badgeColor
        }
    }
}

// MARK: - View Helpers

struct PackageIcon: View {
    let name: String
    let source: PackageItem.PackageSource
    let size: CGFloat
    @Environment(\.omanixTheme) var theme

    init(name: String, source: PackageItem.PackageSource, size: CGFloat = 28) {
        self.name = name
        self.source = source
        self.size = size
    }

    var body: some View {
        let iconSize = size * 0.5
        let iconColor = AppIcons.iconColor(for: name, source: source)
        Image(systemName: AppIcons.icon(for: name))
            .font(.system(size: iconSize, weight: .medium))
            .foregroundColor(iconColor)
            .frame(width: size, height: size)
            .background(iconColor.opacity(0.1))
            .cornerRadius(size * 0.22)
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
