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
            case .nixpkgs: return Color(red: 0.522, green: 0.686, blue: 0.980)  // #85AEFA
            case .nix: return Color(red: 0.133, green: 0.827, blue: 0.933)      // #22D3EE
            case .homebrewBrew: return Color(red: 0.957, green: 0.620, blue: 0.204) // #F49D34
            case .homebrewCask: return Color(red: 0.906, green: 0.698, blue: 0.180) // #E7B22E
            case .custom: return Color(red: 0.620, green: 0.525, blue: 0.910)    // #9E86E8
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
        // Strip version suffixes for matching (e.g. "postgresql-16.13" → "postgresql")
        let base = lower.replacingOccurrences(of: #"-[\d.]+$"#, with: "", options: .regularExpression)

        switch base {
        // Browsers
        case "google-chrome", "chromium", "firefox", "safari", "arc", "brave-browser":
            return "globe"
        // Editors
        case "visual-studio-code", "vscode", "zed", "sublime-text", "vim", "helix":
            return "chevron.left.forwardslash.chevron.right"
        // Terminals
        case "iterm2", "kitty", "alacritty", "wezterm", "ghostty", "foot", "warp", "neovim":
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
        case "mongodb-compass", "postico", "dbvisualizer", "tableplus",
             "postgresql", "redis", "mysql", "sqlite", "clickhouse", "mariadb", "influxdb":
            return "cylinder"
        // Languages / Runtimes
        case "python3", "python", "ruby", "rustc-wrapper", "rustc", "cargo", "go", "node",
             "nodejs", "deno", "bun", "perl", "lua", "julia", "r":
            return "chevron.left.forwardslash.chevron.right"
        // CLI Utilities
        case "tree", "subversion", "starship", "sketchybar", "turso-cli", "gh", "git",
             "curl", "wget", "ripgrep", "fd", "fzf", "bat", "eza", "zoxide", "tmux",
             "jq", "yq", "htop", "btop", "glow", "tldr", "asdf",
             "mise", "volta", "nvm", "pyenv", "rbenv", "goenv", "direnv",
             "mas", "brew", "nix", "darwin-rebuild":
            return "terminal"
        // Cloud / Infrastructure
        case "aws", "gcloud", "azure", "terraform", "ansible", "vagrant":
            return "cloud"
        // Design
        case "figma", "sketch", "blender":
            return "paintbrush"
        // Utils
        case "alfred", "raycast", "1password", "rectangle", "stats", "caffeine":
            return "square.grid.2x2"
        // Services / Daemons
        case "aeropace", "aerospace", "skhd", "yabai", "jankyborders", "dozer":
            return "sidebar.left"
        default:
            return "app"
        }
    }

    static func iconColor(for name: String, source: PackageItem.PackageSource) -> Color {
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

    /// Stable color derived from the package name (for letter-avatar chips).
    static func hashColor(for name: String) -> Color {
        let hash = abs(name.hashValue)
        let r = Double((hash >> 16) & 0xFF) / 255.0
        let g = Double((hash >> 8) & 0xFF) / 255.0
        let b = Double(hash & 0xFF) / 255.0
        // Desaturate slightly so it doesn't clash
        let avg = (r + g + b) / 3.0
        let mix = 0.35
        return Color(
            red: r * (1 - mix) + avg * mix,
            green: g * (1 - mix) + avg * mix,
            blue: b * (1 - mix) + avg * mix
        )
    }

    /// First 1–2 character(s) of the package name for the letter avatar.
    static func initials(for name: String) -> String {
        let clean = name
            .replacingOccurrences(of: #"-[\d.]+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "-", with: " ")
        let words = clean.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        }
        return String(clean.prefix(2)).uppercased()
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
        let iconName = AppIcons.icon(for: name)
        let isFallback = iconName == "app"

        if isFallback {
            // Letter avatar for unknown packages
            let color = AppIcons.hashColor(for: name)
            let letter = AppIcons.initials(for: name)
            Text(letter)
                .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .frame(width: size, height: size)
                .background(color.opacity(0.12))
                .cornerRadius(size * 0.22)
        } else {
            let iconSize = size * 0.5
            let iconColor = AppIcons.iconColor(for: name, source: source)
            Image(systemName: iconName)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: size, height: size)
                .background(iconColor.opacity(0.1))
                .cornerRadius(size * 0.22)
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
