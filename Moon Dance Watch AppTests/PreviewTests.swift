import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import Moon_Dance_Watch_App

@MainActor
struct HoldImagesTests {
    @Test func bundledManifestCoversBothHoldSets() throws {
        let manifest = try #require(HoldImageManifest.bundled())
        let set2016 = try #require(manifest.sets["2016"])
        let set2024 = try #require(manifest.sets["2024"])
        #expect(set2016.positions.count == 140)
        #expect(set2024.positions.count == 198)
        for info in [set2016, set2024] {
            #expect(info.tileInCells > 1 && info.tileInCells < 2, "a hold tile should be a bit over one cell")
        }
    }

    @Test func tilesAreLaidOutLikeTheBoard() {
        let tile = 72
        #expect(HoldImageManifest.tileRect(for: GridPosition("A18")!, tile: tile) == CGRect(x: 0, y: 0, width: 72, height: 72))
        #expect(HoldImageManifest.tileRect(for: GridPosition("K1")!, tile: tile)
            == CGRect(x: 10 * 72, y: 17 * 72, width: 72, height: 72))
        #expect(HoldImageManifest.tileRect(for: GridPosition("C16")!, tile: tile).origin == CGPoint(x: 144, y: 144))
    }

    /// Every hold of every bundled problem has a picture, so no preview has gaps.
    @Test func everyProblemHoldHasAPicture() throws {
        let snapshot = try SnapshotLoader.decode(from: #require(SnapshotLoader.bundledSnapshotURL()))
        let images = HoldImages()
        var missing: Set<String> = []
        for problem in snapshot.problems {
            for hold in problem.holds {
                let position = try #require(GridPosition(hold.position))
                if images.sprite(for: position, holdSet: problem.holdSet) == nil {
                    missing.insert("\(problem.holdSet) \(hold.position)")
                }
            }
        }
        #expect(missing.isEmpty, "no picture for \(missing.sorted())")
        let sprite = try #require(images.sprite(for: GridPosition("A1")!, holdSet: "2024"))
        #expect(sprite.width == images.info(for: "2024")?.tile)
    }

    /// Every hold has an outline that wraps around it, close in, and follows the
    /// hold rather than its bolt: J15 on the 2024 set sits a quarter cell right.
    @Test func holdOutlinesHugTheirHolds() throws {
        let manifest = try #require(HoldImageManifest.bundled())
        for info in manifest.sets.values {
            for position in info.positions {
                let outline = try #require(info.outline(for: GridPosition(position)!))
                #expect(outline.count >= 6)
                let reach = outline.map { hypot($0.x, $0.y) }.max()!
                // The tile holds the hold; the outline runs about a tenth of a cell outside it.
                #expect(reach < info.tileInCells / 2 + 0.2, "\(position) outline is too far out")
                #expect(reach > 0.1, "\(position) outline is too small")
            }
        }
        let j15 = try #require(manifest.sets["2024"]?.outline(for: GridPosition("J15")!))
        let middle = j15.map(\.x).reduce(0, +) / Double(j15.count)
        #expect(middle > 0.12, "J15's outline should sit right of its bolt")
    }

    @Test func smoothPathClosesThroughTheMidpoints() {
        let square = [CGPoint(x: 0, y: 0), CGPoint(x: 2, y: 0), CGPoint(x: 2, y: 2), CGPoint(x: 0, y: 2)]
        let path = PreviewGeometry.smoothPath(square)
        #expect(path.boundingRect.width > 1.5 && path.boundingRect.width <= 2)
        #expect(path.contains(CGPoint(x: 1, y: 1)))
        #expect(PreviewGeometry.smoothPath([CGPoint.zero]).isEmpty)
    }

    @Test func emptyPositionHasNoPicture() {
        // 2016 has no hold at A1.
        #expect(HoldImages().sprite(for: GridPosition("A1")!, holdSet: "2016") == nil)
    }
}

struct PreviewGeometryTests {
    private let watch = CGSize(width: 205, height: 251)

    @Test func wholeBoardFitsCentredAtZoomOne() {
        let g = PreviewGeometry(size: watch, zoom: 1, centre: PreviewGeometry.boardCentre)
        let topLeft = g.screenPoint(column: 0, row: 18)
        let bottomRight = g.screenPoint(column: 10, row: 1)
        let outline = g.scale * 0.75
        #expect(topLeft.y - g.scale / 2 >= PreviewGeometry.topInset - 0.5)
        #expect(bottomRight.y + outline <= watch.height - PreviewGeometry.bottomInset, "row 1 outlines fit")
        #expect(bottomRight.x + outline <= watch.width, "column K outlines fit")
        // Centred: the same space either side of the board (gutter and margin included).
        let left = g.screenPoint(boardX: 0, boardY: 0).x
        let right = watch.width - g.screenPoint(boardX: PreviewGeometry.boardWidth, boardY: 0).x
        #expect(abs(left - right) < 0.001)
    }

    @Test func zoomOneStillPansALittle() {
        let g = PreviewGeometry(size: watch, zoom: 1, centre: PreviewGeometry.boardCentre)
        let moved = PreviewGeometry(size: watch, zoom: 1, centre: CGPoint(x: -100, y: -100))
        let shift = moved.screenPoint(boardX: 0, boardY: 0).x - g.screenPoint(boardX: 0, boardY: 0).x
        #expect(abs(shift - PreviewGeometry.overscroll) < 0.001)
    }

    @Test func zoomScalesAboutTheMiddleOfTheScreen() {
        let two = PreviewGeometry(size: watch, zoom: 2, centre: PreviewGeometry.boardCentre)
        let three = PreviewGeometry(size: watch, zoom: 3, centre: PreviewGeometry.boardCentre)
        #expect(abs(three.scale - two.scale * 1.5) < 0.001)
        let middle = PreviewGeometry.boardCentre
        #expect(two.screenPoint(boardX: middle.x, boardY: middle.y) == three.screenPoint(boardX: middle.x, boardY: middle.y))
    }

    /// Zoomed in, every edge can be reached, and a little past it, so column K,
    /// row 1 and the corners are never cut off.
    @Test func panningReachesEveryEdgeAndALittleBeyond() {
        let over = PreviewGeometry.overscroll
        for zoom in [2.0, 3.0, 4.0] {
            let topLeft = PreviewGeometry(size: watch, zoom: zoom, centre: CGPoint(x: -50, y: -50))
            let corner = topLeft.screenPoint(boardX: 0, boardY: 0)
            #expect(abs(corner.x - over) < 0.001)
            #expect(abs(corner.y - (PreviewGeometry.topInset + over)) < 0.001)

            let bottomRight = PreviewGeometry(size: watch, zoom: zoom, centre: CGPoint(x: 500, y: 500))
            let far = bottomRight.screenPoint(boardX: PreviewGeometry.boardWidth, boardY: PreviewGeometry.boardHeight)
            #expect(abs(far.x - (watch.width - over)) < 0.001)
            #expect(abs(far.y - (watch.height - PreviewGeometry.bottomInset - over)) < 0.001)
            let k1 = bottomRight.screenPoint(column: 10, row: 1)
            #expect(k1.x + bottomRight.scale * 0.7 < watch.width - over)
        }
    }

    @Test func labelsPinWhenTheirGutterScrollsOff() {
        let whole = PreviewGeometry(size: watch, zoom: 1, centre: PreviewGeometry.boardCentre)
        #expect(!whole.letterRowY(band: 14).pinned)
        #expect(!whole.numberColumnX(band: 14).pinned)
        let zoomed = PreviewGeometry(size: watch, zoom: 4, centre: CGPoint(x: 8, y: 12))
        #expect(zoomed.letterRowY(band: 14).pinned)
        #expect(zoomed.numberColumnX(band: 14).pinned)
    }
}

/// The climber beside the hold pictures, drawn to the board's scale.
struct ClimberScaleTests {
    @Test func sixFootClimberSpansAboutNineRows() {
        let rect = PreviewGeometry.climberRect(heightInches: 72)
        // 182.9 cm at 20 cm a hold.
        #expect(abs(rect.height - 9.144) < 0.001)
        // Feet level with the bottom of row 1.
        #expect(abs(rect.maxY - (PreviewGeometry.gutterTop + Double(GridPosition.rows))) < 0.000_1)
    }

    @Test func everyHeightFitsItsStripRightOfColumnK() {
        let columnK = PreviewGeometry.gutterLeft + Double(GridPosition.columns)
        for inches in AppSettings.heightRange {
            let rect = PreviewGeometry.climberRect(heightInches: inches)
            #expect(rect.minX > columnK)
            #expect(rect.maxX < PreviewGeometry.boardWidth)
            #expect(rect.minY > PreviewGeometry.gutterTop)
        }
    }

    @Test func heightText() {
        #expect(AppSettings.heightText(72) == "6′0″")
        #expect(AppSettings.heightText(69) == "5′9″")
        #expect(AppSettings.centimetres(72) == 183)
    }
}
