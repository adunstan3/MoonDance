import CoreGraphics
import Foundation
import ImageIO

/// Pictures of the real holds, for the problem preview.
///
/// Built by tools/build_hold_images.swift from boardsesh's hold-set layers. Each
/// hold set has one sprite sheet, `HoldImages-<set>.png`: an 11 × 18 grid of square
/// tiles (column A on the left, row 18 at the top), each holding one hold centred on
/// its grid point. `HoldImages.json` gives the tile size, how many pixels one grid
/// cell is in the source, and for each position with a hold, an outline traced a
/// little outside the hold (holds aren't always centred on their bolt).
nonisolated struct HoldImageManifest: Decodable, Sendable {
    struct HoldSetInfo: Decodable, Sendable {
        /// Tile width and height, in sheet pixels.
        let tile: Int
        /// Grid spacing in sheet pixels.
        let cell: Double
        /// Position (e.g. "A5") → outline as [x0, y0, x1, y1, …], in cells from the
        /// grid point (y down).
        let outlines: [String: [Double]]

        /// Positions with a hold.
        var positions: [String] { Array(outlines.keys) }

        /// The closed outline around a hold, in cells from its grid point (y down).
        func outline(for position: GridPosition) -> [CGPoint]? {
            guard let values = outlines[position.name], values.count >= 6 else { return nil }
            return stride(from: 0, to: values.count - 1, by: 2).map { CGPoint(x: values[$0], y: values[$0 + 1]) }
        }

        /// How many grid cells wide a tile is.
        var tileInCells: Double { Double(tile) / cell }
    }

    let source: String
    let sets: [String: HoldSetInfo]

    static func bundled(in bundle: Bundle = .main) -> HoldImageManifest? {
        guard let url = bundle.url(forResource: "HoldImages", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(HoldImageManifest.self, from: data)
    }

    /// Where a position's tile sits in its sheet, in pixels from the top left.
    static func tileRect(for position: GridPosition, tile: Int) -> CGRect {
        CGRect(x: position.column * tile, y: (GridPosition.rows - position.row) * tile, width: tile, height: tile)
    }
}

/// Loads sheets on first use and hands out one hold's picture at a time.
final class HoldImages {
    static let shared = HoldImages()

    let manifest: HoldImageManifest?
    private var sheets: [String: CGImage] = [:]
    private var sprites: [String: CGImage] = [:]

    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
        manifest = HoldImageManifest.bundled(in: bundle)
    }

    func info(for holdSet: String) -> HoldImageManifest.HoldSetInfo? {
        manifest?.sets[holdSet]
    }

    /// The hold at a position, or nil if the hold set has nothing there.
    func sprite(for position: GridPosition, holdSet: String) -> CGImage? {
        let key = "\(holdSet)-\(position.name)"
        if let cached = sprites[key] { return cached }
        guard let info = info(for: holdSet), info.outlines[position.name] != nil,
              let sheet = sheet(for: holdSet),
              let sprite = sheet.cropping(to: HoldImageManifest.tileRect(for: position, tile: info.tile))
        else { return nil }
        sprites[key] = sprite
        return sprite
    }

    private func sheet(for holdSet: String) -> CGImage? {
        if let sheet = sheets[holdSet] { return sheet }
        guard let url = bundle.url(forResource: "HoldImages-\(holdSet)", withExtension: "png"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        sheets[holdSet] = image
        return image
    }
}
