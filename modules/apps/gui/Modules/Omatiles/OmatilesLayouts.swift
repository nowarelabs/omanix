// Modules/Omatiles/OmatilesLayouts.swift
// Pure layout math for the Omatiles window tiling engine. No AppKit side effects —
// just CGRect geometry, so it is trivially testable and safe for the runtime module.

import Foundation
import CoreGraphics

enum OmatilesLayout: String, CaseIterable {
    case tiles, columns, rows, accordion

    /// Jumps to the next layout in the cycle (⌘⌥L).
    static func cycle(from current: String) -> String {
        let all = OmatilesLayout.allCases.map(\.rawValue)
        guard let i = all.firstIndex(of: current) else { return "tiles" }
        return all[(i + 1) % all.count]
    }
}

enum OmatilesLayouts {

    /// Distributes `count` panes inside `workArea` with `gapInner` spacing.
    /// - tiles:    strict grid (≈ 2×2, 3×2, …)
    /// - columns:  equal vertical splits
    /// - rows:     equal horizontal stacks
    /// - accordion: one large master pane + a side stack
    static func compute(layout: String, count: Int, workArea: CGRect, gapInner: CGFloat) -> [CGRect] {
        guard count > 0 else { return [] }
        let gap = max(0, gapInner)
        let w = workArea.width
        let h = workArea.height

        switch layout {
        case "columns":
            guard count > 0 else { return [] }
            let cw = (w - gap * CGFloat(count - 1)) / CGFloat(count)
            return (0..<count).map { i in
                CGRect(x: workArea.minX + CGFloat(i) * (cw + gap),
                       y: workArea.minY,
                       width: cw,
                       height: h)
            }

        case "rows":
            let rh = (h - gap * CGFloat(count - 1)) / CGFloat(count)
            return (0..<count).map { i in
                CGRect(x: workArea.minX,
                       y: workArea.minY + CGFloat(i) * (rh + gap),
                       width: w,
                       height: rh)
            }

        case "accordion":
            guard count > 1 else { return [workArea] }
            let mainW = w * 0.55 - gap / 2
            var frames: [CGRect] = [
                CGRect(x: workArea.minX, y: workArea.minY, width: mainW, height: h)
            ]
            let rest = count - 1
            let sideX = workArea.minX + mainW + gap
            let sideW = w - mainW - gap
            let sideH = (h - gap * CGFloat(rest - 1)) / CGFloat(rest)
            for i in 0..<rest {
                frames.append(CGRect(x: sideX,
                                     y: workArea.minY + CGFloat(i) * (sideH + gap),
                                     width: sideW,
                                     height: sideH))
            }
            return frames

        default: // tiles — strict grid
            let cols = max(1, Int(ceil(sqrt(Double(count)))))
            let rows = max(1, Int(ceil(Double(count) / Double(cols))))
            let cw = (w - gap * CGFloat(cols - 1)) / CGFloat(cols)
            let rh = (h - gap * CGFloat(rows - 1)) / CGFloat(rows)
            var frames: [CGRect] = []
            var placed = 0
            for r in 0..<rows {
                for c in 0..<cols where placed < count {
                    frames.append(CGRect(x: workArea.minX + CGFloat(c) * (cw + gap),
                                         y: workArea.minY + CGFloat(r) * (rh + gap),
                                         width: cw,
                                         height: rh))
                    placed += 1
                }
            }
            return frames
        }
    }
}