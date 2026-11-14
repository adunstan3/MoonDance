import CoreGraphics

/// Lays out "Show beta": each note in a bubble in a lane to the left of the row
/// numbers or to the right of column K, level with its hold where possible, with
/// a line to the hold.
///
/// Notes on holds in columns A–E go left and G–K go right; column F goes to the
/// side with less in it. If a lane overflows, the notes nearest the middle move
/// to the other side. Within a lane, bubbles keep their holds' top-to-bottom
/// order and are pushed apart so they never overlap, which also keeps the lines
/// from crossing. Bubbles have a fixed size in points (readable at any zoom); the
/// lanes sit just outside the board, so you pan sideways to read them.
nonisolated enum BetaBubbles {
    /// Text width inside a bubble, in points.
    static let textWidth: CGFloat = 76
    static let padding: CGFloat = 5
    /// About four lines of 11 pt text.
    static let maxTextHeight: CGFloat = 54
    /// Space between a lane and the board.
    static let laneGap: CGFloat = 6
    /// Space between bubbles.
    static let spacing: CGFloat = 4
    static var laneWidth: CGFloat { textWidth + 2 * padding }
    /// How far past the board's sides you can pan while the bubbles show.
    static var sideRoom: CGFloat { laneWidth + laneGap + 6 }

    struct Note: Equatable {
        let position: GridPosition
        /// The bubble's size, padding included.
        let size: CGSize
    }

    struct Bubble: Equatable {
        let position: GridPosition
        let rect: CGRect
        let onLeft: Bool
    }

    static func layout(_ notes: [Note], geometry g: PreviewGeometry) -> [Bubble] {
        let leftEdge = g.screenPoint(boardX: 0, boardY: 0).x - laneGap
        let rightEdge = g.screenPoint(boardX: PreviewGeometry.boardWidth, boardY: 0).x + laneGap
        let top = g.screenPoint(boardX: 0, boardY: PreviewGeometry.gutterTop).y
        let bottom = g.screenPoint(boardX: 0, boardY: PreviewGeometry.boardHeight).y
        let laneHeight = bottom - top

        func height(_ lane: [Note]) -> CGFloat {
            lane.reduce(0) { $0 + $1.size.height } + spacing * CGFloat(max(lane.count - 1, 0))
        }
        let middle = GridPosition.columns / 2
        var left = notes.filter { $0.position.column < middle }
        var right = notes.filter { $0.position.column > middle }
        for note in notes where note.position.column == middle {
            if height(left) <= height(right) { left.append(note) } else { right.append(note) }
        }
        // Even out a lane that overflows, moving the note nearest the middle.
        for _ in 0..<notes.count {
            if height(left) > laneHeight, height(right) < laneHeight,
               let index = left.indices.max(by: { left[$0].position.column < left[$1].position.column }) {
                right.append(left.remove(at: index))
            } else if height(right) > laneHeight, height(left) < laneHeight,
                      let index = right.indices.min(by: { right[$0].position.column < right[$1].position.column }) {
                left.append(right.remove(at: index))
            } else {
                break
            }
        }

        func holdY(_ note: Note) -> CGFloat { g.screenPoint(column: note.position.column, row: note.position.row).y }

        /// Tops for one lane: each bubble as level with its hold as it can be,
        /// in hold order, without overlapping, kept within the board's height.
        func stack(_ lane: [Note]) -> [(Note, CGFloat)] {
            let sorted = lane.sorted { (holdY($0), $0.position.column) < (holdY($1), $1.position.column) }
            var tops = sorted.map { holdY($0) - $0.size.height / 2 }
            // Down: no overlaps, and not above the board.
            var floor = top
            for i in tops.indices {
                tops[i] = max(tops[i], floor)
                floor = tops[i] + sorted[i].size.height + spacing
            }
            // Up: not below the board, still without overlaps.
            var ceiling = bottom
            for i in tops.indices.reversed() {
                tops[i] = min(tops[i], ceiling - sorted[i].size.height)
                ceiling = tops[i] - spacing
            }
            return Array(zip(sorted, tops))
        }

        return stack(left).map { note, y in
            Bubble(position: note.position,
                   rect: CGRect(x: leftEdge - note.size.width, y: y, width: note.size.width, height: note.size.height),
                   onLeft: true)
        } + stack(right).map { note, y in
            Bubble(position: note.position,
                   rect: CGRect(x: rightEdge, y: y, width: note.size.width, height: note.size.height),
                   onLeft: false)
        }
    }
}
