//
//  WrappingHStack.swift
//  Crane
//
//  A layout that arranges subviews horizontally and wraps to new rows
//  when there's not enough horizontal space. Lets us lay out an arbitrary
//  number of fixed-width children inside a vertical `ScrollView` without
//  needing a nested horizontal `NSScrollView` (which is the source of the
//  vertical-scroll gesture conflict in the Settings page).
//

import SwiftUI

struct WrappingHStack: Layout {
    var horizontalSpacing: CGFloat = 8
    var verticalSpacing: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = computeRows(maxWidth: maxWidth, subviews: subviews)
        let totalHeight = rows.reduce(0) { $0 + $1.height } + CGFloat(max(rows.count - 1, 0)) * verticalSpacing
        let usedWidth = rows.map(\.width).max() ?? 0
        return CGSize(
            width: maxWidth.isFinite ? maxWidth : usedWidth,
            height: totalHeight
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            // Centre each row horizontally within the layout's bounds. The
            // layout itself fills the proposed width, but individual rows
            // only occupy as much horizontal space as their children need,
            // so we offset the row's start by half the difference.
            let xOffset = max(0, (bounds.width - row.width) / 2)
            var x = bounds.minX + xOffset
            for index in row.indices {
                let subview = subviews[index]
                let size = subview.sizeThatFits(.unspecified)
                subview.place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(size)
                )
                x += size.width + horizontalSpacing
            }
            y += row.height + verticalSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func computeRows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let proposedWidth = rows[rows.count - 1].width + size.width + (rows[rows.count - 1].indices.isEmpty ? 0 : horizontalSpacing)
            if proposedWidth > maxWidth, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            var current = rows[rows.count - 1]
            current.indices.append(index)
            current.width += size.width + (current.indices.count > 1 ? horizontalSpacing : 0)
            current.height = max(current.height, size.height)
            rows[rows.count - 1] = current
        }
        return rows
    }
}
