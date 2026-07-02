//
//  TreemapTail.swift
//  Burrow
//
//  Folds the long tail of small treemap cells into a single inert "Other" cell
//  (PRD §Analyze), so a folder of thousands of files stays legible and the map
//  matches the total it claims. Pure — total bytes are preserved.
//

import Foundation

enum TreemapTail {
    struct Cell: Equatable { let name: String; let size: Int64 }

    /// Keep the largest `keep` cells; sum the rest into one "Other" cell.
    static func fold(_ cells: [Cell], keep: Int, otherName: String = "Other") -> [Cell] {
        guard keep >= 0, cells.count > keep else { return cells }
        let sorted = cells.sorted { $0.size > $1.size }
        let head = Array(sorted.prefix(keep))
        let other = sorted.dropFirst(keep).reduce(Int64(0)) { $0 + $1.size }
        return other > 0 ? head + [Cell(name: otherName, size: other)] : head
    }
}
