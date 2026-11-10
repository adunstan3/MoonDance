import CoreGraphics
import Foundation
import ImageIO

/// Pictures of the real holds, for the problem preview.
///
/// Built by tools/build_hold_images.swift from boardsesh's hold-set layers. Each
/// hold set has one sprite sheet, `HoldImages-<set>.png`: an 11 × 18 grid of square
/// tiles (column A on the left, row 18 at the top), each holding one hold centred on
/// its grid point. `HoldImages.json` gives the tile size, how many pixels one grid
/// cell is in the source, and which positions have a hold.
nonisolated struct HoldImageManifest: Decodable, Sendable {
    struct HoldSetInfo: Decodable, Sendable {
        /// Tile width and height, in sheet pixels.
        let tile: Int
        /// Grid spacing in sheet pixels.
        let cell: Double
        /// Positions with a hold, e.g. "A5".
        let positions: [String]

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
        guard let info = info(for: holdSet), info.positions.contains(position.name),
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
