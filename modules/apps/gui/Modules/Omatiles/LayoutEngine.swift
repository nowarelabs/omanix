// Modules/Omatiles/LayoutEngine.swift
// Pure, testable layout math for Owin (Phase 4.5).
//
// The brief's "Layouts as Type-Safe Functions": each workspace's layout is a
// pure function from (screenFrame, windowCount) -> [CGRect]. No imperative tree,
// no daemon — just math that the AX sink calls via AXUIElementSetAttributeValue.
// This file has no AX imports so it can be unit-tested headlessly.

import CoreGraphics

enum OwinLayout: String {
    case bsp
    case monocle
    case stack
    case spiral
    case float
}

struct LayoutEngine {

    /// Returns one frame per window, in window-index order. Gap is inset on all
    /// sides so tiled windows don't touch each other or the screen edge.
    static func frames(count: Int, in screen: CGRect, layout: OwinLayout, gap: CGFloat = 8) -> [CGRect] {
        guard count > 0 else { return [] }
        if layout == .float { return [] }
        if layout == .monocle {
            // Every window covers the screen; only the topmost is visible.
            // Returning the same inset frame for all keeps them stacked.
            let f = screen.insetBy(dx: gap, dy: gap)
            return Array(repeating: f, count: count)
        }
        switch layout {
        case .bsp: return bsp(count: count, in: screen, gap: gap)
        case .stack: return stack(count: count, in: screen, gap: gap)
        case .spiral: return spiral(count: count, in: screen, gap: gap)
        default: return stack(count: count, in: screen, gap: gap)
        }
    }

    // MARK: - BSP (binary space partition, longest-edge split)

    private static func bsp(count: Int, in screen: CGRect, gap: CGFloat) -> [CGRect] {
        var rects: [CGRect] = [screen]
        // Split the largest rect until we have enough.
        while rects.count < count {
            // Find the rect with the largest area to split.
            guard let idx = rects.indices.max(by: { rects[$0].width * rects[$0].height < rects[$1].width * rects[$1].height }) else { break }
            let r = rects.remove(at: idx)
            let splitVertically = r.width >= r.height
            let (a, b): (CGRect, CGRect)
            if splitVertically {
                let half = r.width / 2
                a = CGRect(x: r.minX, y: r.minY, width: half - gap/2, height: r.height)
                b = CGRect(x: r.minX + half + gap/2, y: r.minY, width: r.width - half - gap/2, height: r.height)
            } else {
                let half = r.height / 2
                a = CGRect(x: r.minX, y: r.minY, width: r.width, height: half - gap/2)
                b = CGRect(x: r.minX, y: r.minY + half + gap/2, width: r.width, height: r.height - half - gap/2)
            }
            rects.insert(b, at: idx)
            rects.insert(a, at: idx)
        }
        // Inset each rect by gap so windows don't touch.
        return rects.map { $0.insetBy(dx: gap/2, dy: gap/2) }
    }

    // MARK: - Stack (master left 60%, slaves stacked right)

    private static func stack(count: Int, in screen: CGRect, gap: CGFloat) -> [CGRect] {
        if count == 1 { return [screen.insetBy(dx: gap, dy: gap)] }
        let masterW = screen.width * 0.60
        let stackW = screen.width * 0.40
        var out: [CGRect] = []
        // Master
        out.append(CGRect(x: screen.minX + gap/2, y: screen.minY + gap/2,
                          width: masterW - gap, height: screen.height - gap))
        // Slaves: equal height slices on the right.
        let slaveH = (screen.height - gap * CGFloat(count)) / CGFloat(count - 1)
        for i in 1..<count {
            let y = screen.minY + gap/2 + CGFloat(i-1) * (slaveH + gap)
            out.append(CGRect(x: screen.minX + masterW + gap/2, y: y,
                              width: stackW - gap, height: slaveH))
        }
        return out
    }

    // MARK: - Spiral (golden-ratio inspired, keeps nesting)

    private static func spiral(count: Int, in screen: CGRect, gap: CGFloat) -> [CGRect] {
        var rects: [CGRect] = []
        var remaining = screen.insetBy(dx: gap/2, dy: gap/2)
        var vertical = true
        for i in 0..<count {
            if i == count - 1 {
                rects.append(remaining)
                break
            }
            let ratio: CGFloat = 0.5 // could be 1/phi for golden, but 0.5 is predictable
            if vertical {
                let w = remaining.width * ratio - gap/2
                rects.append(CGRect(x: remaining.minX, y: remaining.minY, width: w, height: remaining.height))
                remaining = CGRect(x: remaining.minX + w + gap, y: remaining.minY,
                                   width: remaining.width - w - gap, height: remaining.height)
            } else {
                let h = remaining.height * ratio - gap/2
                rects.append(CGRect(x: remaining.minX, y: remaining.minY, width: remaining.width, height: h))
                remaining = CGRect(x: remaining.minX, y: remaining.minY + h + gap,
                                   width: remaining.width, height: remaining.height - h - gap)
            }
            vertical.toggle()
        }
        return rects
    }
}
