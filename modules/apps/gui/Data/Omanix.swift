// Data/Omanix.swift
// Omanix — the data/service layer. Wraps the `omanix` CLI and the on-disk
// Homebrew index. Foundation ONLY — no SwiftUI. All methods run the `omanix`
// command and return plain values; the view model layers state on top.

import Foundation

enum OmanixError: LocalizedError {
    case invalidOutput
    case commandFailed(String)
    case timedOut(String)

    var errorDescription: String? {
        switch self {
        case .invalidOutput: return "Invalid command output"
        case .commandFailed(let output): return "Command failed: \(output)"
        case .timedOut(let cmd): return "\(cmd) timed out"
        }
    }
}

/// The single place that talks to the `omanix` CLI and reads/writes files
/// under `~/.omanix`. Create one instance and share it.
final class Omanix {

    private let omanixDir: String
    private var brewCacheDir: String { "\(omanixDir)/brew-index" }

    // In-memory brew index, backed by 7-day disk cache.
    private var brewCaskIndex: [(token: String, names: [String], desc: String)] = []
    private var brewFormulaIndex: [(name: String, desc: String)] = []
    private var brewIndexLoaded = false

    // MARK: - Init

    init(omanixDir: String = NSHomeDirectory() + "/.omanix") {
        self.omanixDir = omanixDir
    }

    var configPath: String { "\(omanixDir)/configuration.nix" }
    /// Machine-produced option values written by `omanix state set`. configuration.nix
    /// imports this file; the GUI reads it for current values, never editing config.nix.
    var stateFilePath: String { "\(omanixDir)/state.nix" }

    // MARK: - Installed (declared) packages

    /// Reads `omanix list-packages` and returns the declared set (deduped).
    func declaredPackages() async throws -> [PackageItem] {
        let output = try await runCommand("omanix", ["list-packages"])
        guard let data = output.data(using: .utf8) else { throw OmanixError.invalidOutput }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            FileLogger.shared.error("store", "failed to parse list-packages JSON")
            throw OmanixError.invalidOutput
        }

        var items: [PackageItem] = []
        var seen: Set<String> = []

        for entry in json {
            guard let sourceStr = entry["source"] as? String,
                  let name = entry["name"] as? String else { continue }

            let source = PackageSource(cliValue: sourceStr)
            let key = "\(name)|\(source.rawValue)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)

            items.append(PackageItem(
                name: name,
                description: entry["description"] as? String ?? "",
                source: source,
                isInstalled: true
            ))
        }

        items.sort { a, b in
            if a.source.rawValue != b.source.rawValue { return a.source.rawValue < b.source.rawValue }
            return a.name < b.name
        }

        FileLogger.shared.info("store", "loaded \(items.count) declared packages (\(seen.count) unique)")
        return items
    }

    // MARK: - Install / uninstall

    func addPackage(_ package: PackageItem) async throws {
        let command: [String]
        switch package.source {
        case .custom: command = ["install-app", package.name]
        default:      command = ["add", package.name]
        }
        _ = try await runCommand("omanix", command)
        FileLogger.shared.info("store", "added \(package.name)")
    }

    func removePackage(_ package: PackageItem) async throws {
        let command: [String]
        switch package.source {
        case .custom: command = ["uninstall-app", package.name]
        default:      command = ["remove", package.name]
        }
        _ = try await runCommand("omanix", command)
        FileLogger.shared.info("store", "removed \(package.name)")
    }

    // MARK: - System actions

    func rebuild() async throws -> [String] {
        let output = try await runCommand("omanix", ["rebuild"])
        return output.components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    func rollback() async throws {
        _ = try await runCommand("omanix", ["rebuild", "--rollback"])
    }

    func updateFlake() async throws {
        _ = try await runCommand("omanix", ["update"])
    }

    // MARK: - Search

    /// Debounced at the view-model layer; this performs the actual search.
    /// Returns matches from declared packages, nixpkgs, and Homebrew.
    func search(query: String, declared: [PackageItem]) async -> [PackageItem] {
        var results: [PackageItem] = []
        let q = query.lowercased()

        // 1. Declared (instant, local)
        for pkg in declared {
            if pkg.name.lowercased().contains(q) || pkg.description.lowercased().contains(q) {
                results.append(PackageItem(
                    name: pkg.name,
                    description: pkg.description,
                    source: pkg.source,
                    isInstalled: true
                ))
            }
        }

        // 2. nixpkgs via `nix search`
        if let nixPath = await findExecutable("nix") {
            do {
                let json = try await runJSONCommand(
                    nixPath, ["search", "nixpkgs", query, "--json"], timeout: 20
                )
                for (fullName, info) in json {
                    let name = extractNixName(fullName)
                    if name.isEmpty || results.contains(where: { $0.name == name }) { continue }
                    if let details = info as? [String: Any],
                       let description = details["description"] as? String {
                        results.append(PackageItem(
                            name: name,
                            description: description,
                            source: .nixpkgs,
                            isInstalled: declared.contains { $0.name == name }
                        ))
                    }
                }
            } catch {
                FileLogger.shared.warn("store", "nix search skipped: \(error.localizedDescription)")
            }
        }

        // 3. Homebrew (cached index)
        ensureBrewIndex()
        for entry in brewCaskIndex
        where entry.token.contains(q) ||
              (entry.names.contains { $0.lowercased().contains(q) }) ||
              entry.desc.lowercased().contains(q) {
            guard !results.contains(where: { $0.name == entry.token }) else { continue }
            results.append(PackageItem(
                name: entry.token,
                description: entry.desc.isEmpty ? "Homebrew cask" : entry.desc,
                source: .homebrewCask,
                isInstalled: declared.contains { $0.name == entry.token }
            ))
        }

        for entry in brewFormulaIndex
        where entry.name.contains(q) || entry.desc.lowercased().contains(q) {
            guard !results.contains(where: { $0.name == entry.name }) else { continue }
            results.append(PackageItem(
                name: entry.name,
                description: entry.desc.isEmpty ? "Homebrew formula" : entry.desc,
                source: .homebrewBrew,
                isInstalled: declared.contains { $0.name == entry.name }
            ))
        }

        return results
    }

    // MARK: - Brew index (disk-cached)

    /// Loads the cached index, kicking off a background refresh if stale/missing.
    func ensureBrewIndex() {
        guard !brewIndexLoaded else { return }
        brewIndexLoaded = true
        loadedBrewIndexFromDisk()
        if (brewCaskIndex.isEmpty && brewFormulaIndex.isEmpty) || isBrewIndexStale() {
            Task { await refreshBrewIndex() }
        }
    }

    func refreshBrewIndex() async {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: brewCacheDir, withIntermediateDirectories: true)
        let cacheDir = brewCacheDir

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                guard let url = URL(string: "https://formulae.brew.sh/api/cask.json"),
                      let (data, _) = try? await URLSession.shared.data(from: url) else { return }
                try? data.write(to: URL(fileURLWithPath: "\(cacheDir)/casks.json"))
            }
            group.addTask {
                guard let url = URL(string: "https://formulae.brew.sh/api/formula.json"),
                      let (data, _) = try? await URLSession.shared.data(from: url) else { return }
                try? data.write(to: URL(fileURLWithPath: "\(cacheDir)/formulas.json"))
            }
        }

        let ts = "\(Date().timeIntervalSince1970)"
        try? ts.write(toFile: "\(brewCacheDir)/last-updated", atomically: true, encoding: .utf8)
        loadedBrewIndexFromDisk()
    }

    private func loadedBrewIndexFromDisk() {
        let fm = FileManager.default

        if let data = fm.contents(atPath: "\(brewCacheDir)/casks.json"),
           let entries = try? JSONDecoder().decode([BrewCask].self, from: data) {
            brewCaskIndex = entries.map { (token: $0.token, names: $0.name ?? [], desc: $0.desc ?? "") }
        }
        if let data = fm.contents(atPath: "\(brewCacheDir)/formulas.json"),
           let entries = try? JSONDecoder().decode([BrewFormula].self, from: data) {
            brewFormulaIndex = entries.map { (name: $0.name, desc: $0.desc ?? "") }
        }

        brewIndexReady = !brewCaskIndex.isEmpty || !brewFormulaIndex.isEmpty
    }

    private(set) var brewIndexReady = false

    private func isBrewIndexStale() -> Bool {
        let fm = FileManager.default
        guard let data = fm.contents(atPath: "\(brewCacheDir)/last-updated"),
              let str = String(data: data, encoding: .utf8),
              let timestamp = Double(str.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return true
        }
        let last = Date(timeIntervalSince1970: timestamp)
        return Date().timeIntervalSince(last) > 7 * 24 * 3600
    }

    // MARK: - Configuration edits (via `omanix state set` — Nix-owned mutation)

    /// Writes a validated option through the `omanix state set` CLI. The CLI owns the
    /// schema + type checking and writes only the generated state.nix — never
    /// configuration.nix — so the GUI performs no free-form Nix text surgery.
    private func setState(_ option: String, _ value: String) throws {
        let path = findOmanixBinary()
        let output = runSync([path, "state", "set", option, value])
        guard output.terminationStatus == 0 else {
            throw OmanixError.commandFailed(output.stderr.isEmpty ? output.stdout : output.stderr)
        }
    }

    func setWidgetEnabled(_ id: String, _ enabled: Bool) throws {
        try setState("omanix.widgets.\(id).enable", enabled ? "true" : "false")
    }

    func setTheme(_ id: String) throws {
        try setState("omanix.theme", id)
    }

    func currentThemeId() -> String {
        // 1. Try ~/.config/omanix/theme.json (written by modules/theme/theme.nix)
        let themeJSON = NSHomeDirectory() + "/.config/omanix/theme.json"
        if let data = FileManager.default.contents(atPath: themeJSON),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let name = obj["name"] as? String { return name }
        // 2. Fallback: state.nix (machine-written) then configuration.nix (human-written)
        if let name = readOption("omanix.theme") { return name }
        return "tokyo-night"
    }

    func setOmabarOption(_ key: String, _ value: String) throws {
        try setState("omanix.omabar.\(key)", value)
    }

    func setOmabarEnabled(_ v: Bool) throws { try setOmabarOption("enable", v ? "true" : "false") }
    func setOmabarShowClock(_ v: Bool) throws { try setOmabarOption("showClock", v ? "true" : "false") }
    func setOmabarShowBattery(_ v: Bool) throws { try setOmabarOption("showBattery", v ? "true" : "false") }
    func setOmabarShowVolume(_ v: Bool) throws { try setOmabarOption("showVolume", v ? "true" : "false") }
    func setOmabarShowVolumeText(_ v: Bool) throws { try setOmabarOption("showVolumeText", v ? "true" : "false") }
    func setOmabarShowWifi(_ v: Bool) throws { try setOmabarOption("showWifi", v ? "true" : "false") }
    func setOmabarShowApps(_ v: Bool) throws { try setOmabarOption("showApps", v ? "true" : "false") }

    func setOmabarAutoHide(_ v: Bool) throws { try setOmabarOption("autoHide", v ? "true" : "false") }
    func setOmabarShowDate(_ v: Bool) throws { try setOmabarOption("showDate", v ? "true" : "false") }
    func setOmabarShowBatteryPercent(_ v: Bool) throws { try setOmabarOption("showBatteryPercent", v ? "true" : "false") }
    func setOmabarUse24Hour(_ v: Bool) throws { try setOmabarOption("use24Hour", v ? "true" : "false") }
    func setOmabarClockFormat(_ v: String) throws { try setOmabarOption("clockFormat", v) }

    // MARK: - Structured components (Phase 3: components.<name>.* overrides flat show*)

    func setComponentOption(_ component: String, _ key: String, _ value: String) throws {
        try setState("omanix.omabar.components.\(component).\(key)", value)
    }

    func setComponentEnabled(_ component: String, _ enabled: Bool) throws {
        try setComponentOption(component, "enable", enabled ? "true" : "false")
    }

    func setComponentShowText(_ component: String, _ show: Bool) throws {
        try setComponentOption(component, "showText", show ? "true" : "false")
    }

    func readComponentBool(_ component: String, _ key: String) -> Bool? {
        readBoolOption("omanix.omabar.components.\(component).\(key)")
    }

    func readComponentString(_ component: String, _ key: String) -> String? {
        readOption("omanix.omabar.components.\(component).\(key)")
    }

    func setOmatilesOption(_ key: String, _ value: String) throws {
        try setState("omanix.omatiles.\(key)", value)
    }

    func setOmatilesEnabled(_ v: Bool) throws { try setOmatilesOption("enable", v ? "true" : "false") }
    func setOmatilesBindings(_ v: Bool) throws { try setOmatilesOption("bindings", v ? "true" : "false") }
    func setOmatilesEdgeDrag(_ v: Bool) throws { try setOmatilesOption("enableEdgeDrag", v ? "true" : "false") }
    func setOmatilesKeyboardShortcuts(_ v: Bool) throws { try setOmatilesOption("enableKeyboardShortcuts", v ? "true" : "false") }
    func setOmatilesMargins(_ v: Bool) throws { try setOmatilesOption("enableMargins", v ? "true" : "false") }
    func setOmatilesDefaultLayout(_ v: String) throws { try setOmatilesOption("defaultLayout", v) }
    func setOmatilesAutoTile(_ v: Bool) throws { try setOmatilesOption("autoTile", v ? "true" : "false") }

    /// Applies the resolved omatiles declarative state to the live system via the
    /// Nix-owned `omanix state apply omatiles` path (mirrors the activation script).
    /// Best-effort — throws only if the CLI itself fails.
    func applyOmatilesLive() throws {
        let path = findOmanixBinary()
        let output = runSync([path, "state", "apply", "omatiles"])
        guard output.terminationStatus == 0 else {
            throw OmanixError.commandFailed(output.stderr.isEmpty ? output.stdout : output.stderr)
        }
    }

    // MARK: - Config state readers (bar + tiling)

    /// Reads a literal `option = value;` from state.nix first (machine-written), then
    /// configuration.nix (human-written). State wins because it is the newer source for
    /// app-toggled options.
    func readOption(_ option: String) -> String? {
        if let v = literalOption(option, inFile: stateFilePath) { return v }
        return literalOption(option, inFile: configPath)
    }

    /// Reads a literal `option = value;` assignment from a single Nix file.
    private func literalOption(_ option: String, inFile path: String) -> String? {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        let pattern = #"\#(NSRegularExpression.escapedPattern(for: option))\s*=\s*([^;]+);"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let value = ns.substring(with: match.range(at: 1))
        return value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }

    func readBoolOption(_ option: String) -> Bool? {
        guard let v = readOption(option) else { return nil }
        return v == "true"
    }

    /// Reads the current `omanix.omabar.*` values with defaults for anything unset.
    /// Structured `components.<name>.*` overrides flat `show*` when set (Phase 3).
    func currentOmabarState() -> OmabarState {
        OmabarState(
            enable: readBoolOption("omanix.omabar.enable") ?? true,
            showClock: readComponentBool("clock", "enable") ?? readBoolOption("omanix.omabar.showClock") ?? true,
            showBattery: readComponentBool("battery", "enable") ?? readBoolOption("omanix.omabar.showBattery") ?? true,
            showVolume: readComponentBool("volume", "enable") ?? readBoolOption("omanix.omabar.showVolume") ?? true,
            showVolumeText: readComponentBool("volume", "showText") ?? readBoolOption("omanix.omabar.showVolumeText") ?? true,
            showWifi: readComponentBool("wifi", "enable") ?? readBoolOption("omanix.omabar.showWifi") ?? true,
            showApps: readComponentBool("apps", "enable") ?? readBoolOption("omanix.omabar.showApps") ?? false,
            autoHide: readBoolOption("omanix.omabar.autoHide") ?? false,
            showDate: readBoolOption("omanix.omabar.showDate") ?? true,
            showBatteryPercent: readComponentBool("battery", "showText") ?? readBoolOption("omanix.omabar.showBatteryPercent") ?? true,
            use24Hour: readBoolOption("omanix.omabar.use24Hour") ?? false,
            clockFormat: readComponentString("clock", "style") ?? readOption("omanix.omabar.clockFormat") ?? "digital"
        )
    }

    /// Reads the current `omanix.omatiles.*` values with defaults for anything unset.
    func currentOmatilesState() -> OmatilesState {
        OmatilesState(
            enable: readBoolOption("omanix.omatiles.enable") ?? true,
            bindings: readBoolOption("omanix.omatiles.bindings") ?? true,
            enableEdgeDrag: readBoolOption("omanix.omatiles.enableEdgeDrag") ?? true,
            enableKeyboardShortcuts: readBoolOption("omanix.omatiles.enableKeyboardShortcuts") ?? true,
            enableMargins: readBoolOption("omanix.omatiles.enableMargins") ?? false
        )
    }

    /// Locates the `omanix` CLI for Nix-owned state mutations, preferring the flake
    /// dir then PATH.
    private func findOmanixBinary() -> String {
        let local = "\(omanixDir)/bin/omanix"
        if FileManager.default.isExecutableFile(atPath: local) { return local }
        return "omanix"
    }

    /// Synchronous process runner: executes a command and returns stdout, stderr, and
    /// the exit status. Only used for tiny, fast CLI mutations (omanix state set), so
    /// blocking is acceptable.
    private func runSync(_ arguments: [String]) -> (terminationStatus: Int32, stdout: String, stderr: String) {
        let launchPath = arguments.first ?? "omanix"
        let args = Array(arguments.dropFirst())
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [launchPath] + args
        process.environment = ProcessInfo.processInfo.environment.merging(
            ["PATH": processPATH, "FLAKE_DIR": omanixDir]
        ) { _, new in new }
        process.standardOutput = stdout
        process.standardError = stderr

        do { try process.run() } catch {
            return (1, "", "Failed to launch \(launchPath): \(error.localizedDescription)")
        }
        process.waitUntilExit()
        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        return (
            process.terminationStatus,
            String(data: outData, encoding: .utf8) ?? "",
            String(data: errData, encoding: .utf8) ?? ""
        )
    }

    // MARK: - Process helpers

    /// GUI apps don't inherit a shell PATH, so we assemble one explicitly.
    private var processPATH: String {
        let userLocal   = NSHomeDirectory() + "/.local/bin"
        let nixProfile  = "/nix/var/nix/profiles/default/bin"
        let nixHome     = NSHomeDirectory() + "/.nix-profile/bin"
        let homebrew    = "/opt/homebrew/bin"
        let systemSw    = "/run/current-system/sw/bin"
        let systemPaths = "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin"
        return "\(userLocal):\(nixProfile):\(nixHome):\(homebrew):\(systemSw):\(systemPaths)"
    }

    private func findExecutable(_ name: String) async -> String? {
        guard let path = try? await runCommand("which", [name]) else { return nil }
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func runCommand(_ command: String, _ arguments: [String]) async throws -> String {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + arguments
        process.environment = ProcessInfo.processInfo.environment.merging(
            ["PATH": processPATH]
        ) { _, new in new }
        process.standardOutput = stdout
        process.standardError = stderr

        let outTask = Task.detached { stdout.fileHandleForReading.readDataToEndOfFile() }
        let errTask = Task.detached { stderr.fileHandleForReading.readDataToEndOfFile() }

        try process.run()
        while process.isRunning {
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        let outData = await outTask.value
        let errData = await errTask.value
        let errStr = String(data: errData, encoding: .utf8) ?? ""
        guard let output = String(data: outData, encoding: .utf8) else {
            throw OmanixError.invalidOutput
        }
        guard process.terminationStatus == 0 else {
            throw OmanixError.commandFailed(errStr.isEmpty ? output : errStr)
        }
        return output
    }

    private func runJSONCommand(_ path: String, _ args: [String], timeout: TimeInterval) async throws -> [String: Any] {
        let process = Process()
        let stdout = Pipe()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        process.environment = ProcessInfo.processInfo.environment.merging(
            ["PATH": processPATH]
        ) { _, new in new }
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice

        let dataTask = Task.detached { stdout.fileHandleForReading.readDataToEndOfFile() }
        try process.run()

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        if process.isRunning {
            process.terminate()
            throw OmanixError.timedOut(path)
        }

        let data = await dataTask.value
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OmanixError.invalidOutput
        }
        return json
    }

    private func extractNixName(_ key: String) -> String {
        key.split(separator: ".").last.map(String.init) ?? key
    }
}

// MARK: - Brew Codable

private struct BrewCask: Codable {
    let token: String
    let name: [String]?
    let desc: String?
}

private struct BrewFormula: Codable {
    let name: String
    let desc: String?
}
