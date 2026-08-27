// ViewModels/OmanixViewModel.swift
// Omanix — the functionality layer bridging Data (OmanixStore) to Views.
// Owns all @Published UI state, instantiates the store, and exposes
// thin async operations. Views never touch the store directly.

import Foundation
import SwiftUI

@MainActor
final class OmanixViewModel: ObservableObject {

    // MARK: Published state (what views render)

    @Published var searchQuery = "" {
        didSet { scheduleSearch() }
    }
    @Published var searchResults: [PackageItem] = []
    @Published var declaredPackages: [PackageItem] = []
    @Published var installedCount = 0
    @Published var sourceCount = 0

    @Published var widgets: [WidgetItem] = []
    @Published var themes: [ThemeItem] = []
    @Published var currentTheme = "tokyo-night"

    @Published var isSearching = false
    @Published var isRebuilding = false
    @Published var needsRebuild = false
    @Published var rebuildLog: [String] = []
    @Published var brewIndexReady = false
    @Published var isIndexingBrew = false

    @Published var message: String?
    @Published var messageKind: MessageKind?

    enum MessageKind { case success, error }

    // MARK: Derived / system info

    var systemUser: String { NSUserName() }
    var systemHost: String {
        ProcessInfo.processInfo.hostName
    }
    var versionString: String {
        (try? String(contentsOfFile: NSHomeDirectory() + "/.omanix/version", encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "0.1.0"
    }

    // MARK: Dependencies

    private let store: OmanixStore
    private var searchTask: Task<Void, Never>?
    private var messageTimer: Task<Void, Never>?
    private var lastQuery = ""

    // MARK: Init

    init(store: OmanixStore = OmanixStore()) {
        self.store = store
        FileLogger.shared.rotate()
        FileLogger.shared.info("vm", "app launched")

        loadWidgets()
        loadThemes()
        refreshDeclared()
    }

    // MARK: - Installed

    func refreshDeclared() {
        Task {
            do {
                let items = try await store.declaredPackages()
                declaredPackages = items
                installedCount = items.count
                sourceCount = Set(items.map(\.source)).count
                brewIndexReady = store.brewIndexReady
            } catch {
                FileLogger.shared.error("vm", "refreshDeclared failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Search

    private func scheduleSearch() {
        searchTask?.cancel()
        let query = searchQuery

        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled, !query.isEmpty else { return }
            await performSearch(query)
        }
    }

    private func performSearch(_ query: String) async {
        guard query != lastQuery else { return }
        lastQuery = query
        isSearching = true
        searchResults = await store.search(query: query, declared: declaredPackages)
        isSearching = false
    }

    func refreshBrewIndex() {
        isIndexingBrew = true
        Task {
            await store.refreshBrewIndex()
            brewIndexReady = store.brewIndexReady
            isIndexingBrew = false
        }
    }

    // MARK: - Install / uninstall

    func install(_ package: PackageItem) async {
        do {
            try await store.addPackage(package)
            showMessage("Added \(package.name) to configuration", .success)
            needsRebuild = true
            markInstalled(package, installed: true)
        } catch {
            showMessage("Failed to install \(package.name): \(error.localizedDescription)", .error)
        }
    }

    func uninstall(_ package: PackageItem) async {
        do {
            try await store.removePackage(package)
            showMessage("Removed \(package.name)", .success)
            declaredPackages.removeAll { $0.name == package.name }
            installedCount = declaredPackages.count
            sourceCount = Set(declaredPackages.map(\.source)).count
            markInstalled(package, installed: false)
        } catch {
            showMessage("Failed to remove \(package.name): \(error.localizedDescription)", .error)
        }
    }

    private func markInstalled(_ package: PackageItem, installed: Bool) {
        if let i = searchResults.firstIndex(where: { $0.id == package.id }) {
            searchResults[i].isInstalled = installed
        }
    }

    // MARK: - System actions

    func rebuild() {
        isRebuilding = true
        needsRebuild = false
        rebuildLog = []
        Task {
            do {
                let lines = try await store.rebuild()
                rebuildLog = lines
                showMessage("System rebuilt successfully", .success)
            } catch {
                rebuildLog = []
                showMessage("Rebuild failed: \(error.localizedDescription)", .error)
            }
            isRebuilding = false
        }
    }

    func rollback() {
        Task {
            do {
                try await store.rollback()
                showMessage("Rolled back successfully", .success)
            } catch {
                showMessage("Rollback failed: \(error.localizedDescription)", .error)
            }
        }
    }

    func updateFlake() {
        Task {
            do {
                try await store.updateFlake()
                showMessage("Flake updated successfully", .success)
            } catch {
                showMessage("Update failed: \(error.localizedDescription)", .error)
            }
        }
    }

    // MARK: - Widgets

    func loadWidgets() {
        widgets = [
            WidgetItem(id: "store", name: "Omanix", icon: "bag", isEnabled: true),
            WidgetItem(id: "pomodoro", name: "Pomodoro Timer", icon: "timer", isEnabled: false),
            WidgetItem(id: "clock", name: "Clock", icon: "clock", isEnabled: false),
        ]
    }

    func toggleWidget(_ widget: WidgetItem) {
        guard let i = widgets.firstIndex(where: { $0.id == widget.id }) else { return }
        widgets[i].isEnabled.toggle()
        do {
            try store.setWidgetEnabled(widget.id, widgets[i].isEnabled)
            needsRebuild = true
        } catch {
            widgets[i].isEnabled.toggle()
            showMessage("Could not update widget: \(error.localizedDescription)", .error)
        }
    }

    // MARK: - Themes

    func loadThemes() {
        themes = [
            ThemeItem(id: "tokyo-night", name: "Tokyo Night", colors: [
                .background: OColor(red: 0.13, green: 0.13, blue: 0.17),
                .surface:    OColor(red: 0.18, green: 0.18, blue: 0.23),
                .accent:     OColor(red: 0.42, green: 0.44, blue: 0.95),
                .text:       OColor(red: 0.87, green: 0.87, blue: 0.93),
            ]),
            ThemeItem(id: "catppuccin", name: "Catppuccin Mocha", colors: [
                .background: OColor(red: 0.11, green: 0.11, blue: 0.15),
                .surface:    OColor(red: 0.15, green: 0.15, blue: 0.20),
                .accent:     OColor(red: 0.83, green: 0.53, blue: 0.76),
                .text:       OColor(red: 0.90, green: 0.90, blue: 0.95),
            ]),
        ]
        currentTheme = themes.first?.id ?? "tokyo-night"
    }

    func selectTheme(_ theme: ThemeItem) {
        currentTheme = theme.id
        do {
            try store.setTheme(theme.id)
            needsRebuild = true
            showMessage("Theme set to \(theme.name)", .success)
        } catch {
            showMessage("Could not set theme: \(error.localizedDescription)", .error)
        }
    }

    // MARK: - Messages

    private func showMessage(_ text: String, _ kind: MessageKind) {
        messageTimer?.cancel()
        message = text
        messageKind = kind
        messageTimer = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            message = nil
        }
    }
}
