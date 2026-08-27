// Data/Models.swift
// Omanix — pure data types shared across the store service, the view model,
// and the views. No SwiftUI types live here (colors are mapped in Theme.swift).

import Foundation

// MARK: - Package

/// A package as returned by the `omanix` CLI or the Homebrew/nixpkgs index.
struct PackageItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let description: String
    let source: PackageSource
    let version: String?
    var isInstalled: Bool

    init(
        name: String,
        description: String,
        source: PackageSource,
        version: String? = nil,
        isInstalled: Bool = false
    ) {
        self.name = name
        self.description = description
        self.source = source
        self.version = version
        self.isInstalled = isInstalled
    }
}

/// Where a package comes from. Mirrors `libexec/omanix-list-packages.sh`.
enum PackageSource: String, CaseIterable {
    case nixpkgs = "Nixpkgs"
    case nix = "Nix"
    case homebrewBrew = "Brew"
    case homebrewCask = "Cask"
    case custom = "Custom"

    var displayName: String { rawValue }

    /// Maps the `source` string emitted by `omanix list-packages`.
    init(cliValue: String) {
        switch cliValue {
        case "nixpkgs":       self = .nixpkgs
        case "nix":           self = .nix
        case "homebrew-brew": self = .homebrewBrew
        case "homebrew-cask": self = .homebrewCask
        case "custom":        self = .custom
        default:              self = .nixpkgs
        }
    }
}

// MARK: - Widget

struct WidgetItem: Identifiable {
    let id: String
    let name: String
    let icon: String
    var isEnabled: Bool
}

// MARK: - Theme

struct ThemeItem: Identifiable {
    let id: String
    let name: String
    let description: String
    let mode: String
    var colors: [ThemeColorRole: OColor]
}

enum ThemeColorRole: String, CaseIterable {
    case background, surface, accent, text, muted, selection, darkBackground
}

/// A small color wrapper so models don't have to import SwiftUI.
/// Views bridge this to `Color` via a `toColor()` helper.
struct OColor: Hashable {
    let red: Double
    let green: Double
    let blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    init(hex: String) {
        var hexValue = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexValue = hexValue.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexValue).scanHexInt64(&rgb)
        self.red   = Double((rgb & 0xFF0000) >> 16) / 255.0
        self.green = Double((rgb & 0x00FF00) >> 8) / 255.0
        self.blue  = Double(rgb & 0x0000FF) / 255.0
    }
}

// MARK: - Discover / Browse placeholders

struct DiscoverPackage: Identifiable {
    let id = UUID()
    let name: String
    let version: String?
    let description: String
    let iconSystemName: String
    let iconColor: OColor
    let installs: String?
}

struct SourceItem: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String
    let color: OColor
}

// MARK: - Navigation

/// The pages reachable from the sidebar.
enum SidebarItem: String, CaseIterable, Identifiable {
    case browse, installed, widgets, themes, settings
    var id: String { rawValue }

    var title: String {
        switch self {
        case .browse: return "Browse"
        case .installed: return "Installed"
        case .widgets: return "Widgets"
        case .themes: return "Themes"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .browse: return "square.grid.2x2"
        case .installed: return "checkmark.circle"
        case .widgets: return "archivebox"
        case .themes: return "tag"
        case .settings: return "gearshape"
        }
    }
}
