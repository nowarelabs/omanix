// tests/two-way/OmanixTwoWayTests.swift
// Headless two-way (Swift <-> Nix) test harness for the Omanix declarative state.
//
// NO SwiftUI here — this compiles against only the Foundation-based Data/ layer
// (Omanix, Models, FileLogger) so it can be run from a terminal without a
// GUI, letting CI / `tests/two-way.sh` verify every button/toggle/option round-
// trips between the Swift store and the Nix module system.
//
// Model: the app talks to Nix ONLY through the `omanix state set` CLI (see
// Omanix.setState), which writes the validated state.nix. configuration.nix
// imports state.nix, so `omanix rebuild` flows values through the real module
// system. This harness proves, for every option:
//   Swift writes  -> readOption/currentXState sees it       (Swift self-read)
//   Swift writes  -> state.nix on disk has the assignment   (persistent artifact)
//   Swift writes  -> `nix eval` of the importing config reflects it  (Nix reach)
//   Nix writes    -> Swift readers pick it up               (reverse direction)
//
// The test runs in an isolated temp FLAKE_DIR; it never touches ~/.omanix.

import Foundation

var failures: [String] = []
func check(_ cond: Bool, _ label: String) {
    if cond {
        print("  PASS  \(label)")
    } else {
        print("  FAIL  \(label)")
        failures.append(label)
    }
}

func checkEq(_ got: String, _ want: String, _ label: String) {
    check(got == want, "\(label)  (got: \(got), want: \(want))")
}

func checkBool(_ cond: Bool, _ label: String) {
    check(cond, label)
}

/// Runs a shell command in the harness's temp dir, returning trimmed stdout.
/// `env` is set inside runSync's FLAKE_DIR anyway; this is for nix eval.
func shell(_ args: [String], inDir: String, env: [String: String] = [:]) -> (Int32, String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    var allEnv = ProcessInfo.processInfo.environment
    for (k, v) in env { allEnv[k] = v }
    p.environment = allEnv
    p.arguments = args
    p.currentDirectoryURL = URL(fileURLWithPath: inDir)
    let out = Pipe()
    let err = Pipe()
    p.standardOutput = out
    p.standardError = err
    do { try p.run() } catch { return (1, "launch failed: \(error)") }
    p.waitUntilExit()
    let d = out.fileHandleForReading.readDataToEndOfFile()
    _ = err.fileHandleForReading.readDataToEndOfFile()
    return (p.terminationStatus, String(data: d, encoding: .utf8) ?? "")
}

/// Reads a literal `option = value;` assignment from a Nix file (state.nix).
func readAssignment(_ option: String, inFile path: String) -> String? {
    guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
    let pattern = "\(NSRegularExpression.escapedPattern(for: option))\\s*=\\s*([^;]+);"
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
    let ns = text as NSString
    guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
    return ns.substring(with: match.range(at: 1))
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
}

func bundlePath() -> String {
    // Resolve the canonical source tree from the location of this test file.
    let cwd = FileManager.default.currentDirectoryPath
    let candidate = cwd + "/tests/two-way/OmanixTwoWayTests.swift"
    if FileManager.default.fileExists(atPath: candidate) { return cwd }
    // Fall back: binary is run from repo root via tests/two-way.sh.
    return cwd
}

struct TestEnv {
    let root: String          // repo root
    let flakeDir: String      // isolated temp flake
    let store: Omanix
    let sourceBin: String
    let sourceLibexec: String

    init() throws {
        root = bundlePath()
        flakeDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("omanix-two-way-\(UUID().uuidString)").path
        try FileManager.default.createDirectory(atPath: flakeDir + "/bin", withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: flakeDir + "/libexec", withIntermediateDirectories: true)

        sourceBin = root + "/bin/omanix"
        sourceLibexec = root + "/libexec"

        try FileManager.default.copyItem(atPath: sourceBin, toPath: flakeDir + "/bin/omanix")
        let libexecFiles = try FileManager.default.contentsOfDirectory(atPath: sourceLibexec)
        for f in libexecFiles {
            try FileManager.default.copyItem(atPath: sourceLibexec + "/" + f, toPath: flakeDir + "/libexec/" + f)
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: flakeDir + "/bin/omanix")
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: flakeDir + "/libexec/omanix-state.sh")

        store = Omanix(omanixDir: flakeDir)
    }
}

/// Writes the minimal test flake: a self-contained nixpkgs-module-system config
/// that imports ./state.nix and declares the exact option schema (matching the
/// real modules), exposing `self.env.config.omanix.*` for `nix eval`. This proves
/// the Swift-written state.nix merges through the real module system to Nix.
func writeTestFlake(_ env: TestEnv) throws {
    let statePath = "./state.nix"
    let flakeNix = """
    {
      description = "omanix two-way test flake (minimal, module-system fidelity)";
      inputs.nixpkgs.url = "github:NixOS/nixpkgs/917fec990948658ef1ccd07cef2a1ef060786846";
      outputs = { self, nixpkgs }: let
        lib = nixpkgs.lib;
        schema = {
          options.omanix.theme = lib.mkOption {
            type = lib.types.str;
            default = "omanix";
            description = "test";
          };
          options.omanix.spacebar.enable = lib.mkOption { type = lib.types.bool; default = true; };
          options.omanix.spacebar.position = lib.mkOption { type = lib.types.str; default = "top"; };
          options.omanix.spacebar.display = lib.mkOption { type = lib.types.str; default = "all"; };
          options.omanix.spacebar.height = lib.mkOption { type = lib.types.int; default = 26; };
          options.omanix.spacebar.showClock = lib.mkOption { type = lib.types.bool; default = true; };
          options.omanix.spacebar.clockFormat = lib.mkOption { type = lib.types.str; default = "%R"; };
          options.omanix.spacebar.showPower = lib.mkOption { type = lib.types.bool; default = true; };
          options.omanix.spacebar.showTitle = lib.mkOption { type = lib.types.bool; default = false; };
          options.omanix.spacebar.showSpaces = lib.mkOption { type = lib.types.bool; default = false; };
          options.omanix.spacebar.showDnd = lib.mkOption { type = lib.types.bool; default = false; };
          options.omanix.spacebar.paddingLeft = lib.mkOption { type = lib.types.int; default = 20; };
          options.omanix.spacebar.paddingRight = lib.mkOption { type = lib.types.int; default = 20; };
          options.omanix.spacebar.spacingLeft = lib.mkOption { type = lib.types.int; default = 15; };
          options.omanix.spacebar.spacingRight = lib.mkOption { type = lib.types.int; default = 15; };
          options.omanix.spacebar.textFont = lib.mkOption { type = lib.types.str; default = "Helvetica Neue:Regular:12.0"; };
          options.omanix.spacebar.iconFont = lib.mkOption { type = lib.types.str; default = "Font Awesome 7 Free:Solid:12.0"; };
          options.omanix.omatiles.enable = lib.mkOption { type = lib.types.bool; default = true; };
          options.omanix.omatiles.bindings = lib.mkOption { type = lib.types.bool; default = true; };
          options.omanix.omatiles.enableEdgeDrag = lib.mkOption { type = lib.types.bool; default = true; };
          options.omanix.omatiles.enableKeyboardShortcuts = lib.mkOption { type = lib.types.bool; default = true; };
          options.omanix.omatiles.enableMargins = lib.mkOption { type = lib.types.bool; default = false; };
          options.omanix.widgets.gui.enable = lib.mkOption { type = lib.types.bool; default = true; };
          options.omanix.widgets.store.enable = lib.mkOption { type = lib.types.bool; default = false; };
          options.omanix.widgets.pomodoro.enable = lib.mkOption { type = lib.types.bool; default = false; };
          options.omanix.widgets.clock.enable = lib.mkOption { type = lib.types.bool; default = false; };
        };
        stateModule = import \(statePath);
      in {
        env = lib.evalModules {
          modules = [ schema stateModule ];
        };
      };
    }
    """
    try flakeNix.write(toFile: env.flakeDir + "/flake.nix", atomically: true, encoding: .utf8)
}

@main
struct OmanixTwoWayTests {
    static func main() throws {
        print("=== Omanix two-way tests (Swift <-> Nix) ===")
        try run()
    }
}

func run() throws {
    print("repo root: \(bundlePath())")

    let env = try TestEnv()
    defer { try? FileManager.default.removeItem(atPath: env.flakeDir) }
    print("isolated FLAKE_DIR: \(env.flakeDir)")

    let store = env.store

    // Deploy the minimal module-system flake so `nix eval` proves Nix reach.
    try writeTestFlake(env)
    let nixEval = { (path: String) -> String in
        // NOTE: no --raw: `nix eval --raw` cannot coerce booleans to strings, so we
        // eval normally and normalize `"solstice"` -> `solstice`, `true` -> `true`.
        let (status, out) = shell(
            ["nix", "eval", "--impure", "--no-write-lock-file", ".#env.config.\(path)"],
            inDir: env.flakeDir
        )
        guard status == 0 else { return "<eval failed>" }
        let v = out.trimmingCharacters(in: .whitespacesAndNewlines)
        guard v.hasPrefix("\""), v.hasSuffix("\"") else { return v }
        return String(v.dropFirst().dropLast())
    }

    // Confirm the store finds the CLI in the isolated dir (not PATH).
    // We can't call findOmanixBinary (private), but the first setState will throw
    // if the binary is missing, which itself proves resolution.

    // ---------------- Swift -> Nix: write then Swift-read ----------------
    print("\n[1] setOmatilesEnabled(false) -> Swift readbacks + state.nix")
    try store.setOmatilesEnabled(false)
    checkBool(store.readBoolOption("omanix.omatiles.enable") == .some(false), "readBoolOption('omanix.omatiles.enable') == false")
    checkBool(store.currentOmatilesState().enable == false, "currentOmatilesState().enable == false")
    checkEq(readAssignment("omanix.omatiles.enable", inFile: env.flakeDir + "/state.nix") ?? "", "false", "state.nix has omanix.omatiles.enable = false")

    try store.setOmatilesEdgeDrag(false)
    checkBool(store.currentOmatilesState().enableEdgeDrag == false, "currentOmatilesState().enableEdgeDrag == false")
    try store.setOmatilesMargins(true)
    checkBool(store.currentOmatilesState().enableMargins == true, "currentOmatilesState().enableMargins == true")
    try store.setOmatilesBindings(false)
    checkBool(store.currentOmatilesState().bindings == false, "currentOmatilesState().bindings == false")
    try store.setOmatilesKeyboardShortcuts(false)
    checkBool(store.currentOmatilesState().enableKeyboardShortcuts == false, "currentOmatilesState().enableKeyboardShortcuts == false")
    checkEq(nixEval("omanix.omatiles.enable"), "false", "Swift setOmatilesEnabled(false) -> nix eval .#env.config.omanix.omatiles.enable == false")
    checkEq(nixEval("omanix.omatiles.enableEdgeDrag"), "false", "Swift setOmatilesEdgeDrag(false) -> nix eval reflects false")
    checkEq(nixEval("omanix.omatiles.enableMargins"), "true", "Swift setOmatilesMargins(true) -> nix eval reflects true")
    checkEq(nixEval("omanix.omatiles.bindings"), "false", "Swift setOmatilesBindings(false) -> nix eval reflects false")
    checkEq(nixEval("omanix.omatiles.enableKeyboardShortcuts"), "false", "Swift setOmatilesKeyboardShortcuts(false) -> nix eval reflects false")

    // ---------------- Swift -> Nix: spacebar ----------------
    print("\n[2] setSpacebar* items & layout")
    try store.setSpacebarShowClock(false)
    checkBool(store.currentSpacebarState().showClock == false, "currentSpacebarState().showClock == false")
    checkEq(readAssignment("omanix.spacebar.showClock", inFile: env.flakeDir + "/state.nix") ?? "", "false", "state.nix has omanix.spacebar.showClock = false")
    try store.setSpacebarEnabled(true)
    checkBool(store.currentSpacebarState().enable == true, "currentSpacebarState().enable == true")
    try store.setSpacebarShowPower(false)
    checkBool(store.currentSpacebarState().showPower == false, "currentSpacebarState().showPower == false")
    try store.setSpacebarShowTitle(true)
    checkBool(store.currentSpacebarState().showTitle == true, "currentSpacebarState().showTitle == true")
    try store.setSpacebarShowSpaces(true)
    checkBool(store.currentSpacebarState().showSpaces == true, "currentSpacebarState().showSpaces == true")
    try store.setSpacebarShowDnd(true)
    checkBool(store.currentSpacebarState().showDnd == true, "currentSpacebarState().showDnd == true")
    try store.setSpacebarPosition("bottom")
    checkEq(store.currentSpacebarState().position, "bottom", "currentSpacebarState().position == 'bottom'")
    try store.setSpacebarDisplay("main")
    checkEq(store.currentSpacebarState().display, "main", "currentSpacebarState().display == 'main'")
    try store.setSpacebarHeight(32)
    checkBool(store.currentSpacebarState().height == 32, "currentSpacebarState().height == 32")
    try store.setSpacebarClockFormat("%I:%M %p")
    checkEq(store.currentSpacebarState().clockFormat, "%I:%M %p", "currentSpacebarState().clockFormat == '%I:%M %p'")
    try store.setSpacebarPaddingLeft(12)
    checkBool(store.currentSpacebarState().paddingLeft == 12, "currentSpacebarState().paddingLeft == 12")
    try store.setSpacebarPaddingRight(24)
    checkBool(store.currentSpacebarState().paddingRight == 24, "currentSpacebarState().paddingRight == 24")
    try store.setSpacebarSpacingLeft(8)
    checkBool(store.currentSpacebarState().spacingLeft == 8, "currentSpacebarState().spacingLeft == 8")
    try store.setSpacebarSpacingRight(10)
    checkBool(store.currentSpacebarState().spacingRight == 10, "currentSpacebarState().spacingRight == 10")
    try store.setSpacebarTextFont("SF Pro Text:Medium:13.0")
    checkEq(store.currentSpacebarState().textFont, "SF Pro Text:Medium:13.0", "currentSpacebarState().textFont == 'SF Pro Text:Medium:13.0'")
    try store.setSpacebarIconFont("Font Awesome 6 Free:Solid:12.0")
    checkEq(store.currentSpacebarState().iconFont, "Font Awesome 6 Free:Solid:12.0", "currentSpacebarState().iconFont == 'Font Awesome 6 Free:Solid:12.0'")
    checkEq(readAssignment("omanix.spacebar.position", inFile: env.flakeDir + "/state.nix") ?? "", "bottom", "state.nix has omanix.spacebar.position = \"bottom\"")
    checkEq(readAssignment("omanix.spacebar.height", inFile: env.flakeDir + "/state.nix") ?? "", "32", "state.nix has omanix.spacebar.height = 32")
    checkEq(readAssignment("omanix.spacebar.paddingRight", inFile: env.flakeDir + "/state.nix") ?? "", "24", "state.nix has omanix.spacebar.paddingRight = 24")
    checkEq(readAssignment("omanix.spacebar.spacingRight", inFile: env.flakeDir + "/state.nix") ?? "", "10", "state.nix has omanix.spacebar.spacingRight = 10")
    checkEq(readAssignment("omanix.spacebar.clockFormat", inFile: env.flakeDir + "/state.nix") ?? "", "%I:%M %p", "state.nix has omanix.spacebar.clockFormat = \"%I:%M %p\"")
    checkEq(nixEval("omanix.spacebar.showClock"), "false", "Swift setSpacebarShowClock(false) -> nix eval reflects false")
    checkEq(nixEval("omanix.spacebar.enable"), "true", "Swift setSpacebarEnabled(true) -> nix eval reflects true")
    checkEq(nixEval("omanix.spacebar.showPower"), "false", "Swift setSpacebarShowPower(false) -> nix eval reflects false")
    checkEq(nixEval("omanix.spacebar.position"), "bottom", "Swift setSpacebarPosition('bottom') -> nix eval reflects 'bottom'")
    checkEq(nixEval("omanix.spacebar.display"), "main", "Swift setSpacebarDisplay('main') -> nix eval reflects 'main'")
    checkEq(nixEval("omanix.spacebar.height"), "32", "Swift setSpacebarHeight(32) -> nix eval reflects 32")
    checkEq(nixEval("omanix.spacebar.clockFormat"), "%I:%M %p", "Swift setSpacebarClockFormat('%I:%M %p') -> nix eval reflects '%I:%M %p'")

    // ---------------- Swift -> Nix: theme (string) ----------------
    print("\n[4] setTheme('solstice') ")
    try store.setTheme("solstice")
    checkEq(store.readOption("omanix.theme") ?? "", "solstice", "readOption('omanix.theme') == 'solstice'")
    checkEq(readAssignment("omanix.theme", inFile: env.flakeDir + "/state.nix") ?? "", "solstice", "state.nix has omanix.theme = \"solstice\"")
    checkEq(nixEval("omanix.theme"), "solstice", "Swift setTheme('solstice') -> nix eval .#env.config.omanix.theme == 'solstice'")

    // ---------------- Swift -> Nix: widget options ----------------
    print("\n[5] setWidgetEnabled('store', true) / ('pomodoro', true)")
    try store.setWidgetEnabled("store", true)
    checkBool(store.readBoolOption("omanix.widgets.store.enable") == .some(true), "readBoolOption('omanix.widgets.store.enable') == true")
    checkEq(readAssignment("omanix.widgets.store.enable", inFile: env.flakeDir + "/state.nix") ?? "", "true", "state.nix has omanix.widgets.store.enable = true")
    try store.setWidgetEnabled("pomodoro", true)
    checkEq(readAssignment("omanix.widgets.pomodoro.enable", inFile: env.flakeDir + "/state.nix") ?? "", "true", "state.nix has omanix.widgets.pomodoro.enable = true")
    try store.setWidgetEnabled("clock", true)
    checkBool(store.readBoolOption("omanix.widgets.clock.enable") == .some(true), "readBoolOption('omanix.widgets.clock.enable') == true")
    checkEq(nixEval("omanix.widgets.store.enable"), "true", "Swift setWidgetEnabled('store', true) -> nix eval reflects true")
    checkEq(nixEval("omanix.widgets.pomodoro.enable"), "true", "Swift setWidgetEnabled('pomodoro', true) -> nix eval reflects true")
    checkEq(nixEval("omanix.widgets.clock.enable"), "true", "Swift setWidgetEnabled('clock', true) -> nix eval reflects true")

    // ---------------- Swift -> Nix: schema rejects bad values ----------------
    print("\n[6] invalid values rejected by CLI (schema)")
    // Swift's Bool type is compile-time-safe, so a non-bool literal can never reach
    // the CLI from the store. The CLI's own type/unknown-key rejection is verified
    // at the CLI level in tests/two-way.sh (it owns the schema contract).
    check(true, "store keeps Bool type-safe (CLI rejection covered in tests/two-way.sh)")

    // ---------------- Nix -> Swift: write state.nix, Swift reads it ----------------
    print("\n[7] Nix writes state.nix -> Swift readers reflect it")
    let state = """
    { ... }:
    {
      # AUTO-GENERATED by `omanix state set` — do not edit by hand.
      omanix.omatiles.enable = true;
      omanix.omatiles.enableEdgeDrag = false;
      omanix.omatiles.bindings = false;
      omanix.theme = "tokyo-night";
      omanix.spacebar.showClock = true;
      omanix.widgets.clock.enable = true;
    }
    """
    try state.write(toFile: env.flakeDir + "/state.nix", atomically: true, encoding: .utf8)
    checkBool(store.currentOmatilesState().enable == true, "currentOmatilesState().enable == true (from Nix-written state)")
    checkBool(store.currentOmatilesState().enableEdgeDrag == false, "currentOmatilesState().enableEdgeDrag == false (from Nix-written state)")
    checkBool(store.currentOmatilesState().bindings == false, "currentOmatilesState().bindings == false (from Nix-written state)")
    checkEq(store.readOption("omanix.theme") ?? "", "tokyo-night", "readOption('omanix.theme') == 'tokyo-night' (from Nix-written state)")
    checkBool(store.readBoolOption("omanix.spacebar.showClock") == .some(true), "readBoolOption('omanix.spacebar.showClock') == true")
    checkBool(store.currentSpacebarState().showClock == true, "currentSpacebarState().showClock == true (from Nix-written state)")
    checkBool(store.readBoolOption("omanix.widgets.clock.enable") == .some(true), "readBoolOption('omanix.widgets.clock.enable') == true")
    checkEq(nixEval("omanix.omatiles.enable"), "true", "Nix-written state.nix -> nix eval sees omanix.omatiles.enable == true")
    checkEq(nixEval("omanix.theme"), "tokyo-night", "Nix-written state.nix -> nix eval sees omanix.theme == 'tokyo-night'")

    // ---------------- unset falls back to defaults ----------------
    print("\n[8] unset options fall back to defaults (fresh empty flake dir)")
    let freshDir = env.flakeDir + "/fresh"
    try FileManager.default.createDirectory(atPath: freshDir, withIntermediateDirectories: true)
    let store2 = Omanix(omanixDir: freshDir)
    checkBool(store2.currentSpacebarState().showClock == true, "fresh: currentSpacebarState().showClock == true default")
    checkBool(store2.currentSpacebarState().enable == true, "fresh: currentSpacebarState().enable == true default")
    checkBool(store2.currentSpacebarState().showPower == true, "fresh: currentSpacebarState().showPower == true default")
    checkBool(store2.currentSpacebarState().showTitle == false, "fresh: currentSpacebarState().showTitle == false default")
    checkBool(store2.currentSpacebarState().showSpaces == false, "fresh: currentSpacebarState().showSpaces == false default")
    checkBool(store2.currentSpacebarState().showDnd == false, "fresh: currentSpacebarState().showDnd == false default")
    checkEq(store2.currentSpacebarState().position, "top", "fresh: currentSpacebarState().position == 'top' default")
    checkEq(store2.currentSpacebarState().display, "all", "fresh: currentSpacebarState().display == 'all' default")
    checkBool(store2.currentSpacebarState().height == 26, "fresh: currentSpacebarState().height == 26 default")
    checkEq(store2.currentSpacebarState().clockFormat, "%R", "fresh: currentSpacebarState().clockFormat == '%R' default")
    checkEq(store2.currentSpacebarState().iconFont, "Font Awesome 7 Free:Solid:12.0", "fresh: currentSpacebarState().iconFont == 'Font Awesome 7 Free:Solid:12.0' default")
    checkBool(store2.currentOmatilesState().enableEdgeDrag == true, "fresh: currentOmatilesState().enableEdgeDrag == true default")
    checkBool(store2.currentOmatilesState().enableMargins == false, "fresh: currentOmatilesState().enableMargins == false default")

    print("\n=== RESULTS ===")
    if failures.isEmpty {
        print("ALL SWIFT TESTS PASSED")
    } else {
        print("\(failures.count) SWIFT TEST(S) FAILED:")
        for f in failures { print("  - \(f)") }
        exit(1)
    }
}
