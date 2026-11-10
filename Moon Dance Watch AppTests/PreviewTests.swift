import CoreGraphics
import Foundation
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

    @Test func emptyPositionHasNoPicture() {
        // 2016 has no hold at A1.
        #expect(HoldImages().sprite(for: GridPosition("A1")!, holdSet: "2016") == nil)
    }
}

struct PreviewGeometryTests {
    private let watch = CGSize(width: 205, height: 251)

    @Test func wholeBoardFitsAtZoomOne() {
        let g = PreviewGeometry(size: watch, zoom: 1, centre: PreviewGeometry.boardCentre)
        let topLeft = g.screenPoint(column: 0, row: 18)
        let bottomRight = g.screenPoint(column: 10, row: 1)
        let ring = g.scale * PreviewGeometry.ringRadius
        #expect(topLeft.y - g.scale / 2 >= PreviewGeometry.topInset - 0.5)
        #expect(bottomRight.y + ring <= watch.height, "row 1 rings fit")
        #expect(topLeft.x - g.scale / 2 >= 0)
        #expect(bottomRight.x + ring <= watch.width, "column K rings fit")
        #expect(watch.width - (bottomRight.x + g.scale / 2) < g.scale / 2, "board sits against the right edge")
        // The back button sits top left: column A (and its letter) start well clear of it.
        #expect(topLeft.x - g.scale / 2 > 55)
        // Nothing to pan at zoom 1.
        #expect(g.clamped(CGPoint(x: 0, y: 0)) == g.centre)
    }

    @Test func zoomScalesAboutTheMiddleOfTheScreen() {
        let one = PreviewGeometry(size: watch, zoom: 2, centre: PreviewGeometry.boardCentre)
        let three = PreviewGeometry(size: watch, zoom: 3, centre: PreviewGeometry.boardCentre)
        #expect(abs(three.scale - one.scale * 1.5) < 0.001)
        let middle = PreviewGeometry.boardCentre
        #expect(one.screenPoint(boardX: middle.x, boardY: middle.y) == three.screenPoint(boardX: middle.x, boardY: middle.y))
    }

    @Test func panningStopsAtTheBoardEdges() {
        let g = PreviewGeometry(size: watch, zoom: 4, centre: PreviewGeometry.boardCentre)
        let farTopLeft = g.clamped(CGPoint(x: -50, y: -50))
        let farBottomRight = g.clamped(CGPoint(x: 500, y: 500))
        // The board's corners land exactly on the viewport's corners.
        let shownTopLeft = PreviewGeometry(size: watch, zoom: 4, centre: farTopLeft).screenPoint(boardX: 0, boardY: 0)
        #expect(abs(shownTopLeft.x) < 0.001)
        #expect(abs(shownTopLeft.y - PreviewGeometry.topInset) < 0.001)
        let shownBottomRight = PreviewGeometry(size: watch, zoom: 4, centre: farBottomRight)
            .screenPoint(boardX: PreviewGeometry.boardWidth, boardY: PreviewGeometry.boardHeight)
        #expect(abs(shownBottomRight.x - watch.width) < 0.001)
        #expect(abs(shownBottomRight.y - watch.height) < 0.001)
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
