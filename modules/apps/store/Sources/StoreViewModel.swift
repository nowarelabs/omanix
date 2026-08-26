// modules/apps/store/Sources/StoreViewModel.swift
// Omanix Store — ViewModel for package management
import SwiftUI
import Foundation

@MainActor
class StoreViewModel: ObservableObject {
    @Published var packages: [PackageItem] = []
    @Published var installedPackages: Set<String> = []
    @Published var declaredPackages: [PackageItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var widgets: [WidgetItem] = []
    @Published var themes: [ThemeItem] = []
    @Published var currentTheme: String = "tokyo-night"
    @Published var isIndexingBrew = false
    @Published var brewIndexReady = false
    @Published var needsRebuild = false
    @Published var rebuildLog: [String] = []

    private let omanixDir: String
    private var searchTask: Task<Void, Never>?
    private var lastQuery: String = ""
    private var messageTimer: Task<Void, Never>?

    // In-memory brew index: (token/name, name array, description)
    private var brewCaskIndex: [(token: String, names: [String], desc: String)] = []
    private var brewFormulaIndex: [(name: String, desc: String)] = []
    private var brewIndexLoaded = false

    private var brewCacheDir: String {
        NSHomeDirectory() + "/.omanix-store/brew-index"
    }

    init() {
        self.omanixDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/omanix").path

        loadDeclaredPackages()
        loadWidgets()
        loadThemes()
    }

    // MARK: - Package Management

    func search(query: String) {
        guard query != lastQuery else { return }
        lastQuery = query

        searchTask?.cancel()

        guard !query.isEmpty else {
            packages = []
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await searchPackages(query: query)
        }
    }

    func searchPackages(query: String) async {
        isLoading = true
        errorMessage = nil

        var results: [PackageItem] = []
        let queryLower = query.lowercased()

        // 1. Filter declared packages (instant, local match)
        for pkg in declaredPackages {
            if pkg.name.lowercased().contains(queryLower) ||
               pkg.description.lowercased().contains(queryLower) {
                results.append(PackageItem(
                    name: pkg.name,
                    description: pkg.description.isEmpty ? pkg.source.displayName + " package" : pkg.description,
                    source: pkg.source,
                    isInstalled: true
                ))
            }
        }

        // 2. Search nixpkgs
        if let nixPath = await findExecutable("nix") {
            do {
                let json = try await runJSONCommand(
                    nixPath, ["search", "nixpkgs", query, "--json"],
                    timeout: 20.0
                )
                for (fullName, info) in json {
                    let name = extractNixPackageName(fullName)
                    if name.isEmpty { continue }
                    if results.contains(where: { $0.name == name }) { continue }
                    if let details = info as? [String: Any],
                       let description = details["description"] as? String {
                        results.append(PackageItem(
                            name: name,
                            description: description,
                            source: .nixpkgs,
                            isInstalled: installedPackages.contains(name)
                        ))
                    }
                }
            } catch {
                // Nix search failed — continue without nixpkgs results
                print("Nix search failed: \(error.localizedDescription)")
            }
        }

        // 3. Search Homebrew index (cached, instant)
        ensureBrewIndex()
        let brewCaskResults = brewCaskIndex.filter {
            $0.token.contains(queryLower) ||
            $0.names.contains(where: { $0.lowercased().contains(queryLower) }) ||
            $0.desc.lowercased().contains(queryLower)
        }
        for entry in brewCaskResults {
            if results.contains(where: { $0.name == entry.token }) { continue }
            results.append(PackageItem(
                name: entry.token,
                description: entry.desc.isEmpty ? "Homebrew cask" : entry.desc,
                source: .homebrewCask,
                isInstalled: installedPackages.contains(entry.token)
            ))
        }

        let brewFormulaResults = brewFormulaIndex.filter {
            $0.name.contains(queryLower) || $0.desc.lowercased().contains(queryLower)
        }
        for entry in brewFormulaResults {
            if results.contains(where: { $0.name == entry.name }) { continue }
            results.append(PackageItem(
                name: entry.name,
                description: entry.desc.isEmpty ? "Homebrew formula" : entry.desc,
                source: .homebrewBrew,
                isInstalled: installedPackages.contains(entry.name)
            ))
        }

        packages = results
        isLoading = false
    }

    // MARK: - Brew Index (cached to disk)

    func ensureBrewIndex() {
        guard !brewIndexLoaded else { return }
        brewIndexLoaded = true
        loadBrewIndexFromDisk()
        // Refresh if older than 7 days or doesn't exist
        if brewCaskIndex.isEmpty && brewFormulaIndex.isEmpty {
            Task { await downloadBrewIndex() }
        } else if isBrewIndexStale() {
            Task { await downloadBrewIndex() }
        }
    }

    func refreshBrewIndex() async {
        await downloadBrewIndex()
    }

    private func loadBrewIndexFromDisk() {
        let fm = FileManager.default

        // Load casks
        let caskPath = "\(brewCacheDir)/casks.json"
        if let data = fm.contents(atPath: caskPath),
           let entries = try? JSONDecoder().decode([BrewCask].self, from: data) {
            brewCaskIndex = entries.map { (token: $0.token, names: $0.name ?? [], desc: $0.desc ?? "") }
        }

        // Load formulas
        let formulaPath = "\(brewCacheDir)/formulas.json"
        if let data = fm.contents(atPath: formulaPath),
           let entries = try? JSONDecoder().decode([BrewFormula].self, from: data) {
            brewFormulaIndex = entries.map { (name: $0.name, desc: $0.desc ?? "") }
        }

        brewIndexReady = !brewCaskIndex.isEmpty || !brewFormulaIndex.isEmpty
    }

    private func isBrewIndexStale() -> Bool {
        let fm = FileManager.default
        let metaPath = "\(brewCacheDir)/last-updated"
        guard let data = fm.contents(atPath: metaPath),
              let str = String(data: data, encoding: .utf8),
              let timestamp = Double(str.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return true
        }
        let lastUpdate = Date(timeIntervalSince1970: timestamp)
        return Date().timeIntervalSince(lastUpdate) > 7 * 24 * 3600
    }

    private func downloadBrewIndex() async {
        isIndexingBrew = true
        let fm = FileManager.default
        try? fm.createDirectory(atPath: brewCacheDir, withIntermediateDirectories: true)

        let cacheDir = brewCacheDir
        await withTaskGroup(of: Void.self) { group in
            // Download casks
            group.addTask { [weak self] in
                guard let self else { return }
                guard let url = URL(string: "https://formulae.brew.sh/api/cask.json") else { return }
                guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
                try? data.write(to: URL(fileURLWithPath: "\(cacheDir)/casks.json"))
                if let entries = try? JSONDecoder().decode([BrewCask].self, from: data) {
                    await MainActor.run {
                        self.brewCaskIndex = entries.map { (token: $0.token, names: $0.name ?? [], desc: $0.desc ?? "") }
                    }
                }
            }

            // Download formulas
            group.addTask { [weak self] in
                guard let self else { return }
                guard let url = URL(string: "https://formulae.brew.sh/api/formula.json") else { return }
                guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
                try? data.write(to: URL(fileURLWithPath: "\(cacheDir)/formulas.json"))
                if let entries = try? JSONDecoder().decode([BrewFormula].self, from: data) {
                    await MainActor.run {
                        self.brewFormulaIndex = entries.map { (name: $0.name, desc: $0.desc ?? "") }
                    }
                }
            }
        }

        // Write timestamp
        let ts = "\(Date().timeIntervalSince1970)"
        try? ts.write(toFile: "\(brewCacheDir)/last-updated", atomically: true, encoding: .utf8)

        // Back on MainActor after await withTaskGroup — no MainActor.run needed
        self.isIndexingBrew = false
        self.brewIndexReady = !self.brewCaskIndex.isEmpty || !self.brewFormulaIndex.isEmpty
    }

    // MARK: - Search Helpers

    private func findExecutable(_ name: String) async -> String? {
        let task = Process()
        let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["which", name]
        task.environment = ProcessInfo.processInfo.environment.merging(
            ["PATH": processPATH]
        ) { _, new in new }
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        let dataTask = Task.detached { pipe.fileHandleForReading.readDataToEndOfFile() }
        try? task.run()
        while task.isRunning {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        guard task.terminationStatus == 0 else { return nil }
        let data = await dataTask.value
        let path = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (path?.isEmpty == true) ? nil : path
    }

    private func runJSONCommand(
        _ path: String, _ arguments: [String], timeout: TimeInterval
    ) async throws -> [String: Any] {
        let process = Process()
        let stdoutPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment.merging(
            ["PATH": processPATH]
        ) { _, new in new }
        process.standardOutput = stdoutPipe
        process.standardError = FileHandle.nullDevice

        let dataTask = Task.detached { stdoutPipe.fileHandleForReading.readDataToEndOfFile() }
        try process.run()

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        if process.isRunning {
            process.terminate()
            throw StoreError.commandFailed("nix search timed out")
        }

        let data = await dataTask.value
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw StoreError.invalidOutput
        }
        return json
    }

    private func extractNixPackageName(_ nixKey: String) -> String {
        let parts = nixKey.split(separator: ".")
        return parts.last.map(String.init) ?? nixKey
    }

    func installPackage(_ package: PackageItem) async {
        isLoading = true
        clearMessages()

        do {
            let command: [String]
            switch package.source {
            case .custom:
                command = ["omanix", "install-app", package.name]
            default:
                command = ["omanix", "add", package.name]
            }

            _ = try await runCommand(command[0], Array(command.dropFirst()))
            showMessage("Added \(package.name) to configuration", type: .success)

            installedPackages.insert(package.name)
            if let index = packages.firstIndex(where: { $0.id == package.id }) {
                packages[index].isInstalled = true
            }
            needsRebuild = true
        } catch {
            showMessage("Failed to install \(package.name): \(error.localizedDescription)", type: .error)
        }

        isLoading = false
    }

    func uninstallPackage(_ package: PackageItem) async {
        isLoading = true
        clearMessages()

        do {
            let command: [String]
            switch package.source {
            case .custom:
                command = ["omanix", "uninstall-app", package.name]
            default:
                command = ["omanix", "remove", package.name]
            }

            _ = try await runCommand(command[0], Array(command.dropFirst()))
            showMessage("Removed \(package.name)", type: .success)

            installedPackages.remove(package.name)
            if let index = packages.firstIndex(where: { $0.id == package.id }) {
                packages[index].isInstalled = false
            }
            declaredPackages.removeAll { $0.name == package.name }
        } catch {
            showMessage("Failed to remove \(package.name): \(error.localizedDescription)", type: .error)
        }

        isLoading = false
    }

    func rebuild() async {
        isLoading = true
        clearMessages()
        rebuildLog = ["Starting rebuild..."]

        do {
            let result = try await runCommand("omanix", ["rebuild"])

            // Stream output to log
            for line in result.components(separatedBy: "\n") where !line.isEmpty {
                rebuildLog.append(line)
            }

            showMessage("System rebuilt successfully", type: .success)
            needsRebuild = false
        } catch {
            let errorOutput = "\(error)"
            for line in errorOutput.components(separatedBy: "\n") where !line.isEmpty {
                rebuildLog.append(line)
            }
            showMessage("Rebuild failed", type: .error)
        }

        isLoading = false
    }

    func rollback() async {
        isLoading = true
        clearMessages()
        do {
            _ = try await runCommand("omanix", ["rebuild", "--rollback"])
            showMessage("Rolled back successfully", type: .success)
        } catch {
            showMessage("Rollback failed: \(error.localizedDescription)", type: .error)
        }
        isLoading = false
    }

    func updateFlake() async {
        isLoading = true
        clearMessages()
        do {
            _ = try await runCommand("omanix", ["update"])
            showMessage("Flake updated successfully", type: .success)
        } catch {
            showMessage("Update failed: \(error.localizedDescription)", type: .error)
        }
        isLoading = false
    }

    // MARK: - Messages

    private enum MessageType { case success, error }

    private func showMessage(_ text: String, type: MessageType) {
        messageTimer?.cancel()
        switch type {
        case .success: successMessage = text; errorMessage = nil
        case .error: errorMessage = text; successMessage = nil
        }
        messageTimer = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            clearMessages()
        }
    }

    private func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }

    // MARK: - Widget Management
    // NOTE: When adding new widgets, add them here AND in modules/widgets/options.nix
    func loadWidgets() {
        widgets = [
            WidgetItem(id: "store", name: "Omanix", icon: "bag", isEnabled: true),
            WidgetItem(id: "pomodoro", name: "Pomodoro Timer", icon: "timer", isEnabled: false),
            WidgetItem(id: "clock", name: "Clock", icon: "clock", isEnabled: false),
        ]
    }

    func toggleWidget(_ widget: WidgetItem) async {
        guard let index = widgets.firstIndex(where: { $0.id == widget.id }) else { return }

        widgets[index].isEnabled.toggle()

        let configPath = "\(omanixDir)/configuration.nix"
        guard var config = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            showMessage("Could not read configuration.nix", type: .error)
            return
        }

        let option = "omanix.widgets.\(widget.id).enable"
        let newValue = widgets[index].isEnabled ? "true" : "false"

        if config.contains(option) {
            config = config.replacingOccurrences(
                of: "\(option) = .*;",
                with: "\(option) = \(newValue);",
                options: .regularExpression
            )
        } else {
            config += "\n  \(option) = \(newValue);"
        }

        try? config.write(toFile: configPath, atomically: true, encoding: .utf8)
    }

    // MARK: - Theme Management
    // NOTE: When adding new themes, add them here AND in themes/ directory
    func loadThemes() {
        themes = [
            ThemeItem(id: "tokyo-night", name: "Tokyo Night", colors: [
                .background: Color(red: 0.13, green: 0.13, blue: 0.17),
                .surface: Color(red: 0.18, green: 0.18, blue: 0.23),
                .accent: Color(red: 0.42, green: 0.44, blue: 0.95),
                .text: Color(red: 0.87, green: 0.87, blue: 0.93),
            ]),
            ThemeItem(id: "catppuccin", name: "Catppuccin Mocha", colors: [
                .background: Color(red: 0.11, green: 0.11, blue: 0.15),
                .surface: Color(red: 0.15, green: 0.15, blue: 0.20),
                .accent: Color(red: 0.83, green: 0.53, blue: 0.76),
                .text: Color(red: 0.90, green: 0.90, blue: 0.95),
            ]),
        ]
    }

    func selectTheme(_ theme: ThemeItem) {
        currentTheme = theme.id

        let configPath = "\(omanixDir)/configuration.nix"
        guard var config = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            showMessage("Could not read configuration.nix", type: .error)
            return
        }

        if config.contains("omanix.theme") {
            config = config.replacingOccurrences(
                of: "omanix\\.theme = \".*\";",
                with: "omanix.theme = \"\(theme.id)\";",
                options: .regularExpression
            )
        } else {
            config += "\n  omanix.theme = \"\(theme.id)\";"
        }

        try? config.write(toFile: configPath, atomically: true, encoding: .utf8)
        showMessage("Theme set to \(theme.name)", type: .success)
    }

    // MARK: - Installed Packages

    func loadDeclaredPackages() {
        Task {
            do {
                print("[omanix] loadDeclaredPackages: calling omanix list-packages")
                let output = try await runCommand("omanix", ["list-packages"])
                print("[omanix] loadDeclaredPackages: got \(output.count) chars, first 200: \(String(output.prefix(200)))")

                guard let data = output.data(using: .utf8) else {
                    print("[omanix] loadDeclaredPackages: FAILED to convert output to UTF8 data")
                    return
                }

                guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                    print("[omanix] loadDeclaredPackages: FAILED to parse JSON. Raw: \(String(output.prefix(500)))")
                    return
                }

                print("[omanix] loadDeclaredPackages: parsed \(json.count) entries")

                var items: [PackageItem] = []
                var names: Set<String> = []

                for entry in json {
                    guard let sourceStr = entry["source"] as? String,
                          let name = entry["name"] as? String else { continue }

                    let source: PackageItem.PackageSource
                    switch sourceStr {
                    case "nixpkgs": source = .nixpkgs
                    case "nix": source = .nix
                    case "homebrew-brew": source = .homebrewBrew
                    case "homebrew-cask": source = .homebrewCask
                    case "custom": source = .custom
                    default: source = .nixpkgs
                    }

                    let description = entry["description"] as? String ?? ""

                    items.append(PackageItem(
                        name: name,
                        description: description,
                        source: source,
                        isInstalled: true
                    ))
                    names.insert(name)
                }

                items.sort { a, b in
                    if a.source.rawValue != b.source.rawValue {
                        return a.source.rawValue < b.source.rawValue
                    }
                    return a.name < b.name
                }

                print("[omanix] loadDeclaredPackages: setting \(items.count) declaredPackages, \(names.count) installedPackages")
                declaredPackages = items
                installedPackages = names
            } catch {
                print("[omanix] loadDeclaredPackages FAILED: \(error.localizedDescription)")
            }
        }
    }

    func loadInstalledPackages() {
        loadDeclaredPackages()
    }

    // MARK: - Process Helpers

    /// Minimal PATH that includes nix, homebrew, and system tool locations.
    /// GUI apps don't inherit the terminal's PATH, so we set it explicitly.
    private var processPATH: String {
        let nixProfile = "/nix/var/nix/profiles/default/bin"
        let homebrew = "/opt/homebrew/bin"
        let systemSw = "/run/current-system/sw/bin"
        let nixHome = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".nix-profile/bin").path
        let userLocal = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/bin").path
        let systemPaths = "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin"
        return "\(userLocal):\(nixProfile):\(nixHome):\(homebrew):\(systemSw):\(systemPaths)"
    }

    private func runCommand(_ command: String, _ arguments: [String]) async throws -> String {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + arguments
        let env = ProcessInfo.processInfo.environment.merging(
            ["PATH": processPATH]
        ) { _, new in new }
        process.environment = env
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        print("[omanix] runCommand: \(command) \(arguments.joined(separator: " "))")
        print("[omanix] runCommand: PATH=\(env["PATH"] ?? "nil")")

        // Read pipe data concurrently to prevent deadlocks on large output
        let stdoutData = Task.detached { stdoutPipe.fileHandleForReading.readDataToEndOfFile() }
        let stderrData = Task.detached { stderrPipe.fileHandleForReading.readDataToEndOfFile() }

        try process.run()

        while process.isRunning {
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        let data = await stdoutData.value
        let errData = await stderrData.value
        let errStr = String(data: errData, encoding: .utf8) ?? ""
        guard let output = String(data: data, encoding: .utf8) else {
            print("[omanix] runCommand: FAILED to convert stdout to string (\(data.count) bytes)")
            throw StoreError.invalidOutput
        }

        print("[omanix] runCommand: exit=\(process.terminationStatus), stdout=\(output.count) bytes, stderr=\(errStr.count) bytes")
        if !errStr.isEmpty {
            print("[omanix] runCommand: stderr=\(String(errStr.prefix(300)))")
        }

        guard process.terminationStatus == 0 else {
            throw StoreError.commandFailed(errStr.isEmpty ? output : errStr)
        }

        return output
    }

    private func runCommandWithTimeout(
        _ path: String, _ arguments: [String], timeout: TimeInterval
    ) async throws -> String {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment.merging(
            ["PATH": processPATH]
        ) { _, new in new }
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let stdoutData = Task.detached { stdoutPipe.fileHandleForReading.readDataToEndOfFile() }
        let stderrData = Task.detached { stderrPipe.fileHandleForReading.readDataToEndOfFile() }

        try process.run()

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        if process.isRunning {
            process.terminate()
            throw StoreError.commandFailed("Command timed out after \(Int(timeout))s")
        }

        let data = await stdoutData.value
        guard let output = String(data: data, encoding: .utf8) else {
            throw StoreError.invalidOutput
        }

        guard process.terminationStatus == 0 else {
            let errData = await stderrData.value
            let errStr = String(data: errData, encoding: .utf8) ?? ""
            throw StoreError.commandFailed(errStr.isEmpty ? output : errStr)
        }

        return output
    }
}

// MARK: - Brew Index Codable Types

private struct BrewCask: Codable {
    let token: String
    let name: [String]?
    let desc: String?
}

private struct BrewFormula: Codable {
    let name: String
    let desc: String?
}

// MARK: - Errors

enum StoreError: LocalizedError {
    case invalidOutput
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidOutput:
            return "Invalid command output"
        case .commandFailed(let output):
            return "Command failed: \(output)"
        }
    }
}
