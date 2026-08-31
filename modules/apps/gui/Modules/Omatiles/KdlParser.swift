// Modules/Omatiles/KdlParser.swift
//
// A small, reusable KDL tokenizer + parser (the "parsing" half of the
// Interpreter pattern). Its only job is to turn a KDL document string into a
// plain AST (`KdlNode` tree). It knows nothing about windows or workspaces —
// that interpretation lives in `KdlWorkspaceCompiler`, so each half can be
// tested and swapped independently (separation of concerns).
//
// KDL is a newline-terminated grammar: a node's inline values end at a newline
// (or `;`), and each following line is a new sibling node. Blocks `{ }` hold a
// set of child nodes.
//
// Supported surface (enough for declarative workspace/layout documents):
//   nodes            :  name value1 value2 { children }
//   quoted values    :  "double"  'single'
//   unquoted values  :  abc 123 true (bare identifiers / numbers / booleans)
//   properties       :  key="value"  key=unquoted
//   comments         :  // line   and   /* block */
// `;` is an optional statement separator. Blank lines are ignored.

import Foundation

/// A single parsed KDL node: a name, positional values, key=value properties,
/// and optional child nodes.
struct KdlNode {
    var name: String
    var args: [String] = []
    var properties: [String: String] = [:]
    var children: [KdlNode] = []

    init(_ name: String, args: [String] = [], properties: [String: String] = [:], children: [KdlNode] = []) {
        self.name = name
        self.args = args
        self.properties = properties
        self.children = children
    }
}

/// Tokenizer for the KDL grammar. Splits source text into a flat token stream;
/// the parser walks these tokens. Keeping tokenization separate keeps each piece
/// trivially correct and testable. Newlines are significant tokens because KDL
/// statement boundaries are line-based.
private enum KdlToken {
    case node(String)          // an identifier or quoted node name/value
    case prop(String)          // a property key (from `key=`)
    case openBrace, closeBrace
    case newline               // statement separator (also `;`)
}

enum KdlParseError: Error, Equatable {
    case unterminatedString
}

enum KdlParser {

    /// Parse a full KDL document into its top-level nodes. Any syntax error
    /// returns nil (never throws to the caller), so malformed input degrades to
    /// an empty map instead of crashing the app.
    static func parse(_ text: String) -> [KdlNode]? {
        guard let tokens = try? tokenize(text) else { return nil }
        var remaining = ArraySlice(tokens)
        var roots: [KdlNode] = []
        while let node = parseNode(&remaining) {
            roots.append(node)
        }
        return roots
    }

    // MARK: - Tokenizer

    private static func tokenize(_ text: String) throws -> [KdlToken] {
        let chars = Array(text)
        var i = 0
        var tokens: [KdlToken] = []
        let n = chars.count

        func skipInsignificant() {
            // Spaces/tabs and comments are insignificant; newlines are significant.
            while i < n {
                let c = chars[i]
                if c == " " || c == "\t" { i += 1 }
                else if c == "/" && i + 1 < n, chars[i + 1] == "/" {
                    while i < n, chars[i] != "\n" { i += 1 }
                } else if c == "/" && i + 1 < n, chars[i + 1] == "*" {
                    i += 2
                    while i + 1 < n, !(chars[i] == "*" && chars[i + 1] == "/") { i += 1 }
                    i = min(i + 2, n)
                } else {
                    break
                }
            }
        }

        func readQuoted(_ quote: Character) throws -> String {
            i += 1
            var out = ""
            while i < n {
                let c = chars[i]
                if c == "\\", i + 1 < n {
                    let e = chars[i + 1]
                    out.append(e == "n" ? "\n" : (e == "t" ? "\t" : e))
                    i += 2
                } else if c == quote {
                    i += 1
                    return out
                } else {
                    out.append(c)
                    i += 1
                }
            }
            throw KdlParseError.unterminatedString
        }

        func readBare() -> String {
            var j = i
            while j < n {
                let c = chars[j]
                if c == " " || c == "\t" || c == "\n" || c == "\r"
                    || c == "{" || c == "}" || c == ";" || c == "=" {
                    break
                }
                j += 1
            }
            let s = String(chars[i..<j])
            i = j
            return s
        }

        while i < n {
            skipInsignificant()
            if i >= n { break }
            let c = chars[i]
            switch c {
            case "\n", "\r":
                tokens.append(.newline)
                i += 1
                // Collapse consecutive newlines.
                while i < n, chars[i] == "\n" || chars[i] == "\r" { i += 1 }
            case "{": tokens.append(.openBrace); i += 1
            case "}": tokens.append(.closeBrace); i += 1
            case ";": tokens.append(.newline); i += 1
            case "\"", "'":
                tokens.append(.node(try readQuoted(c)))
            default:
                let ident = readBare()
                if ident.isEmpty {
                    i += 1
                    continue
                }
                // Property key if followed by `=` (ignoring spaces).
                var k = i
                while k < n, chars[k] == " " { k += 1 }
                if k < n, chars[k] == "=" {
                    tokens.append(.prop(ident))
                    i = k + 1
                    while i < n, chars[i] == " " { i += 1 }
                    if i < n, chars[i] == "\"" || chars[i] == "'" {
                        tokens.append(.node(try readQuoted(chars[i])))
                    } else {
                        tokens.append(.node(readBare()))
                    }
                } else {
                    tokens.append(.node(ident))
                }
            }
        }
        return tokens
    }

    // MARK: - Parser

    private static func skipSeparators(_ tokens: inout ArraySlice<KdlToken>) {
        while case .newline? = tokens.first { tokens.removeFirst() }
    }

    private static func parseNode(_ tokens: inout ArraySlice<KdlToken>) -> KdlNode? {
        skipSeparators(&tokens)
        guard case .node(let name)? = tokens.first else { return nil }
        tokens.removeFirst()

        var node = KdlNode(name)

        // Read this node's inline values (args + props) until a line end or brace.
        while let t = tokens.first {
            switch t {
            case .node(let value):
                tokens.removeFirst()
                node.args.append(value)
            case .prop(let key):
                tokens.removeFirst()
                if case .node(let v)? = tokens.first {
                    tokens.removeFirst()
                    node.properties[key] = v
                }
            default:
                break
            }
            // A line terminator ends the inline value list.
            if case .newline? = tokens.first { break }
            if case .openBrace? = tokens.first { break }
            if case .closeBrace? = tokens.first { break }
        }

        // If a block follows (after optional separators), parse children.
        skipSeparators(&tokens)
        if case .openBrace? = tokens.first {
            tokens.removeFirst()
            node.children = parseChildren(&tokens)
        }
        return node
    }

    private static func parseChildren(_ tokens: inout ArraySlice<KdlToken>) -> [KdlNode] {
        var children: [KdlNode] = []
        while let t = tokens.first {
            switch t {
            case .closeBrace:
                tokens.removeFirst()
                return children
            case .node:
                if let child = parseNode(&tokens) {
                    children.append(child)
                }
            case .prop:
                tokens.removeFirst() // stray property with no node; skip
            case .openBrace:
                tokens.removeFirst() // stray block; skip its contents
                _ = parseChildren(&tokens)
            case .newline:
                tokens.removeFirst()
            }
        }
        return children
    }
}
