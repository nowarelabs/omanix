// Modules/Kdl/Sources/NumberTypes.swift
//
// Minimal, dependency-free replacements for the `BigDecimal` and `BigInt`
// modules that the vendored KDL parser originally imported (via SwiftPM).
//
// KDL only needs these types to *represent* numeric literals and round-trip them
// to a string for description/equality — it never does arithmetic on them, and
// Omanix reads only string values from KDL workspace documents. So a string-backed
// implementation is exactly the right size and removes every external dependency.
//
// `BigDecimal` reproduces the exact string forms the KDL spec tests assert:
//   - "1.5E1000"  -> description "1.5E+1000"  (exponent forces a '+' when unsigned)
//   - "1.5E-1000" -> description "1.5E-1000"  (existing exponent sign preserved)
//   - "+1.0"      == "1.0"                    (leading '+' ignored for equality)
// `BInt` stores an arbitrary-precision integer as a decimal string and can be
// constructed from a radix (hex/octal/binary) literal.

import Foundation

/// Arbitrary-precision decimal, backed by its original canonical string.
public struct BigDecimal: Equatable, CustomStringConvertible, Sendable {
    public let value: String

    public init(_ s: String) { value = s }

    /// Canonical form: uppercase the exponent marker, ensure an explicit '+' on an
    /// unsigned exponent. Same as the upstream description for the tested forms.
    public var description: String { BigDecimal.normalizeExponent(value) }

    /// Equality compares canonical forms; a leading '+' on the mantissa is ignored
    /// so that "+1.0" == "1.0" (the KDL spec treats sign identically).
    public static func == (lhs: BigDecimal, rhs: BigDecimal) -> Bool {
        lhs.compareKey == rhs.compareKey
    }

    private var compareKey: String {
        var v = value
        if v.hasPrefix("+") { v.removeFirst() }
        return BigDecimal.normalizeExponent(v)
    }

    private static func normalizeExponent(_ s: String) -> String {
        guard let idx = s.firstIndex(where: { $0 == "e" || $0 == "E" }) else { return s }
        let mantissa = String(s[s.startIndex..<idx])
        var exponent = String(s[s.index(after: idx)...])
        if let first = exponent.first, first != "+", first != "-" {
            exponent = "+" + exponent
        }
        return mantissa + "E" + exponent
    }
}

/// Arbitrary-precision integer, backed by a decimal string. Constructible from a
/// decimal string or a base-16/8/2 literal (used by the KDL parser for hex/octal/
/// binary tokens that exceed the platform Int range). No tests in the vendored
/// suite exercise this path, but it is implemented correctly and dependency-free.
public struct BInt: Equatable, CustomStringConvertible, Sendable {
    let digits: String

    /// Decimal-string initializer. Returns nil for anything that is not a
    /// (optionally signed) base-10 integer literal.
    public init?(_ s: String) {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.isEmpty == false else { return nil }
        var body = t
        var sign = ""
        if body.first == "+" || body.first == "-" {
            sign = String(body.removeFirst())
        }
        guard !body.isEmpty, body.allSatisfy({ $0.isNumber }) else { return nil }
        // Normalize away leading zeros but keep at least one digit.
        var norm = String(body.drop(while: { $0 == "0" }))
        if norm.isEmpty { norm = "0" }
        digits = norm == "0" ? "0" : sign + norm
    }

    /// Parse from a non-decimal radix (16, 8, 2). Returns nil on invalid input.
    init?(_ s: String, radix: Int) {
        guard radix == 2 || radix == 8 || radix == 16, !s.isEmpty else { return nil }
        let valid: Set<Character>
        switch radix {
        case 2: valid = Set("01")
        case 8: valid = Set("01234567")
        default: valid = Set("0123456789abcdefABCDEF")
        }
        guard s.allSatisfy({ valid.contains($0) }), !s.isEmpty else { return nil }
        // Convert radix -> decimal string by repeated base conversion.
        var decimal = "0"
        for ch in s {
            let digit = radix == 16 ? BInt.hexValue(ch) : Int(String(ch), radix: radix) ?? 0
            // decimal = decimal * radix + digit
            decimal = BInt.multiplyBySmall(decimal, radix)
            decimal = BInt.addSmall(decimal, digit)
        }
        var norm = String(decimal.drop(while: { $0 == "0" }))
        if norm.isEmpty { norm = "0" }
        digits = norm
    }

    public var description: String { digits }

    public static func == (lhs: BInt, rhs: BInt) -> Bool { lhs.digits == rhs.digits }

    // MARK: string big-integer helpers

    private static func hexValue(_ c: Character) -> Int {
        switch c {
        case "0"..."9": return Int(String(c)) ?? 0
        case "a"..."f": return Int(c.asciiValue! - Character("a").asciiValue! + 10)
        case "A"..."F": return Int(c.asciiValue! - Character("A").asciiValue! + 10)
        default: return 0
        }
    }

    private static func multiplyBySmall(_ s: String, _ m: Int) -> String {
        guard m != 0 else { return "0" }
        var result = ""
        var carry = 0
        for ch in s.reversed() where ch.isNumber {
            let prod = (Int(String(ch)) ?? 0) * m + carry
            result.insert(Character(String(prod % 10)), at: result.startIndex)
            carry = prod / 10
        }
        while carry > 0 {
            result.insert(Character(String(carry % 10)), at: result.startIndex)
            carry /= 10
        }
        return result.isEmpty ? "0" : result
    }

    private static func addSmall(_ s: String, _ a: Int) -> String {
        guard a != 0 else { return s }
        var result = ""
        var carry = a
        for ch in s.reversed() where ch.isNumber {
            let sum = (Int(String(ch)) ?? 0) + carry
            result.insert(Character(String(sum % 10)), at: result.startIndex)
            carry = sum / 10
        }
        while carry > 0 {
            result.insert(Character(String(carry % 10)), at: result.startIndex)
            carry /= 10
        }
        return result.isEmpty ? "0" : result
    }
}
